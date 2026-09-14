#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   C L I P B O A R D                                                      │
# │   clipboard history · watch, store and restore                           │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Clipboard history: a watcher, a store, and restore.

Qt's clipboard on Wayland is only readable by a surface with keyboard focus,
so the selection is read through wlr-data-control with `wl-paste --watch`.
wl-clipboard reports password-manager offers (`x-kde-passwordManagerHint`) as
`CLIPBOARD_STATE=sensitive`, and those are never stored.

    clipboard.py watch [--keep N] [--images | --no-images]
    clipboard.py store [--keep N] [--images | --no-images]
    clipboard.py restore <key>
    clipboard.py forget <key>
    clipboard.py wipe

`watch` execs wl-paste, which runs `store` on every change with the content on
stdin and the same arguments. `store` prints nothing, since the watcher's
stdout is never read; the shell watches the store file instead.

Payloads are separate files under `clipboard/`. The JSON holds only metadata
and a preview, because the shell re-reads it on every copy, and it is replaced
whole each time, so the shell never reads half of it.
"""

import fcntl
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

# History length, and preview length in characters. The launcher searches the
# preview too, so it is longer than a row.
KEEP = 200
PREVIEW = 240

# Larger payloads are not kept.
LIMIT = 16 * 1024 * 1024

# The type password managers mark their offers with. wl-clipboard already
# reports those as `sensitive`; the type is checked as well.
SECRET = "x-kde-passwordManagerHint"

SUFFIXES = {
    "image/png": ".png",
    "image/jpeg": ".jpg",
    "image/webp": ".webp",
    "image/gif": ".gif",
    "image/bmp": ".bmp",
    "image/tiff": ".tiff",
}


def state_directory():
    root = os.environ.get("XDG_STATE_HOME") or f"{os.environ['HOME']}/.local/state"
    return Path(root) / "quickshell"


def store_path():
    return state_directory() / "clipboard.json"


def payload_directory():
    return state_directory() / "clipboard"


def types():
    """The MIME types of the current offer, or an empty list."""
    try:
        result = subprocess.run(["wl-paste", "--list-types"],
                                capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"wl-paste --list-types failed: {error}", file=sys.stderr)
        return []
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def image_type(offered):
    """The image type on offer, preferring the ones in SUFFIXES.

    An image copied from a browser is also offered as `text/html`, and
    wl-paste's inference picks the text, so the type list is checked directly.
    """
    images = [name for name in offered if name.startswith("image/")]
    if not images:
        return ""
    for name in SUFFIXES:
        if name in images:
            return name
    return images[0]


def read_offer(offered, stdin_bytes, keep_images):
    """Return (bytes, MIME type, kind) to store.

    Text is already on stdin. An image is read again by type, because stdin
    holds whatever type wl-paste inferred.
    """
    wanted = image_type(offered)
    if not wanted:
        return stdin_bytes, "text/plain;charset=utf-8", "text"
    if not keep_images:
        return b"", "", ""
    try:
        result = subprocess.run(["wl-paste", "--no-newline", "--type", wanted],
                                capture_output=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"wl-paste --type {wanted} failed: {error}", file=sys.stderr)
        return b"", "", ""
    if result.returncode != 0 or not result.stdout:
        return b"", "", ""
    return result.stdout, wanted, "image"


def preview_of(body):
    """A one-line preview with whitespace collapsed."""
    try:
        text = body.decode("utf-8")
    except UnicodeDecodeError:
        return ""
    return " ".join(text.split())[:PREVIEW]


def load():
    try:
        with open(store_path(), encoding="utf-8") as handle:
            kept = json.load(handle)
    except (OSError, ValueError):
        return []
    entries = kept.get("entries") if isinstance(kept, dict) else None
    return entries if isinstance(entries, list) else []


def save(entries):
    path = store_path()
    staging = f"{path}.{os.getpid()}.part"
    with open(staging, "w", encoding="utf-8") as handle:
        json.dump({"entries": entries}, handle, ensure_ascii=False)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(staging, path)


def opened():
    """Take the store's exclusive lock, held until the handle is closed.

    `store`, `forget` and `wipe` run as separate processes and can overlap.
    The lock is a file of its own, because `save` replaces the store.
    """
    directory = state_directory()
    directory.mkdir(parents=True, exist_ok=True)
    payload_directory().mkdir(parents=True, exist_ok=True)
    handle = open(directory / "clipboard.lock", "a", encoding="utf-8")
    fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
    return handle


def discard(entry, entries):
    """Delete an entry's payload unless another entry still references it.

    Keys derive from the content digest, so two entries can share a file.
    """
    path = entry.get("file", "")
    if any(other is not entry and other.get("file") == path for other in entries):
        return
    try:
        Path(path).unlink()
    except OSError:
        pass


def evict(entries, keep):
    while len(entries) > max(1, keep):
        discard(entries.pop(), entries)


def store(keep, keep_images):
    state = os.environ.get("CLIPBOARD_STATE", "data")
    # `sensitive` is a password manager; `clear` and `nil` mean the clipboard
    # was emptied.
    if state != "data":
        return

    offered = types()
    if any(SECRET in name for name in offered):
        return

    body = sys.stdin.buffer.read()
    body, mime, kind = read_offer(offered, body, keep_images)
    if not kind or not body or len(body) > LIMIT:
        return
    if kind == "text" and not body.strip():
        return

    digest = hashlib.sha256(body).hexdigest()

    with opened():
        entries = load()

        # Copied again: move it to the top with a new time. This also covers
        # restore, since wl-copy triggers the watcher with the same content.
        for index, entry in enumerate(entries):
            if entry.get("hash") == digest:
                entry["copied"] = int(time.time() * 1000)
                entries.insert(0, entries.pop(index))
                save(entries)
                return

        key = f"clip-{digest[:12]}"
        suffix = SUFFIXES.get(mime, ".txt" if kind == "text" else ".bin")
        path = payload_directory() / f"{key}{suffix}"
        try:
            path.write_bytes(body)
        except OSError as error:
            print(f"Cannot keep the clipboard entry: {error}", file=sys.stderr)
            return

        entries.insert(0, {
            "key": key,
            "hash": digest,
            "kind": kind,
            "mime": mime,
            "file": str(path),
            "preview": preview_of(body),
            "bytes": len(body),
            "copied": int(time.time() * 1000),
        })
        evict(entries, keep)
        save(entries)


def entry_for(entries, key):
    for entry in entries:
        if entry.get("key") == key:
            return entry
    return None


def restore(key):
    with opened():
        entry = entry_for(load(), key)
    if entry is None:
        print(json.dumps({"restored": False}))
        return
    path = Path(entry.get("file", ""))
    if not path.exists():
        print(f"The payload of {key} is gone", file=sys.stderr)
        print(json.dumps({"restored": False}))
        return
    # Output is not captured: wl-copy's forked daemon would hold the pipes.
    try:
        with path.open("rb") as body:
            subprocess.run(["wl-copy", "--type", entry.get("mime", "text/plain")],
                           stdin=body, timeout=10)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"wl-copy failed: {error}", file=sys.stderr)
        print(json.dumps({"restored": False}))
        return
    print(json.dumps({"restored": True, "key": key}))


def forget(key):
    with opened():
        entries = load()
        entry = entry_for(entries, key)
        if entry is None:
            print(json.dumps({"forgotten": False}))
            return
        entries.remove(entry)
        discard(entry, entries)
        save(entries)
    print(json.dumps({"forgotten": True, "key": key}))


def wipe():
    with opened():
        entries = load()
        for entry in entries:
            discard(entry, [])
        save([])
    # Clear the live selection too, in case it still holds a secret.
    try:
        subprocess.run(["wl-copy", "--clear"], timeout=5)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"wl-copy --clear failed: {error}", file=sys.stderr)
    print(json.dumps({"wiped": True}))


def watcher_pidfile():
    runtime = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    return Path(runtime) / "impasto-clipboard.pid"


def displace():
    """Stop the previous watcher and record this one.

    Quickshell does not kill `Process` children when it exits; they are
    reparented to systemd, so each shell restart would add another watcher.
    The pidfile lives in the runtime directory, and the process's command line
    is checked before signalling in case the pid was reused.
    """
    path = watcher_pidfile()
    try:
        previous = int(path.read_text().strip())
    except (OSError, ValueError):
        previous = 0
    if previous > 0 and previous != os.getpid():
        try:
            command = Path(f"/proc/{previous}/cmdline").read_bytes()
            if b"clipboard.py" in command:
                os.kill(previous, 15)
        except (OSError, ProcessLookupError):
            pass
    try:
        path.write_text(f"{os.getpid()}\n")
    except OSError as error:
        print(f"Cannot claim the watcher: {error}", file=sys.stderr)


def watch(rest):
    """Exec wl-paste with this script as its change handler.

    exec keeps the pid recorded by displace() valid and leaves no Python
    parent behind.
    """
    displace()
    try:
        os.execvp("wl-paste", ["wl-paste", "--watch",
                               sys.executable, os.path.abspath(__file__),
                               "store", *rest])
    except OSError as error:
        print(f"Cannot start wl-paste: {error}", file=sys.stderr)
        sys.exit(1)


def main():
    arguments = sys.argv[1:]
    action = arguments[0] if arguments else "watch"
    rest = arguments[1:]

    keep = KEEP
    if "--keep" in rest:
        at = rest.index("--keep")
        if at + 1 < len(rest):
            try:
                keep = max(1, int(rest[at + 1]))
            except ValueError:
                pass
    keep_images = "--no-images" not in rest

    if action == "watch":
        watch(rest)
    elif action == "store":
        store(keep, keep_images)
    elif action == "restore" and rest:
        restore(rest[0])
    elif action == "forget" and rest:
        forget(rest[0])
    elif action == "wipe":
        wipe()
    else:
        print("usage: clipboard.py [watch | store] [--keep N] "
              "[--images|--no-images] | restore <key> | forget <key> | wipe",
              file=sys.stderr)
        print(json.dumps({"error": f"No such action: {action}"}))


if __name__ == "__main__":
    main()
