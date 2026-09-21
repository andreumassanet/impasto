#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   R E C O R D                                                            │
# │   screen recording · start, monitor and stop                             │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Screen recording: start, stop and report status.

Uses `wl-screenrec` (GPU encoding) when installed, else `wf-recorder`; with
neither, there is no recording.

A recording outlives the shell, so its state is a file in the runtime
directory, and a restarted shell finds a running take through `status`.

Recordings are stopped with SIGINT: both encoders finalise the container on an
interrupt and leave an unplayable file on SIGTERM.
"""

import json
import os
import shutil
import signal
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# GPU encoder first. Both accept `-g "x,y wxh"`, `-f <file>` and an audio flag.
ENCODERS = ("wl-screenrec", "wf-recorder")

# What is being recorded. A window and a region both arrive as a rectangle, so
# the shape is kept in the state file for `status`.
SHAPES = ("screen", "region", "window")

STAMP = "%Y-%m-%d-%H%M%S"

# Where the pid and the path live while a take is running. The runtime
# directory, so a reboot cannot leave a stale one behind.
STATE = "impasto-recording.json"


def run(command, **kwargs):
    """Run a command with stdin closed, as in `capture.py`."""
    kwargs.setdefault("stdin", subprocess.DEVNULL)
    try:
        return subprocess.run(command, capture_output=True, text=True,
                              timeout=120, **kwargs)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"{command[0]} failed: {error}", file=sys.stderr)
        return None


def report(**fields):
    print(json.dumps(fields))


def state_path():
    runtime = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    return Path(runtime) / STATE


def read_state():
    try:
        return json.loads(state_path().read_text())
    except (OSError, json.JSONDecodeError):
        return None


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except (OSError, TypeError):
        return False


def weight(path):
    """Bytes written so far; 0 if the encoder has not created the file yet."""
    try:
        return Path(path).stat().st_size
    except (OSError, TypeError, ValueError):
        return 0


def encoders():
    """Every encoder installed, best first. More than one matters: on some
    cards wl-screenrec cannot negotiate a capture format and dies at once,
    and the take goes to the next one rather than failing."""
    return [name for name in ENCODERS if shutil.which(name)]


def directory():
    """Where recordings go: $IMPASTO_RECORDINGS (set in `env.lua`), then the
    XDG videos directory, then $HOME."""
    value = os.environ.get("IMPASTO_RECORDINGS")
    if value:
        return Path(value).expanduser()
    if shutil.which("xdg-user-dir"):
        result = run(["xdg-user-dir", "VIDEOS"])
        if result is not None and result.stdout.strip():
            return Path(result.stdout.strip())
    return Path.home()


def monitor_source():
    """The default sink's monitor source.

    Given a bare audio flag, both encoders record the default input, which is
    the microphone; a screen recording wants what the machine plays instead.
    """
    if not shutil.which("pactl"):
        return ""
    result = run(["pactl", "get-default-sink"])
    if result is None or result.returncode != 0:
        return ""
    sink = result.stdout.strip()
    return f"{sink}.monitor" if sink else ""


def command_for(tool, geometry, path, audio, output=""):
    command = [tool, "-f", str(path)]
    if geometry:
        command += ["-g", geometry]
    elif output:
        # Without one, both encoders take whichever screen they list first.
        command += ["-o", output]
    if audio:
        source = monitor_source()
        if tool == "wl-screenrec":
            command.append("--audio")
            if source:
                command += ["--audio-device", source]
        else:
            command.append(f"--audio={source}" if source else "--audio")
    return command


def tools():
    report(**{
        "tool": next(iter(encoders()), ""),
        "wl-screenrec": bool(shutil.which("wl-screenrec")),
        "wf-recorder": bool(shutil.which("wf-recorder")),
        "audio": bool(monitor_source()),
        "directory": str(directory()),
    })


def status():
    kept = read_state()
    if not kept or not alive(kept.get("pid")):
        if kept:
            state_path().unlink(missing_ok=True)
        report(recording=False)
        return
    report(recording=True, path=kept.get("path"), started=kept.get("started"),
           seconds=int(time.time() - kept.get("started", time.time())),
           tool=kept.get("tool"), audio=kept.get("audio", False),
           shape=kept.get("shape", "screen"),
           size=weight(kept.get("path", "")))


def start(geometry, audio, shape, output=""):
    """Record one screen, or the rectangle from the capture overlay."""
    kept = read_state()
    if kept and alive(kept.get("pid")):
        report(error="Already recording")
        return

    tools_found = encoders()
    if not tools_found:
        report(error="No screen recorder installed")
        return

    folder = directory()
    try:
        folder.mkdir(parents=True, exist_ok=True)
    except OSError as error:
        report(error=f"Cannot write to {folder}: {error}")
        return
    path = folder / f"{datetime.now().strftime(STAMP)}_impasto.mp4"

    process = None
    for tool in tools_found:
        try:
            # Its own session, so the encoder is not a child of whatever
            # pressed the key: the shell may be restarted mid-take and the
            # take goes on.
            started = subprocess.Popen(
                command_for(tool, geometry, path, audio, output),
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError:
            continue

        # One that rejects its arguments, or cannot capture at all, exits
        # immediately. Try the next rather than report a take that is over.
        time.sleep(0.25)
        if started.poll() is None:
            process = started
            break
        path.unlink(missing_ok=True)

    if process is None:
        report(error=f"{tools_found[0]} would not start")
        return

    kept = {"pid": process.pid, "path": str(path), "started": time.time(),
            "tool": tool, "audio": audio, "shape": shape}
    try:
        state_path().write_text(json.dumps(kept))
    except OSError as error:
        print(f"cannot write the state file: {error}", file=sys.stderr)
    report(recording=True, path=str(path), tool=tool, audio=audio,
           shape=shape, size=0)


def stop():
    kept = read_state()
    if not kept or not alive(kept.get("pid")):
        state_path().unlink(missing_ok=True)
        report(recording=False)
        return

    # SIGINT, not SIGTERM: it is what closes the container.
    try:
        os.kill(kept["pid"], signal.SIGINT)
    except OSError as error:
        report(error=f"Cannot stop it: {error}")
        return

    deadline = time.monotonic() + 5
    while time.monotonic() < deadline and alive(kept["pid"]):
        time.sleep(0.05)

    state_path().unlink(missing_ok=True)
    path = Path(kept.get("path", ""))
    report(recording=False, path=str(path),
           seconds=int(time.time() - kept.get("started", time.time())),
           size=weight(path))


def main():
    arguments = sys.argv[1:]
    action = arguments[0] if arguments else "status"
    audio = "--audio" in arguments
    geometry = ""
    if "--geometry" in arguments:
        at = arguments.index("--geometry")
        if at + 1 < len(arguments):
            geometry = arguments[at + 1]
    output = ""
    if "--output" in arguments:
        at = arguments.index("--output")
        if at + 1 < len(arguments):
            output = arguments[at + 1]
    shape = "region" if geometry else "screen"
    if "--shape" in arguments:
        at = arguments.index("--shape")
        if at + 1 < len(arguments) and arguments[at + 1] in SHAPES:
            shape = arguments[at + 1]

    if action == "tools":
        tools()
    elif action == "status":
        status()
    elif action == "start":
        start(geometry, audio, shape, output)
    elif action == "stop":
        stop()
    else:
        print("usage: record.py [tools|status|start|stop] "
              "[--geometry 'x,y wxh'] [--output <screen>] "
              "[--shape screen|region|window] "
              "[--audio]", file=sys.stderr)
        report(error=f"No such action: {action}")


if __name__ == "__main__":
    main()
