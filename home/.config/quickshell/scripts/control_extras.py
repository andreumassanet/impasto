#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   C O N T R O L   E X T R A S                                            │
# │   control centre · image search and song recognition                     │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""The two control centre tiles that call outside tools.

`tools` reports which of them are installed; the shell lists a tile only when
its tools exist. `lens` selects a region, uploads it to uguu.se (temporary
public hosting) and opens Google Lens on the address; `music` records a few
seconds of what the speakers play, from the output's monitor, and names the
song. Both end in a notification, success or not. Nothing is uploaded unless
the shell started `lens`, which it does only with the `lensUpload` setting
on.
"""

import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.parse import quote

UPLOAD_ADDRESS = "https://uguu.se/upload"
LENS_ADDRESS = "https://lens.google.com/uploadbyurl?url="

# How long `music` records before it asks, and the size of an empty WAV file.
RECORD_SECONDS = 12
WAV_HEADER_BYTES = 44

TOOLS = ("grim", "slurp", "curl", "songrec", "parec")


def notify(title, body="", urgency="normal"):
    """Through the shell's own notification daemon, so it lands on the island."""
    subprocess.run(["notify-send", "-u", urgency, title, body],
                   stdin=subprocess.DEVNULL, check=False)


def run(command, **kwargs):
    """Run a tool with stdin closed unless it is given input.

    Children inherit a pipe from the shell, and a tool that reads stdin when it
    is not a terminal (slurp, for one) would block on it forever.
    """
    if "input" not in kwargs:
        kwargs.setdefault("stdin", subprocess.DEVNULL)
    try:
        return subprocess.run(command, capture_output=True, timeout=120, **kwargs)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"{command[0]} failed: {error}", file=sys.stderr)
        return None


def tools():
    print(json.dumps({name: bool(shutil.which(name)) for name in TOOLS}))


def lens(wait_s):
    # The control centre is closing; the selection must not catch it.
    time.sleep(wait_s)
    selection = run(["slurp"], text=True)
    if selection is None or selection.returncode != 0 or not selection.stdout.strip():
        return  # cancelled with Escape
    shot = run(["grim", "-g", selection.stdout.strip(), "-"])
    if shot is None or shot.returncode != 0 or not shot.stdout:
        notify("Lens", "The region could not be captured", "critical")
        return
    upload = run(["curl", "-sF", "files[]=@-;filename=lens.png", UPLOAD_ADDRESS],
                 input=shot.stdout)
    try:
        address = json.loads(upload.stdout)["files"][0]["url"]
        if not address.startswith("https://"):
            raise ValueError(address)
    except (AttributeError, ValueError, KeyError, IndexError, TypeError):
        notify("Lens", "The upload did not work", "critical")
        return
    run(["xdg-open", LENS_ADDRESS + quote(address, safe="")])


def monitor_source():
    """The default sink's monitor source: what the machine plays, not the microphone."""
    if not shutil.which("pactl"):
        return ""
    result = run(["pactl", "get-default-sink"], text=True)
    if result is None or result.returncode != 0 or not result.stdout.strip():
        return ""
    return result.stdout.strip() + ".monitor"


def record(source, path):
    """Record a monitor source to a WAV file for RECORD_SECONDS.

    `songrec listen` and `songrec recognize` print nothing from a PipeWire
    monitor, but recognising a recorded file works, so the sample is taken
    here. parec runs until it is told to stop, and a signal (not a kill) lets
    it finish the WAV header.
    """
    recorder = subprocess.Popen(
        ["parec", "-d", source, "--file-format=wav", "--rate=44100", "--channels=2", str(path)],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        recorder.wait(timeout=RECORD_SECONDS)  # returns early only if parec failed
    except subprocess.TimeoutExpired:
        recorder.terminate()
    recorder.wait()
    return path.exists() and path.stat().st_size > WAV_HEADER_BYTES


def music():
    source = monitor_source()
    if not source:
        notify("Song recognition", "There is no output to listen to", "critical")
        return
    notify("Listening…", "Recognising the song that is playing")
    track = None
    with tempfile.TemporaryDirectory() as directory:
        sample = pathlib.Path(directory) / "sample.wav"
        if not record(source, sample):
            notify("Song recognition", "Nothing could be recorded", "critical")
            return
        result = run(["songrec", "audio-file-to-recognized-song", str(sample)], text=True)
    if result is not None and result.returncode == 0:
        try:
            track = json.loads(result.stdout).get("track")
        except (ValueError, AttributeError):
            track = None
    if not (isinstance(track, dict) and track.get("title")):
        notify("Song recognition", "No song recognised")
        return
    notify("Song recognised", " — ".join(filter(None, [track["title"], track.get("subtitle")])))


def main():
    arguments = sys.argv[1:]
    action = arguments[0] if arguments else "tools"
    if action == "tools":
        tools()
    elif action == "lens":
        wait_s = float(arguments[2]) if len(arguments) > 2 and arguments[1] == "--wait" else 0.0
        lens(wait_s)
    elif action == "music":
        music()
    else:
        print("usage: control_extras.py [tools | lens [--wait SECONDS] | music]",
              file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
