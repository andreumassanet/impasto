#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   C A P T U R E                                                          │
# │   screenshots · capture and crop                                         │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Screen capture: grab the whole screen, then crop and deliver.

`grab` saves a full-screen grim shot and prints its path; the shell's overlay
draws it and the selection is made on top of it. `finish` crops that picture
with ImageMagick and saves it, copies it, opens it in satty or runs tesseract.

Selecting on a still picture means the crop is exactly what was on screen when
the key was pressed, with no second capture and no screen freeze. A missing
tool is reported, never a crash, and nothing is saved or copied on failure.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

# Saved file names; sorts chronologically as text.
STAMP = "%Y-%m-%d-%H%M%S"

DESTINATIONS = ("file", "clipboard", "editor", "text")


def run(command, **kwargs):
    """Run a tool with stdin closed.

    Children inherit a pipe from the shell, and a tool that reads stdin when it
    is not a terminal (slurp, for one) would block on it forever.
    """
    kwargs.setdefault("stdin", subprocess.DEVNULL)
    try:
        return subprocess.run(command, capture_output=True, text=True,
                              timeout=120, **kwargs)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"{command[0]} failed: {error}", file=sys.stderr)
        return None


def report(**fields):
    print(json.dumps(fields))


def runtime():
    return Path(os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir())


def directory():
    """Where saved captures go.

    $IMPASTO_CAPTURES or $HYPRSHOT_DIR (both set in `env.lua`), then the XDG
    pictures directory, then $HOME.
    """
    for key in ("IMPASTO_CAPTURES", "HYPRSHOT_DIR"):
        value = os.environ.get(key)
        if value:
            return Path(value).expanduser()
    if shutil.which("xdg-user-dir"):
        result = run(["xdg-user-dir", "PICTURES"])
        if result is not None and result.stdout.strip():
            return Path(result.stdout.strip())
    return Path.home()


def copy(*arguments, feed=None):
    """Run wl-copy without capturing its output.

    wl-copy forks a daemon that keeps serving the selection and inherits the
    pipes, so capturing output would block until the timeout.
    """
    if not shutil.which("wl-copy"):
        return False
    try:
        completed = subprocess.run(["wl-copy", *arguments],
                                   stdin=feed or subprocess.DEVNULL,
                                   stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL, timeout=20)
        return completed.returncode == 0
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"wl-copy failed: {error}", file=sys.stderr)
        return False


def copy_image(path):
    try:
        with open(path, "rb") as picture:
            return copy("-t", "image/png", feed=picture)
    except OSError as error:
        print(f"cannot read {path}: {error}", file=sys.stderr)
        return False


def languages():
    """The installed subset of Spanish and English for tesseract.

    Language packs are separate packages, and requesting a missing one fails.
    """
    result = run(["tesseract", "--list-langs"])
    if result is None or result.returncode != 0:
        return "eng"
    installed = {line.strip() for line in result.stdout.splitlines()[1:]}
    wanted = [name for name in ("spa", "eng") if name in installed]
    return "+".join(wanted) if wanted else "eng"


def read_text(path):
    result = run(["tesseract", str(path), "-", "-l", languages()])
    if result is None or result.returncode != 0:
        if result is not None:
            print(result.stderr.strip(), file=sys.stderr)
        return None
    return result.stdout.strip()


def magick():
    """ImageMagick 7 is `magick` and 6 is `convert`; both crop the same."""
    for name in ("magick", "convert"):
        if shutil.which(name):
            return name
    return ""


def tools():
    report(**{
        "grim": bool(shutil.which("grim")),
        "crop": bool(magick()),
        "clipboard": bool(shutil.which("wl-copy")),
        "editor": bool(shutil.which("satty")),
        "text": bool(shutil.which("tesseract")),
        "directory": str(directory()),
    })


def grab(output=""):
    """Capture one screen into the runtime directory.

    Every crop is cut from this picture, so the result is what was on screen
    when the key was pressed, including menus that close once the pointer moves.
    Without an output name grim takes every screen side by side, which is a
    picture of no single one.
    """
    if not shutil.which("grim"):
        report(error="grim is not installed")
        return
    handle, name = tempfile.mkstemp(prefix="impasto-grab-", suffix=".png",
                                    dir=str(runtime()))
    os.close(handle)
    path = Path(name)
    command = ["grim"]
    if output:
        command += ["-o", output]
    result = run(command + [str(path)])
    if result is None or result.returncode != 0:
        path.unlink(missing_ok=True)
        report(error="grim took nothing")
        return

    # Pixel size differs from logical size on a scaled screen; the overlay
    # needs both to map its selection to a crop.
    width, height = 0, 0
    tool = magick()
    if tool:
        size = run([tool, "identify", "-format", "%w %h", str(path)])
        if size is not None and size.returncode == 0:
            try:
                width, height = (int(part) for part in size.stdout.split()[:2])
            except ValueError:
                pass
    report(path=str(path), width=width, height=height)


