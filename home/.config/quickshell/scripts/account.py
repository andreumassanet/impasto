#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   A C C O U N T                                                          │
# │   the account's name and picture · read and change them                  │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""The account's full name and picture: read them, and change them.

The name is the GECOS field, changed through AccountsService, which lets the
active user change their own without a password. The picture is the first
conventional path that exists, and is changed through /usr/lib/impasto/avatar
under pkexec: the picture is read and made square here, as the user, and only
the PNG that comes out reaches the helper.

    get                 {user, name, fullName, avatar, accounts, shared} as JSON
    name <text>         the account's full name
    picture <path>      the picture, square, where both screens read it
    picture --clear     no picture
"""

import json
import os
import pwd
import subprocess
import sys

HELPER = "/usr/lib/impasto/avatar"
POLICY = "/usr/share/polkit-1/actions/org.impasto.avatar.policy"

# The picture both screens get: square, and small enough for a login screen.
SIDE = 256

# The greeter's FacesDir comes first: sddm runs as its own user and cannot read
# a 0700 $HOME, so it is the only location the lock screen and the login screen
# can share. The rest are fallbacks for a machine without `./setup system`.
AVATARS = (
    "/var/lib/impasto/faces/{user}.face.icon",
    "~/.face",
    "~/.face.icon",
    "/var/lib/AccountsService/icons/{user}",
)


def account():
    try:
        record = pwd.getpwuid(os.getuid())
    except KeyError:
        return {"user": "", "name": "", "avatar": None}

    user = record.pw_name

    # GECOS is comma-separated (name, office, phones); only the name is used,
    # and the login name stands in when it is empty.
    full = (record.pw_gecos or "").split(",")[0].strip()
    name = full or user

    avatar = None
    for candidate in AVATARS:
        path = os.path.expanduser(candidate.format(user=user))
        if os.path.isfile(path):
            avatar = path
            break

    return {"user": user, "name": name, "fullName": full, "avatar": avatar,
            "accounts": account_path(user) is not None, "shared": shared()}


def shared():
    """The helper and its policy are there: ./setup system has run since."""
    return os.access(HELPER, os.X_OK) and os.path.isfile(POLICY)


def account_path(user):
    """AccountsService's object for the user, or None where it is not running."""
    try:
        found = subprocess.run(
            ["busctl", "--json=short", "call", "org.freedesktop.Accounts",
             "/org/freedesktop/Accounts", "org.freedesktop.Accounts",
             "FindUserByName", "s", user],
            capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if found.returncode != 0:
        return None
    try:
        return json.loads(found.stdout)["data"][0]
    except (ValueError, KeyError, IndexError):
        return None


def set_name(name):
    user = pwd.getpwuid(os.getuid()).pw_name
    path = account_path(user)
    if path is None:
        return "AccountsService is not running"
    done = subprocess.run(
        ["busctl", "call", "org.freedesktop.Accounts", path,
         "org.freedesktop.Accounts.User", "SetRealName", "s", "--", name.strip()],
        capture_output=True, text=True, timeout=10)
    return None if done.returncode == 0 else done.stderr.strip() or "not changed"


def set_picture(path):
    if not shared():
        return "the picture helper is not installed (./setup system)"
    try:
        square = subprocess.run(
            ["magick", f"{path}[0]", "-auto-orient", "-thumbnail", f"{SIDE}x{SIDE}^",
             "-gravity", "center", "-extent", f"{SIDE}x{SIDE}", "-strip", "png:-"],
            capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as error:
        return f"could not read the picture: {error}"
    if square.returncode != 0 or not square.stdout:
        return "could not read the picture"
    done = subprocess.run(["pkexec", HELPER, "set"], input=square.stdout,
                          capture_output=True, timeout=60)
    return None if done.returncode == 0 else "not changed"


def clear_picture():
    if not shared():
        return "the picture helper is not installed (./setup system)"
    done = subprocess.run(["pkexec", HELPER, "clear"], capture_output=True, timeout=60)
    return None if done.returncode == 0 else "not changed"


def main():
    args = sys.argv[1:] or ["get"]
    if args == ["get"]:
        print(json.dumps(account()))
        return
    if len(args) == 2 and args[0] == "name":
        error = set_name(args[1])
    elif len(args) == 2 and args[0] == "picture":
        error = clear_picture() if args[1] == "--clear" else set_picture(args[1])
    else:
        sys.stderr.write("Usage: account.py [get] | name <text> | picture <path> | picture --clear\n")
        sys.exit(1)
    print(json.dumps({"error": error}))
    sys.exit(0 if error is None else 1)


if __name__ == "__main__":
    main()
