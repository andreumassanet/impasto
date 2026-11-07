#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   S Y S T E M                                                            │
# │   live system state · brightness, audio, radios                          │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Read and toggle the radios, and read the power profile.

Only what nothing else can push: NetworkManager and bluez have no interface
the shell can subscribe to, so they are polled while a panel is open. The
power profile is read here only to tell whether power-profiles-daemon
answers; the shell follows and sets it over D-Bus. Volume, brightness and
battery are pushed by Pipewire, sysfs and UPower and are handled in QML, not
here.

Missing tools degrade to `None`, which the UI renders as an unavailable
control instead of failing.
"""

import json
import shutil
import subprocess
import sys

def run(*command):
    """Run a command and return its stdout, or None if it is unavailable."""
    if not shutil.which(command[0]):
        return None
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def wifi():
    output = run("nmcli", "radio", "wifi")
    return None if output is None else output == "enabled"


def bluetooth():
    output = run("bluetoothctl", "show")
    if output is None:
        return None
    return "Powered: yes" in output


def power_profile():
    return run("powerprofilesctl", "get")


def status():
    return {
        "wifi": wifi(),
        "bluetooth": bluetooth(),
        "powerProfile": power_profile(),
    }


def toggle(target):
    """Flip a boolean control, based on its current state."""
    if target == "wifi":
        state = wifi()
        if state is None:
            return False
        return run("nmcli", "radio", "wifi", "off" if state else "on") is not None

    if target == "bluetooth":
        state = bluetooth()
        if state is None:
            return False
        return run("bluetoothctl", "power", "off" if state else "on") is not None

    sys.stderr.write(f"Unknown toggle target: {target}\n")
    return False


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: system.py status | toggle <wifi|bluetooth>\n")
        sys.exit(1)

    action = sys.argv[1]
    if action == "status":
        print(json.dumps(status()))
    elif action == "toggle" and len(sys.argv) >= 3:
        toggle(sys.argv[2])
        print(json.dumps(status()))
    else:
        sys.stderr.write(f"Unknown action: {action}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
