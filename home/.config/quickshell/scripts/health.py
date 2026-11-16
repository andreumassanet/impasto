#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   H E A L T H                                                            │
# │   failed units and this boot's journal errors, as JSON                   │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""One snapshot for the dashboard's Health card.

`failedSystem` and `failedUser` are the units `systemctl [--user] --failed`
lists; `journalErrors` counts this boot's entries of priority err and worse.
A command that is missing or slow gives an empty answer, never an error.
"""

import json
import subprocess


def run(*command, timeout=8):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return ""
    return result.stdout


def failed_units(user):
    command = ["systemctl", *(["--user"] if user else []), "--failed", "--plain", "--no-legend", "--no-pager"]
    return [line.split()[0] for line in run(*command).splitlines() if line.strip()]


def main():
    errors = run("journalctl", "-b", "-p", "3", "-q", "--no-pager", "-o", "cat").splitlines()
    print(json.dumps({
        "failedSystem": failed_units(False),
        "failedUser": failed_units(True),
        "journalErrors": len([line for line in errors if line.strip()]),
    }))


if __name__ == "__main__":
    main()
