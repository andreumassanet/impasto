#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   S Y S T E M   M O N I T O R                                            │
# │   one snapshot of the GPUs, CPU temperature and mounted disks            │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

# From end_4 illogical-impulse (scripts/system_monitor.py), unchanged.
"""One-shot hardware snapshot for the system monitor sidebar, as JSON.

GPUs (NVIDIA via nvidia-smi, Intel i915 and AMD amdgpu via sysfs), CPU
temperature and RAPL energy counters. With the argument `disks`, only the
mounted disks. Counters that need
a delta (Intel rc6 residency, RAPL energy) are returned raw with a
timestamp; the shell does the differencing. Anything unreadable is null.
"""

import json
import os
import re
import sys
import subprocess
import time
from pathlib import Path

SYS = Path("/sys")


def read(path, cast=str):
    try:
        return cast(Path(path).read_text().strip())
    except (OSError, ValueError):
        return None


def run(*command):
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def pci_name(slot):
    """Marketing name from lspci, e.g. 'UHD Graphics 770'."""
    fields = re.findall(r'"([^"]*)"', run("lspci", "-mm", "-s", slot))
    if len(fields) < 3:
        return None
    device = fields[2]
    bracket = re.search(r"\[([^\]]+)\]", device)
    return bracket.group(1) if bracket else device


def hwmon_of(device):
    for hwmon in sorted((device / "hwmon").glob("hwmon*")):
        return hwmon
    return None


def nvidia_gpus():
    gpus = []
    query = "name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw"
    for line in run("nvidia-smi", f"--query-gpu={query}", "--format=csv,noheader,nounits").splitlines():
        f = [part.strip() for part in line.split(",")]
        if len(f) < 6:
            continue

        def num(text):
            try:
                return float(text)
            except ValueError:
                return None

        gpus.append({
            "vendor": "nvidia",
            "name": re.sub(r"^NVIDIA\s+", "", f[0]),
            "usage": None if num(f[1]) is None else num(f[1]) / 100,
            "vramUsedMiB": num(f[2]),
            "vramTotalMiB": num(f[3]),
            "temp": num(f[4]),
            "power": num(f[5]),
        })
    return gpus


def sysfs_gpus():
    gpus = []
    for card in sorted((SYS / "class/drm").glob("card[0-9]")):
        device = (card / "device").resolve()
        driver = (device / "driver").resolve().name
        slot = device.name
        if driver == "i915":
            gt = card / "gt/gt0"
            gpus.append({
                "vendor": "intel",
                "name": pci_name(slot) or "Intel Graphics",
                # Share of time the render engine was not in RC6 sleep: take
                # the delta of this counter over the sample interval.
                "rc6Ms": read(gt / "rc6_residency_ms", int),
                "freqMHz": read(gt / "rps_act_freq_mhz", int),
                "maxFreqMHz": read(gt / "rps_RP0_freq_mhz", int),
            })
        elif driver == "amdgpu":
            hwmon = hwmon_of(device)
            power = read(hwmon / "power1_average", int) if hwmon else None
            if power is None and hwmon:
                power = read(hwmon / "power1_input", int)
            temp = read(hwmon / "temp1_input", int) if hwmon else None
            used = read(device / "mem_info_vram_used", int)
            total = read(device / "mem_info_vram_total", int)
            busy = read(device / "gpu_busy_percent", int)
            gpus.append({
                "vendor": "amd",
                "name": pci_name(slot) or "AMD Graphics",
                "usage": None if busy is None else busy / 100,
                "vramUsedMiB": None if used is None else used / 2**20,
                "vramTotalMiB": None if total is None else total / 2**20,
                "temp": None if temp is None else temp / 1000,
                "power": None if power is None else power / 1e6,
            })
    return gpus


def cpu_temp():
    for hwmon in sorted((SYS / "class/hwmon").glob("hwmon*")):
        if read(hwmon / "name") not in ("coretemp", "k10temp"):
            continue
        for label in sorted(hwmon.glob("temp*_label")):
            if read(label) in ("Package id 0", "Tctl", "Tdie"):
                value = read(str(label).replace("_label", "_input"), int)
                if value is not None:
                    return value / 1000
        value = read(hwmon / "temp1_input", int)
        return None if value is None else value / 1000
    return None


def rapl():
    """Energy counters in µJ by domain name. Root-only on most kernels."""
    energy = {}
    for domain in sorted((SYS / "class/powercap").glob("intel-rapl:*")):
        value = read(domain / "energy_uj", int)
        name = read(domain / "name")
        if value is None or name is None:
            continue
        energy[name] = {"uj": value, "max": read(domain / "max_energy_range_uj", int)}
    return energy


def disks():
    seen = set()
    result = []
    try:
        mounts = Path("/proc/mounts").read_text().splitlines()
    except OSError:
        return result
    for line in mounts:
        source, target = line.split()[:2]
        if not source.startswith("/dev/") or source.startswith(("/dev/loop", "/dev/zram")):
            continue
        if source in seen:
            continue
        seen.add(source)
        try:
            stat = os.statvfs(target)
        except OSError:
            continue
        # Same arithmetic as df: reserved blocks count as neither used nor free
        used = (stat.f_blocks - stat.f_bfree) * stat.f_frsize
        total = used + stat.f_bavail * stat.f_frsize
        if total <= 0:
            continue
        result.append({"mount": target, "total": total, "used": used})
    return result


if len(sys.argv) > 1 and sys.argv[1] == "disks":
    # Disk usage barely changes, so the shell asks for it once per open
    print(json.dumps({"disks": disks()}))
else:
    print(json.dumps({
        "time": time.monotonic() * 1000,
        "gpus": nvidia_gpus() + sysfs_gpus(),
        "cpuTemp": cpu_temp(),
        "rapl": rapl(),
    }))
