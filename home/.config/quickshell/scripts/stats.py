#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   S T A T S                                                              │
# │   one snapshot of what the machine is doing                              │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""CPU, memory, disk, network and temperature from /proc and /sys.

Read from the kernel directly, so there is no locale- or version-dependent
output to parse. CPU and network are rates and need two samples.

`stats.py` prints one reading and exits. `stats.py watch <seconds>` stays
resident and prints a line per interval, so the shell can keep a history
without paying Python's start-up on every tick. The sampling interval is set
here either way, not by however often the caller happens to ask.
"""

import fcntl
import glob
import json
import os
import shutil
import socket
import struct
import subprocess
import sys
import time

SAMPLE_WINDOW = 0.25

# While watching, disks and sensors are re-read only every SLOW_EVERY
# intervals: they cost about 16 ms and 4 ms, against 0.1 ms for all the rates
# together, and they barely change.
SLOW_EVERY = 10


def read(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


def cpu_times():
    """Busy and total jiffies for the package and for each core."""
    entries = []
    for line in read("/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        fields = line.split()
        values = [int(value) for value in fields[1:]]
        if len(values) < 4:
            continue
        idle = values[3] + (values[4] if len(values) > 4 else 0)
        total = sum(values)
        entries.append((total - idle, total))
    return entries


def network_bytes():
    received = transmitted = 0
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, _, rest = line.partition(":")
        name = name.strip()
        # Loopback traffic never leaves the machine.
        if name == "lo":
            continue
        fields = rest.split()
        if len(fields) >= 9:
            received += int(fields[0])
            transmitted += int(fields[8])
    return received, transmitted


def route():
    """The interface the default route leaves by, and its IPv4 address."""
    for line in read("/proc/net/route").splitlines()[1:]:
        fields = line.split()
        if len(fields) > 1 and fields[1] == "00000000":
            name = fields[0]
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
                    # SIOCGIFADDR: the address, without parsing `ip`.
                    packed = fcntl.ioctl(probe.fileno(), 0x8915,
                                         struct.pack("256s", name[:15].encode()))
                return {"interface": name, "address": socket.inet_ntoa(packed[20:24])}
            except OSError:
                return {"interface": name, "address": ""}
    return {"interface": "", "address": ""}


def memory():
    values = {}
    for line in read("/proc/meminfo").splitlines():
        key, _, rest = line.partition(":")
        parts = rest.split()
        if parts:
            values[key] = int(parts[0]) * 1024

    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", 0)
    swap_total = values.get("SwapTotal", 0)
    swap_free = values.get("SwapFree", 0)
    return {
        "total": total,
        # Total minus available, not minus free: cache and buffers are
        # reclaimable and should not count as used.
        "used": total - available,
        "swapTotal": swap_total,
        "swapUsed": swap_total - swap_free,
    }


def disks():
    if not shutil.which("df"):
        return []
    try:
        result = subprocess.run(
            ["df", "-B1", "--output=target,size,used,fstype"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return []

    skip = {"tmpfs", "devtmpfs", "squashfs", "overlay", "efivarfs", "ramfs"}
    entries = []
    for line in result.stdout.splitlines()[1:]:
        fields = line.split()
        if len(fields) < 4:
            continue
        target, size, used, fstype = fields[0], fields[1], fields[2], fields[3]
        if fstype in skip or not size.isdigit() or int(size) == 0:
            continue
        entries.append({
            "target": target,
            "total": int(size),
            "used": int(used),
        })
    entries.sort(key=lambda entry: -entry["total"])
    return entries[:4]


def temperature():
    """The hottest sensor that reports a plausible CPU temperature."""
    best = None
    for path in glob.glob("/sys/class/hwmon/hwmon*/temp*_input"):
        raw = read(path).strip()
        if not raw.isdigit():
            continue
        celsius = int(raw) / 1000
        if not 5 < celsius < 125:
            continue
        label = read(os.path.join(os.path.dirname(path),
                                  os.path.basename(path).replace("_input", "_label"))).strip()
        name = read(os.path.join(os.path.dirname(path), "name")).strip()
        if best is None or celsius > best["celsius"]:
            best = {"celsius": round(celsius, 1), "label": label or name}
    return best


def counters():
    """The raw totals a rate is the difference of, and when they were read."""
    return (time.monotonic(), cpu_times(), network_bytes())


def slow_readings():
    """The parts worth re-reading rarely: what is mounted, how hot it is, and
    the route out."""
    return {"disks": disks(), "temperature": temperature(), "route": route()}


def report(before, after, slow=None):
    """One reading, with every rate measured across the two samples given."""
    if slow is None:
        slow = slow_readings()
    span = max(1e-6, after[0] - before[0])
    first_cpu, first_net = before[1], before[2]
    second_cpu, second_net = after[1], after[2]

    usages = []
    for (busy_a, total_a), (busy_b, total_b) in zip(first_cpu, second_cpu):
        jiffies = total_b - total_a
        usages.append(round((busy_b - busy_a) / jiffies * 100, 1) if jiffies > 0 else 0.0)

    load = read("/proc/loadavg").split()[:3]
    uptime = read("/proc/uptime").split()
    model = ""
    for line in read("/proc/cpuinfo").splitlines():
        if line.startswith("model name"):
            model = line.partition(":")[2].strip()
            break

    return {
        "cpu": {
            "total": usages[0] if usages else 0.0,
            "cores": usages[1:],
            "model": model,
            "load": [float(value) for value in load] if len(load) == 3 else [0, 0, 0],
        },
        "memory": memory(),
        "disks": slow["disks"],
        "network": {
            "down": max(0, int((second_net[0] - first_net[0]) / span)),
            "up": max(0, int((second_net[1] - first_net[1]) / span)),
            "received": second_net[0],
            "sent": second_net[1],
            **slow["route"],
        },
        "temperature": slow["temperature"],
        "uptime": int(float(uptime[0])) if uptime else 0,
    }


def snapshot():
    """A single reading, for a caller that wants one and then goes away."""
    before = counters()
    time.sleep(SAMPLE_WINDOW)
    return report(before, counters())


def watch(interval):
    """One line per interval, forever. The reader decides when to stop."""
    before = counters()
    slow = slow_readings()
    tick = 0
    while True:
        time.sleep(interval)
        after = counters()
        tick += 1
        if tick % SLOW_EVERY == 0:
            slow = slow_readings()
        print(json.dumps(report(before, after, slow)), flush=True)
        before = after


if __name__ == "__main__":
    try:
        if len(sys.argv) > 1 and sys.argv[1] == "watch":
            watch(float(sys.argv[2]) if len(sys.argv) > 2 else 3.0)
        else:
            print(json.dumps(snapshot()))
    except (KeyboardInterrupt, BrokenPipeError):
        # The reader closed the pipe.
        pass
    except Exception as error:  # a stats panel must never take the shell down
        sys.stderr.write(f"stats failed: {error}\n")
        print(json.dumps({}))
