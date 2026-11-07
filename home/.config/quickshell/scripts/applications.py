#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   A P P L I C A T I O N S                                                │
# │   desktop entry index for the launcher                                   │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""List the desktop entries the launcher can start.

Directories are scanned in XDG precedence order and the first entry wins, so
a user override in ~/.local/share/applications shadows the system copy.
"""

import configparser
import json
import os
import sys

XDG_DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
XDG_DATA_DIRS = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"

APPLICATION_DIRS = [
    os.path.join(directory, "applications")
    for directory in [XDG_DATA_HOME, *XDG_DATA_DIRS.split(":")]
    if directory
]


def read_entry(path):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        parser.read(path, encoding="utf-8")
        section = parser["Desktop Entry"]
    except (configparser.Error, KeyError, UnicodeDecodeError, OSError):
        return None

    if section.get("Type") != "Application":
        return None
    if section.getboolean("NoDisplay", fallback=False):
        return None
    if section.getboolean("Hidden", fallback=False):
        return None

    name = section.get("Name", "").strip()
    if not name:
        return None

    keywords = " ".join([name, section.get("Keywords", ""), section.get("GenericName", "")])
    return {
        "kind": "app",
        "id": os.path.basename(path),
        "name": name,
        "subtitle": section.get("Comment", "").strip() or section.get("GenericName", "Application"),
        "keywords": keywords.lower(),
        # The desktop entry's own icon name, resolved against the icon theme by
        # the shell. Empty is fine: the launcher falls back to a glyph.
        "icon": section.get("Icon", "").strip(),
        "exec": section.get("Exec", "").strip(),
        # The only field linking an entry to an open window, which the dock
        # uses to match running apps. Most entries omit it, so it is just
        # the first guess.
        "wmclass": section.get("StartupWMClass", "").strip(),
        # Freedesktop categories, which screen time groups by.
        "categories": [part for part in section.get("Categories", "").split(";") if part],
    }


def list_applications():
    applications = {}
    for directory in APPLICATION_DIRS:
        if not os.path.isdir(directory):
            continue
        try:
            entries = os.listdir(directory)
        except OSError as error:
            sys.stderr.write(f"Cannot read {directory}: {error}\n")
            continue
        for entry in entries:
            if not entry.endswith(".desktop") or entry in applications:
                continue
            application = read_entry(os.path.join(directory, entry))
            if application:
                applications[entry] = application
    return sorted(applications.values(), key=lambda app: app["name"].lower())


if __name__ == "__main__":
    print(json.dumps(list_applications()))
