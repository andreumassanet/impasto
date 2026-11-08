#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   S O N G                                                                │
# │   control centre · name the song that is playing                         │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""The control centre's Song tile.

`tools` reports whether songrec and parec are installed; the shell lists the
tile only when both are. `listen` records a few seconds of what the speakers
play, from the output's monitor, and names the song in a notification,
success or not.
"""

import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

# How long `music` records before it asks, and the size of an empty WAV file.
RECORD_SECONDS = 12
WAV_HEADER_BYTES = 44

TOOLS = ("songrec", "parec")


def notify(title, body="", urgency="normal"):
    """Through the shell's own notification daemon, so it lands on the island."""
    subprocess.run(["notify-send", "-u", urgency, title, body],
                   stdin=subprocess.DEVNULL, check=False)


def run(command, **kwargs):
    """Run a tool with stdin closed unless it is given input.

    Children inherit a pipe from the shell, and a tool that reads stdin when it
    is not a terminal would block on it forever.
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
    try:
        recorder.wait(timeout=3)
    except subprocess.TimeoutExpired:
        # A recorder that ignores the signal must not hang the helper.
        recorder.kill()
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
    elif action == "listen":
        music()
    else:
        print("usage: song.py [tools | listen]",
              file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
