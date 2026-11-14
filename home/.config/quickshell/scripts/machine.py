#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   M A C H I N E                                                          │
# │   hardware and os summary                                                │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Static facts about the machine, for the control centre and the greeting.

Distribution, kernel, compositor, login shell, host and package count, read
from the same sources fastfetch uses so the two agree. Read on demand rather
than on a tick; a missing source is null.
"""

import json
import os
import pwd
import shutil
import subprocess
import sys

OS_RELEASE = ("/etc/os-release", "/usr/lib/os-release")
PACMAN_LOCAL = "/var/lib/pacman/local"


def distribution():
    """PRETTY_NAME out of os-release, which is what every fetch tool prints."""
    for path in OS_RELEASE:
        try:
            with open(path, encoding="utf-8") as handle:
                for line in handle:
                    key, _, value = line.strip().partition("=")
                    if key == "PRETTY_NAME":
                        return value.strip().strip('"') or None
        except OSError:
            continue
    return None


def compositor():
    """The session's compositor, with its version where it can be asked."""
    name = os.environ.get("XDG_CURRENT_DESKTOP", "").split(":")[0].strip()
    if not name:
        return None
    if name.lower() == "hyprland" and shutil.which("hyprctl"):
        try:
            result = subprocess.run(
                ["hyprctl", "version", "-j"],
                capture_output=True, text=True, timeout=5, check=False,
            )
            version = json.loads(result.stdout).get("version", "")
            if version:
                return f"{name} {version}"
        except (OSError, subprocess.SubprocessError, ValueError):
            pass
    return name


def login_shell(record):
    """The account's shell, by its name — the passwd record's, not $SHELL's."""
    path = record.pw_shell if record else os.environ.get("SHELL", "")
    return os.path.basename(path) or None


def packages():
    """How many packages pacman has installed: one directory each in its
    local database, the way fastfetch counts them. No pacman, no number."""
    try:
        with os.scandir(PACMAN_LOCAL) as entries:
            return sum(1 for entry in entries if entry.is_dir())
    except OSError:
        return None


def machine():
    try:
        record = pwd.getpwuid(os.getuid())
    except KeyError:
        record = None
    uname = os.uname()
    return {
        "os": distribution(),
        "kernel": uname.release or None,
        "host": uname.nodename or None,
        "wm": compositor(),
        "shell": login_shell(record),
        "packages": packages(),
    }


def main():
    if len(sys.argv) > 1 and sys.argv[1] != "get":
        sys.stderr.write("Usage: machine.py [get]\n")
        sys.exit(1)
    print(json.dumps(machine()))


if __name__ == "__main__":
    main()
