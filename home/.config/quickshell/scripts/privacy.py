#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   P R I V A C Y                                                          │
# │   which programs have the camera open · on every open and close          │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Print, as a JSON line, the programs holding a camera device open.

Usage: privacy.py

Most programs open /dev/video* themselves rather than through PipeWire, so
the device is watched with inotify and the processes holding it are found in
/proc when that changes; nothing is polled. Programs that probe every camera
(Discord does, every three seconds) open and close each one in a burst, so a
burst is waited out, and /proc is read only when the opens and closes in it
did not cancel. Only this user's processes can be read, which leaves out the face unlock, run as root at the
lock screen. PipeWire and WirePlumber are reported as `pipewire`: the program
behind them is a PipeWire stream, which the shell reads itself.
"""

import ctypes
import glob
import json
import os
import select
import signal
import subprocess
import sys

DEVICES = "/dev/video*"
# How long the device must stay quiet before /proc is read.
SETTLE = 0.25
BROKERS = {"pipewire", "wireplumber"}


def holders(devices):
    found = set()
    for fd_dir in glob.glob("/proc/[0-9]*/fd"):
        try:
            links = [os.readlink(os.path.join(fd_dir, fd)) for fd in os.listdir(fd_dir)]
        except OSError:
            continue
        if not any(link in devices for link in links):
            continue
        pid_dir = os.path.dirname(fd_dir)
        try:
            with open(os.path.join(pid_dir, "comm"), encoding="utf-8") as source:
                name = source.read().strip()
        except OSError:
            continue
        found.add("pipewire" if name in BROKERS else name)
    return sorted(found)


def report(devices, last):
    now = holders(devices)
    if now != last:
        print(json.dumps({"camera": now}), flush=True)
    return now


def die_with_parent():
    """Take inotifywait down with this script when the shell stops it."""
    libc = ctypes.CDLL(None, use_errno=True)
    libc.prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG


def read_burst(stream):
    """Everything inotifywait writes until it has been quiet for SETTLE."""
    data = os.read(stream, 4096)
    if not data:
        return None
    while select.select([stream], [], [], SETTLE)[0]:
        more = os.read(stream, 4096)
        if not more:
            return None
        data += more
    return data


def main():
    devices = set(glob.glob(DEVICES))
    last = report(devices, None)
    if not devices:
        return
    watch = subprocess.Popen(
        ["inotifywait", "-m", "-q", "-e", "open,close", "--format", "%w %e", *sorted(devices)],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        preexec_fn=die_with_parent)
    if watch.stdout is None:
        return
    stream = watch.stdout.fileno()
    # Opens less closes per device; a probe leaves it as it was.
    held = dict.fromkeys(devices, 0)
    seen = dict(held)
    pending = b""
    while (burst := read_burst(stream)) is not None:
        *lines, pending = (pending + burst).split(b"\n")
        for line in lines:
            device, _, events = line.decode(errors="replace").partition(" ")
            if device in held:
                held[device] += 1 if events.startswith("OPEN") else -1
        if held != seen:
            seen = dict(held)
            last = report(devices, last)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