def parse(geometry):
    """Parse `x,y wxh`, grim's geometry format; None for anything else."""
    try:
        where, size = geometry.split(" ")
        x, y = (int(part) for part in where.split(","))
        width, height = (int(part) for part in size.split("x"))
    except (ValueError, AttributeError):
        return None
    if width <= 0 or height <= 0:
        return None
    return x, y, width, height


def cut_out(picture, geometry):
    """Crop the rectangle, or return the whole picture when there is none.

    Returns the path to use, or None after reporting an error.
    """
    box = parse(geometry) if geometry else None
    if box is None:
        return picture

    tool = magick()
    if not tool:
        picture.unlink(missing_ok=True)
        report(error="ImageMagick is not installed")
        return None

    x, y, width, height = box
    cut = runtime() / f"impasto-cut-{datetime.now().strftime(STAMP)}.png"
    # Without `+repage` the crop keeps the original canvas offset, and viewers
    # draw it inside a full-screen canvas.
    result = run([tool, str(picture), "-crop", f"{width}x{height}+{x}+{y}",
                  "+repage", str(cut)])
    picture.unlink(missing_ok=True)
    if result is None or result.returncode != 0:
        cut.unlink(missing_ok=True)
        report(error="Could not cut the picture")
        return None
    return cut


def keep(cut, stamp):
    """Move the capture into the captures directory under a timestamped name."""
    folder = directory()
    try:
        folder.mkdir(parents=True, exist_ok=True)
    except OSError as error:
        cut.unlink(missing_ok=True)
        report(error=f"Cannot write to {folder}: {error}")
        return None
    saved = folder / f"{stamp}_impasto.png"
    try:
        shutil.move(str(cut), saved)
    except OSError as error:
        cut.unlink(missing_ok=True)
        report(error=f"Cannot save it: {error}")
        return None
    return saved


def finish(source, geometry, destination):
    picture = Path(source)
    if not picture.exists():
        report(error="The picture is gone")
        return
    if destination == "editor" and not shutil.which("satty"):
        picture.unlink(missing_ok=True)
        report(error="satty is not installed")
        return
    if destination == "text" and not shutil.which("tesseract"):
        picture.unlink(missing_ok=True)
        report(error="tesseract is not installed")
        return

    cut = cut_out(picture, geometry)
    if cut is None:
        return
    stamp = datetime.now().strftime(STAMP)

    if destination == "file":
        saved = keep(cut, stamp)
        if saved is None:
            return
        # Saved and copied, so there is nothing to choose at capture time.
        report(to="file", path=str(saved), copied=copy_image(saved))
        return

    if destination == "clipboard":
        copied = copy_image(cut)
        cut.unlink(missing_ok=True)
        report(to="clipboard", copied=copied)
        return

    if destination == "editor":
        folder = directory()
        try:
            folder.mkdir(parents=True, exist_ok=True)
        except OSError as error:
            cut.unlink(missing_ok=True)
            report(error=f"Cannot write to {folder}: {error}")
            return
        saved = folder / f"{stamp}_impasto.png"
        # Detached: satty outlives this script and owns its output and the
        # temporary file from here. Not `--fullscreen`; `windowrules.lua`
        # floats and centres it.
        try:
            subprocess.Popen(
                ["satty", "--filename", str(cut),
                 "--output-filename", str(saved),
                 "--early-exit", "--copy-command", "wl-copy"],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as error:
            cut.unlink(missing_ok=True)
            report(error=f"satty failed: {error}")
            return
        report(to="editor", path=str(saved))
        return

    text = read_text(cut)
    cut.unlink(missing_ok=True)
    if not text:
        report(to="text", characters=0)
        return
    report(to="text", characters=len(text), copied=copy("--", text))


def drop(source):
    """Cancel a capture and delete its picture."""
    Path(source).unlink(missing_ok=True)
    report(cancelled=True)


def main():
    arguments = sys.argv[1:]
    action = arguments[0] if arguments else "tools"

    if action == "tools":
        tools()
        return
    if action == "grab":
        output = ""
        if "--output" in arguments:
            at = arguments.index("--output")
            if at + 1 < len(arguments):
                output = arguments[at + 1]
        grab(output)
        return
    if action == "drop" and len(arguments) > 1:
        drop(arguments[1])
        return
    if action != "finish" or len(arguments) < 2:
        print("usage: capture.py [tools | grab [--output <screen>] | drop <picture> | "
              "finish <picture> [--geometry 'x,y wxh'] "
              f"[--to {'|'.join(DESTINATIONS)}]]", file=sys.stderr)
        report(error=f"No such capture: {action}")
        return

    source = arguments[1]
    geometry = ""
    destination = "file"
    rest = arguments[2:]
    while rest:
        flag = rest.pop(0)
        if flag == "--geometry" and rest:
            geometry = rest.pop(0)
        elif flag == "--to" and rest:
            destination = rest.pop(0)
    if destination not in DESTINATIONS:
        report(error=f"No such destination: {destination}")
        return

    finish(source, geometry, destination)


if __name__ == "__main__":
    main()
