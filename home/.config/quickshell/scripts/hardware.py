#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   H A R D W A R E                                                        │
# │   one snapshot of the GPUs and the processor's energy counters           │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

# Adapted from end_4 illogical-impulse (scripts/system_monitor.py, GPL-3.0): its
# disk and CPU temperature readings are left out, since `stats.py` has them.
"""One-shot hardware snapshot for the dashboard's monitor tab, as JSON.

GPUs (NVIDIA via nvidia-smi, Intel i915 and AMD amdgpu via sysfs) and RAPL
energy counters. Counters that need a delta (Intel rc6 residency, RAPL
energy) are returned raw with a timestamp; the shell does the differencing.
Anything unreadable is null.
"""

import json
import re
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
        fields = [part.strip() for part in line.split(",")]
        if len(fields) < 6:
            continue

        def num(text):
            try:
                return float(text)
            except ValueError:
                return None

        gpus.append({
            "vendor": "nvidia",
            "name": re.sub(r"^NVIDIA\s+", "", fields[0]),
            "usage": None if num(fields[1]) is None else num(fields[1]) / 100,
            "vramUsedMiB": num(fields[2]),
            "vramTotalMiB": num(fields[3]),
            "temp": num(fields[4]),
            "power": num(fields[5]),
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


print(json.dumps({
    "time": time.monotonic() * 1000,
    "gpus": nvidia_gpus() + sysfs_gpus(),
    "rapl": rapl(),
}))
