#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   C A M E R A . P Y                                                      │
# │   camera effects · the webcam, filtered, into a virtual camera           │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Feed the "impasto camera" loopback device with the webcam, filtered.

Usage: camera.py status
       camera.py configure <json>
       camera.py snap
       camera.py serve
       camera.py run          (started by serve, never by hand)

`status` prints whether the effects can run and what is missing.
`configure` writes the effect, the reactions and the palette for `run`.
`snap` saves the next frame, mirrored as the preview shows it, into the
camera's folder and copies it, while something is streaming.

`serve` holds the loopback device and waits. It opens the webcam only while
some program streams from the virtual camera, which v4l2loopback announces
with an event, so at rest it reads nothing and uses no processor. While
something streams it runs `run` as a child, which captures, applies the
chosen effect and the hand-gesture reactions, and writes the frames.

Both print JSON lines on stdout. The effect, the reactions and the palette
are read from $XDG_RUNTIME_DIR/impasto-camera/config.json, which
`configure` writes for the shell.
"""

import fcntl
import importlib.util
import json
import math
import os
import random
import select
import shutil
import signal
import struct
import subprocess
import sys
import time
import zipfile
from pathlib import Path

LABEL = "impasto camera"
WIDTH, HEIGHT, FPS = 1280, 720, 30

RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "impasto-camera"
CONFIG = RUNTIME / "config.json"
PIDFILE = RUNTIME / "serve.pid"
SNAP = RUNTIME / "snap.request"
MODELS = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "impasto/camera"
EMOJI_FONT = "/usr/share/fonts/noto/NotoColorEmoji.ttf"
MODEL_FILES = ["face_landmarker.task", "gesture_recognizer.task", "selfie_segmenter.tflite"]

# V4L2, from linux/videodev2.h and v4l2loopback.c.
VIDIOC_QUERYCAP = 0x80685600
VIDIOC_ENUM_FMT = 0xC0405602
VIDIOC_S_FMT = 0xC0D05605
VIDIOC_DQEVENT = 0x80885659
VIDIOC_SUBSCRIBE_EVENT = 0x4020565A
CAP_VIDEO_CAPTURE = 0x00000001
BUF_TYPE_CAPTURE, BUF_TYPE_OUTPUT = 1, 2
EVENT_CLIENT_USAGE = 0x08000000 + 0x08E00000 + 1
EVENT_SEND_INITIAL = 1


def canonical_face():
    """MediaPipe's canonical face, 468 points in centimetres (y up, z toward
    the camera), read from the geometry metadata inside the landmarker's own
    bundle: a protobuf whose first message holds the vertex buffer, five
    floats a vertex (x, y, z, u, v), as field 3."""
    with zipfile.ZipFile(MODELS / "face_landmarker.task") as bundle:
        data = bundle.read("geometry_pipeline_metadata_landmarks.binarypb")

    def varint(at):
        value = shift = 0
        while True:
            byte = data[at]
            at += 1
            value |= (byte & 0x7F) << shift
            shift += 7
            if byte < 0x80:
                return value, at

    _, at = varint(0)
    size, at = varint(at)
    end = at + size
    floats = []
    while at < end:
        key, at = varint(at)
        field, kind = key >> 3, key & 7
        if kind == 0:
            _, at = varint(at)
        elif kind == 5:
            if field == 3:
                floats.append(struct.unpack_from("<f", data, at)[0])
            at += 4
        elif kind == 1:
            at += 8
        elif kind == 2:
            length, at = varint(at)
            if field == 3:
                floats += struct.unpack_from(f"<{length // 4}f", data, at)
            at += length
    return [floats[i:i + 3] for i in range(0, len(floats), 5)]


def say(**fields):
    print(json.dumps(fields), flush=True)


def fourcc(code):
    return struct.unpack("<I", code.encode())[0]


# ── DEVICES ─────────────────────────────────────────────────────────────────


def devices():
    """(path, name) for every video device, in number order."""
    found = []
    for node in sorted(Path("/sys/class/video4linux").glob("video*"),
                       key=lambda p: int(p.name[5:] or 0)):
        try:
            name = (node / "name").read_text().strip()
        except OSError:
            name = ""
        found.append((f"/dev/{node.name}", name))
    return found


def loopback():
    return next((path for path, name in devices() if name == LABEL), None)


def formats(path):
    """The capture formats a device offers, or none if it captures nothing."""
    try:
        fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
    except OSError:
        return []
    try:
        cap = bytearray(104)
        fcntl.ioctl(fd, VIDIOC_QUERYCAP, cap)
        if not struct.unpack_from("<I", cap, 88)[0] & CAP_VIDEO_CAPTURE:
            return []
        out = []
        for index in range(32):
            desc = bytearray(struct.pack("<II", index, BUF_TYPE_CAPTURE).ljust(64, b"\0"))
            try:
                fcntl.ioctl(fd, VIDIOC_ENUM_FMT, desc)
            except OSError:
                break
            out.append(desc[44:48].decode("ascii", "replace"))
        return out
    except OSError:
        return []
    finally:
        os.close(fd)


def webcam():
    """The first colour camera: one that captures, and not only 8-bit grey,
    which is the infrared half of a face-unlock camera."""
    for path, name in devices():
        if name == LABEL:
            continue
        offered = formats(path)
        if offered and any(code != "GREY" for code in offered):
            return path
    return None


def status():
    missing = []
    if not loopback():
        missing.append("loopback")
    if not webcam():
        missing.append("camera")
    for module in ("cv2", "mediapipe", "numpy"):
        if importlib.util.find_spec(module) is None:
            missing.append(module)
    if any(not (MODELS / name).is_file() for name in MODEL_FILES):
        missing.append("models")
    say(ready=not missing, missing=missing, camera=webcam(), loopback=loopback())


def configure(text):
    try:
        data = json.loads(text)
    except ValueError as error:
        print(f"Not JSON: {error}", file=sys.stderr)
        sys.exit(1)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    staging = CONFIG.with_suffix(f".{os.getpid()}.part")
    staging.write_text(json.dumps(data))
    os.replace(staging, CONFIG)
    say(configured=True)


def photos(quietly):
    """Where the photos go: $IMPASTO_CAMERA (set in `env.lua`), else what
    `env.lua` would set: XDG_CAMERA_DIR from user-dirs.dirs, or Camera in the
    XDG pictures directory, as GNOME's camera does."""
    value = os.environ.get("IMPASTO_CAMERA")
    if value:
        return Path(value).expanduser()
    if shutil.which("xdg-user-dir"):
        for name, under in (("CAMERA", ""), ("PICTURES", "Camera")):
            result = quietly(["xdg-user-dir", name])
            found = result.stdout.strip() if result is not None else ""
            # xdg-user-dir answers $HOME for a name it does not know.
            if found and Path(found) != Path.home():
                return Path(found) / under
    return Path.home() / "Camera"


def suffix():
    """What follows the time in a saved photo's name; see capture.py."""
    return os.environ.get("IMPASTO_CAPTURE_SUFFIX", "_impasto")


def snap():
    """Ask the running `run` for its next frame, mirrored, then keep it in the
    camera's folder and copy it, as a capture does."""
    from capture import STAMP, copy_image, run as quietly
    from datetime import datetime

    stamp = datetime.now().strftime(STAMP)
    taken = RUNTIME / f"snap-{stamp}.png"
    RUNTIME.mkdir(parents=True, exist_ok=True)
    SNAP.write_text(str(taken))
    for _ in range(40):
        if taken.exists():
            break
        time.sleep(.05)
    else:
        SNAP.unlink(missing_ok=True)
        say(error="The camera is not running")
        return
    folder = photos(quietly)
    try:
        folder.mkdir(parents=True, exist_ok=True)
        saved = folder / f"{stamp}{suffix()}.png"
        shutil.move(str(taken), saved)
    except OSError as error:
        taken.unlink(missing_ok=True)
        say(error=f"Cannot save it: {error}")
        return
    say(saved=str(saved), copied=copy_image(saved))


# ── SERVE ───────────────────────────────────────────────────────────────────


def displace():
    """Stop the previous server and record this one: a `Process` child
    outlives the shell. The command line is read before signalling, since a
    pid gets reused."""
    RUNTIME.mkdir(parents=True, exist_ok=True)
    try:
        previous = int(PIDFILE.read_text().strip())
    except (OSError, ValueError):
        previous = 0
    if previous > 0 and previous != os.getpid():
        try:
            if b"camera.py" in Path(f"/proc/{previous}/cmdline").read_bytes():
                os.kill(previous, signal.SIGTERM)
                for _ in range(30):
                    time.sleep(0.1)
                    os.kill(previous, 0)
        except (OSError, ProcessLookupError):
            pass
    PIDFILE.write_text(f"{os.getpid()}\n")


def claim(path):
    """Open the loopback device as its writer, in the frame format `run`
    writes, and put one dark frame in it so a reader that starts before the
    webcam is up gets a picture rather than a wait."""
    fd = os.open(path, os.O_RDWR)
    size = WIDTH * HEIGHT * 3 // 2
    pix = struct.pack("<12I", WIDTH, HEIGHT, fourcc("YU12"), 1, WIDTH, size, 8, 0, 0, 0, 0, 0)
    fmt = bytearray((struct.pack("<II", BUF_TYPE_OUTPUT, 0) + pix).ljust(208, b"\0"))
    fcntl.ioctl(fd, VIDIOC_S_FMT, fmt)
    os.write(fd, bytes([16]) * (WIDTH * HEIGHT) + bytes([128]) * (WIDTH * HEIGHT // 2))
    sub = struct.pack("<3I5I", EVENT_CLIENT_USAGE, 0, EVENT_SEND_INITIAL, 0, 0, 0, 0, 0)
    fcntl.ioctl(fd, VIDIOC_SUBSCRIBE_EVENT, sub)
    return fd


def readers(path):
    """Names of the other programs holding the virtual camera open: not this
    server, nor the child it hands the device to."""
    names = set()
    for fd_dir in Path("/proc").glob("[0-9]*/fd"):
        try:
            if b"camera.py" in (fd_dir.parent / "cmdline").read_bytes():
                continue
            if not any(os.readlink(fd_dir / fd) == path for fd in os.listdir(fd_dir)):
                continue
            names.add((fd_dir.parent / "comm").read_text().strip())
        except OSError:
            continue
    return sorted(names)


def serve():
    displace()
    path = loopback()
    if not path:
        say(state="error", error="loopback")
        sys.exit(1)
    # A server displaced a moment ago may still be letting go of the device.
    for attempt in range(25):
        try:
            fd = claim(path)
            break
        except OSError as error:
            if attempt == 24:
                say(state="error", error=f"loopback: {error.strerror}")
                sys.exit(1)
            time.sleep(.2)

    child = None

    def stop_child():
        nonlocal child
        if child and child.poll() is None:
            child.send_signal(signal.SIGTERM)
            try:
                child.wait(3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        child = None

    def leave(*_):
        stop_child()
        sys.exit(0)

    signal.signal(signal.SIGTERM, leave)
    signal.signal(signal.SIGINT, leave)

    say(state="idle", readers=[])
    poll = select.poll()
    poll.register(fd, select.POLLPRI)
    seen = []
    scanned = 0.0
    while True:
        # The child's exit, and readers joining a stream already running,
        # which raise no event, are noticed within a second or two.
        if not poll.poll(1500):
            if child and child.poll() is not None:
                code = child.returncode
                child = None
                say(state="idle" if code == 0 else "error", readers=readers(path))
            elif child and time.monotonic() - scanned > 5:
                # Reading every process's descriptors is not free: a few
                # seconds late is fine for a name on the panel.
                scanned = time.monotonic()
                now = readers(path)
                if now != seen:
                    seen = now
                    say(readers=now)
            continue
        event = bytearray(136)
        try:
            fcntl.ioctl(fd, VIDIOC_DQEVENT, event)
        except OSError:
            continue
        kind = struct.unpack_from("<I", event, 0)[0]
        if kind != EVENT_CLIENT_USAGE:
            continue
        streaming = struct.unpack_from("<I", event, 8)[0] > 0
        if streaming and not (child and child.poll() is None):
            child = subprocess.Popen([sys.executable, os.path.abspath(__file__), "run", str(fd)],
                                     pass_fds=(fd,))
            seen = readers(path)
            say(state="live", readers=seen)
        elif not streaming:
            stop_child()
            seen = []
            say(state="idle", readers=[])


# ── RUN ─────────────────────────────────────────────────────────────────────


def hex_rgb(value, fallback):
    try:
        value = value.lstrip("#")[-6:]
        return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))
    except (AttributeError, ValueError):
        return fallback


def read_config(last):
    try:
        mtime = CONFIG.stat().st_mtime
    except OSError:
        return last, None
    if last and last.get("_mtime") == mtime:
        return last, None
    try:
        data = json.loads(CONFIG.read_text())
    except (OSError, ValueError):
        return last, None
    data["_mtime"] = mtime
    return data, data


def run(out_fd):
    # MediaPipe's own logging, which would otherwise fill the shell's log.
    os.environ.setdefault("GLOG_minloglevel", "2")
    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")
    import cv2
    import numpy as np
    import mediapipe as mp
    from mediapipe.tasks.python import BaseOptions, vision

    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    source = webcam()
    capture = cv2.VideoCapture(source or 0, cv2.CAP_V4L2)
    capture.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
    capture.set(cv2.CAP_PROP_FRAME_WIDTH, WIDTH)
    capture.set(cv2.CAP_PROP_FRAME_HEIGHT, HEIGHT)
    capture.set(cv2.CAP_PROP_FPS, FPS)
    if not capture.isOpened():
        say(state="error", error="camera busy")
        sys.exit(1)

    video = vision.RunningMode.VIDEO

    def options(name):
        return BaseOptions(model_asset_path=str(MODELS / name))

    face = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
        base_options=options("face_landmarker.task"), running_mode=video))
    # Gestures are recognised beside the loop rather than in it: they cost
    # three frames' time each, and a reaction can wait a frame for its answer.
    recognised = {"result": None}

    def heard(result, _image, _stamp):
        recognised["result"] = result

    hands = vision.GestureRecognizer.create_from_options(vision.GestureRecognizerOptions(
        base_options=options("gesture_recognizer.task"),
        running_mode=vision.RunningMode.LIVE_STREAM, num_hands=2, result_callback=heard))
    segmenter = vision.ImageSegmenter.create_from_options(vision.ImageSegmenterOptions(
        base_options=options("selfie_segmenter.tflite"), running_mode=video,
        output_confidence_masks=True, output_category_mask=False))

    config, _ = read_config(None)
    config = config or {}
    palette = {}

    def refresh_palette():
        colours = config.get("palette", {})
        palette.update(
            accent=hex_rgb(colours.get("accent"), (108, 140, 255)),
            red=hex_rgb(colours.get("red"), (235, 80, 90)),
            yellow=hex_rgb(colours.get("yellow"), (240, 200, 90)),
            green=hex_rgb(colours.get("green"), (130, 210, 120)),
            blue=hex_rgb(colours.get("blue"), (90, 160, 240)))

    refresh_palette()

    # ── grading: one 3×3 matrix per filter, applied with cv2.transform
    luma = np.array([0.299, 0.587, 0.114], np.float32)

    def toned(tint, amount, lift):
        tint = np.array(tint, np.float32) / 255 * lift
        return (np.eye(3, dtype=np.float32) * (1 - amount)
                + amount * np.outer(tint, luma)).astype(np.float32)

    def matrix(effect):
        if effect == "palette":
            return toned(palette["accent"], 0.45, 1.25)
        if effect == "warm":
            return toned(palette["yellow"], 0.2, 1.3)
        if effect == "mono":
            return np.repeat(luma[None, :] * 1.08, 3, 0).astype(np.float32)
        return None

    # ── emoji, drawn from the colour emoji font and kept as RGBA sprites
    from PIL import Image, ImageDraw, ImageFont

    sprites = {}

    def sprite(glyph):
        if glyph not in sprites:
            canvas = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
            try:
                ImageDraw.Draw(canvas).text((10, 10), glyph, font=emoji_font, embedded_color=True)
            except (OSError, ValueError):
                pass
            box = canvas.getbbox() or (0, 0, 1, 1)
            sprites[glyph] = np.asarray(canvas.crop(box)).astype(np.float32)
        return sprites[glyph]

    try:
        emoji_font = ImageFont.truetype(EMOJI_FONT, 109)
    except OSError:
        emoji_font = None

    def blit(img, glyph, centre, width, angle=0.0, alpha=1.0):
        """Lay an emoji on the frame, `width` pixels across, turned `angle`
        degrees, faded by `alpha`."""
        if emoji_font is None or width < 4 or alpha <= 0:
            return
        art = sprite(glyph)
        scale = width / art.shape[1]
        size = max(art.shape[0], art.shape[1]) * scale
        side = int(size * 1.5) + 2
        turn = cv2.getRotationMatrix2D((art.shape[1] / 2, art.shape[0] / 2), -angle, scale)
        turn[:, 2] += (side / 2 - art.shape[1] / 2, side / 2 - art.shape[0] / 2)
        layer = cv2.warpAffine(art, turn, (side, side), flags=cv2.INTER_LINEAR)
        x0, y0 = int(centre[0] - side / 2), int(centre[1] - side / 2)
        fx0, fy0 = max(x0, 0), max(y0, 0)
        fx1, fy1 = min(x0 + side, WIDTH), min(y0 + side, HEIGHT)
        if fx1 <= fx0 or fy1 <= fy0:
            return
        part = layer[fy0 - y0:fy1 - y0, fx0 - x0:fx1 - x0]
        cover = part[..., 3:4] / 255 * alpha
        region = img[fy0:fy1, fx0:fx1].astype(np.float32)
        img[fy0:fy1, fx0:fx1] = (region * (1 - cover) + part[..., :3] * cover).astype(np.uint8)

    # ── face marks, built in the head's own space and turned with it
    #
    # MediaPipe's pose is a 4×4 matrix from its canonical face (centimetres,
    # origin behind the bridge of the nose, y up, z toward the camera) into a
    # camera with a 63° vertical field of view. The marks are built there, so
    # they turn, tilt and recede with the head; what passes behind the head
    # is drawn under the person's silhouette and hidden by it.
    focal = (HEIGHT / 2) / math.tan(math.radians(63 / 2))
    pose = {"pnp": None}
    LIGHT = np.array([-.4, .7, .6]) / np.linalg.norm([-.4, .7, .6])

    # The pose is solved from the landmarks themselves (solvePnP against the
    # canonical face) rather than taken from the landmarker's own matrix,
    # whose yaw lags a turned head.
    canonical = np.array(canonical_face(), np.float64)
    ANCHORS = [33, 133, 362, 263, 1, 4, 6, 168, 152, 234, 454, 10, 61, 291, 105, 334]
    anchors_3d = canonical[ANCHORS]
    lens_matrix = np.array([[focal, 0, WIDTH / 2], [0, focal, HEIGHT / 2], [0, 0, 1]])
    # OpenCV's camera looks down +z with y down; the marks are written for
    # MediaPipe's, which looks down -z with y up.
    flip = np.diag([1.0, -1.0, -1.0])

    def solve_pose(lm):
        seen = np.array([[lm[i].x * WIDTH, lm[i].y * HEIGHT] for i in ANCHORS], np.float64)
        guess = pose.get("pnp")
        if guess is None:
            ok, rvec, tvec = cv2.solvePnP(anchors_3d, seen, lens_matrix, None,
                                          flags=cv2.SOLVEPNP_EPNP)
            ok, rvec, tvec = cv2.solvePnP(anchors_3d, seen, lens_matrix, None, rvec, tvec,
                                          True, cv2.SOLVEPNP_ITERATIVE)
        else:
            ok, rvec, tvec = cv2.solvePnP(anchors_3d, seen, lens_matrix, None,
                                          guess[0].copy(), guess[1].copy(), True,
                                          cv2.SOLVEPNP_ITERATIVE)
        if not ok:
            return None
        if guess is not None and np.abs(tvec - guess[1]).max() < 6:
            rvec = guess[0] * .4 + rvec * .6
            tvec = guess[1] * .4 + tvec * .6
        pose["pnp"] = (rvec, tvec)
        rotation, _ = cv2.Rodrigues(rvec)
        matrix = np.eye(4)
        matrix[:3, :3] = flip @ rotation
        matrix[:3, 3] = flip @ tvec.ravel()
        return matrix

    def project(matrix, p):
        q = matrix @ np.array([p[0], p[1], p[2], 1.0])
        depth = max(-q[2], 1e-3)
        return np.array([WIDTH / 2 + q[0] / depth * focal, HEIGHT / 2 - q[1] / depth * focal]), q

    def facing(matrix, normal, at):
        """Whether a surface at camera-space `at` with head-space `normal`
        faces the camera."""
        return float(np.dot(matrix[:3, :3] @ normal, -at[:3])) > 0

    def behind(img, layer, cover, person):
        """Lay what was drawn behind the head, where the person is not.
        Only the box around what was drawn is blended."""
        x, y, w, h = cv2.boundingRect(cover)
        if w == 0 or h == 0:
            return
        box = (slice(y, y + h), slice(x, x + w))
        hidden = cover[box].astype(np.float32) / 255
        if person is not None:
            hidden *= np.clip(1 - person[box] * 1.4, 0, 1)
        hidden = hidden[..., None]
        img[box] = (img[box] * (1 - hidden) + layer[box] * hidden).astype(np.uint8)

    # ── the crown: a ring of gold sat on top of the hair
    CROWN_SIDES = 64
    CROWN_POINTS = 8
    CROWN_CENTRE = np.array([0.0, 11.9, -5.0])
    CROWN_RADIUS, CROWN_BAND, CROWN_SPIKE = 7.8, 2.6, 3.6

    def crown_geometry():
        lean = math.radians(-12)  # worn a little back
        tip = np.array([[1, 0, 0],
                        [0, math.cos(lean), -math.sin(lean)],
                        [0, math.sin(lean), math.cos(lean)]])
        rows = []
        for k in range(CROWN_SIDES + 1):
            theta = 2 * math.pi * k / CROWN_SIDES
            out = np.array([math.sin(theta), 0, math.cos(theta)])
            # A tooth per point: a sharp rise and fall between the band and
            # the tip, round at the bottom of each notch.
            phase = (k * CROWN_POINTS / CROWN_SIDES) % 1
            rise = 1 - abs(phase - .5) * 2
            height = CROWN_BAND + CROWN_SPIKE * rise ** 1.6
            base = CROWN_CENTRE + tip @ (out * CROWN_RADIUS)
            rows.append((base, base + tip @ np.array([0, height, 0]),
                         base + tip @ np.array([0, CROWN_BAND * .55, 0]), tip @ out, rise))
        return rows

    crown_rows = crown_geometry()

    def crown(img, matrix, person):
        gold = np.array(palette["yellow"], np.float32)
        light = LIGHT
        rotate = matrix[:3, :3]
        faces = []
        for k in range(CROWN_SIDES):
            b0, t0, m0, n0, r0 = crown_rows[k]
            b1, t1, m1, n1, _ = crown_rows[k + 1]
            corners = [project(matrix, p) for p in (b0, b1, t1, t0)]
            centre = sum(q for _, q in corners)[:3] / 4
            normal = rotate @ ((n0 + n1) / 2)
            outside = float(np.dot(normal, -centre)) > 0
            shade = .5 + .5 * max(0.0, float(np.dot(normal, light))) if outside else .32
            faces.append((centre[2], outside, np.array([c for c, _ in corners], np.int32), shade))
        faces.sort(key=lambda face: face[0])

        # The inside of the far half first, shown only where the person is
        # not: the head stands in front of it.
        back = np.zeros_like(img)
        cover = np.zeros(img.shape[:2], np.uint8)
        for _, outside, quad, shade in faces:
            if not outside:
                colour = tuple(int(c) for c in np.clip(gold * shade, 0, 255))
                cv2.fillConvexPoly(back, quad, colour, cv2.LINE_AA)
                cv2.fillConvexPoly(cover, quad, 255, cv2.LINE_AA)
        behind(img, back, cover, person)

        for _, outside, quad, shade in faces:
            if outside:
                colour = tuple(int(c) for c in np.clip(gold * shade, 0, 255))
                edge = tuple(int(c) for c in np.clip(gold * shade * .7, 0, 255))
                cv2.fillConvexPoly(img, quad, colour, cv2.LINE_AA)
                cv2.line(img, tuple(quad[2]), tuple(quad[3]), edge, 2, cv2.LINE_AA)
        front = img

        # Jewels on the band, and a pearl on each tip, where they face us.
        for k in range(0, CROWN_SIDES, CROWN_SIDES // CROWN_POINTS):
            base, top, middle, out, _ = crown_rows[k]
            normal = rotate @ out
            for spot, size, colour in (
                    (crown_rows[k + CROWN_SIDES // CROWN_POINTS // 2][2], .55,
                     palette["red"] if (k // (CROWN_SIDES // CROWN_POINTS)) % 2 else palette["blue"]),
                    (crown_rows[k + CROWN_SIDES // CROWN_POINTS // 2][1], .45, (250, 246, 236))):
                at, q = project(matrix, spot)
                if float(np.dot(rotate @ crown_rows[k + CROWN_SIDES // CROWN_POINTS // 2][3], -q[:3])) <= 0:
                    continue
                radius = max(2, int(size / max(-q[2], 1e-3) * focal))
                cv2.circle(front, tuple(at.astype(int)), radius, colour, -1, cv2.LINE_AA)
                cv2.circle(front, tuple((at - radius * .35).astype(int)), max(1, radius // 3),
                           (255, 255, 255), -1, cv2.LINE_AA)


    # ── the sunglasses: one rigid frame in the canonical face's space, so it
    # keeps its proportions however the head turns. Lenses 5 × 3.7 cm,
    # wrapped back toward the temples; the far lens is cut along the nose
    # and the far arm runs behind the head.
    LENS_X, LENS_Y, LENS_W, LENS_H = 3.25, 2.55, 5.0, 3.7
    LENS_FRONT, LENS_WRAP = 6.0, 1.5

    def lens_point(side, x, y):
        """A point on a lens, from its own centred coordinates in cm."""
        outward = max(0.0, x * side) / (LENS_W / 2)
        return np.array([side * LENS_X + x, LENS_Y + y, LENS_FRONT - LENS_WRAP * outward ** 2])

    def lens_outline(side, grow=1.0):
        points = []
        for k in range(48):
            a = 2 * math.pi * k / 48
            cx, cy = math.cos(a), math.sin(a)
            # A wayfarer: a superellipse, squarer than a circle, a little
            # wider along the top.
            x = math.copysign(abs(cx) ** .5, cx) * LENS_W / 2 * grow
            y = math.copysign(abs(cy) ** .6, cy) * LENS_H / 2 * grow
            x *= 1 + .07 * y / (LENS_H / 2)
            points.append(lens_point(side, x, y))
        return points

    LENSES = {side: (lens_outline(side), lens_outline(side, 1.1)) for side in (-1, 1)}
    BRIDGE = [lens_point(-1, LENS_W / 2 * .92, LENS_H * .3), np.array([0, LENS_Y + LENS_H * .42,
              LENS_FRONT + .25]), lens_point(1, -LENS_W / 2 * .92, LENS_H * .3)]

    def arm(side):
        return [lens_point(side, side * LENS_W / 2 * 1.05, LENS_H * .3),
                np.array([side * 7.9, 3.0, 0.8]), np.array([side * 8.0, 2.5, -2.6]),
                np.array([side * 7.8, 1.1, -3.7])]

    ARMS = {side: arm(side) for side in (-1, 1)}

    def shades(img, matrix, lm, person):
        frame_colour = (24, 22, 26)
        lens_colour = np.array([20, 22, 30], np.float32)
        flat = lambda points: np.array([project(matrix, p)[0] for p in points], np.float32)
        depth = max(-matrix[2, 3], 1)
        rim = max(3, int(.42 / depth * focal))

        # The nearer side is the one whose hinge is closer to the camera.
        hinge_depth = {side: -project(matrix, ARMS[side][0])[1][2] for side in (-1, 1)}
        near = min(hinge_depth, key=hinge_depth.get)
        far = -near

        back = np.zeros_like(img)
        cover = np.zeros(img.shape[:2], np.uint8)
        far_arm = flat(ARMS[far]).astype(np.int32)
        cv2.polylines(back, [far_arm], False, frame_colour, rim, cv2.LINE_AA)
        cv2.polylines(cover, [far_arm], False, 255, rim, cv2.LINE_AA)
        behind(img, back, cover, person)

        # Where the nose stands in front of the far lens.
        nose_top = np.array([lm[168].x * WIDTH, lm[168].y * HEIGHT])
        nose_tip = np.array([lm[4].x * WIDTH, lm[4].y * HEIGHT])
        along = nose_tip - nose_top
        along /= max(np.linalg.norm(along), 1)
        normal = np.array([-along[1], along[0]])
        far_centre = flat([lens_point(far, 0, 0)])[0]
        if np.dot(far_centre - nose_top, normal) < 0:
            normal = -normal
        span = WIDTH + HEIGHT
        keep = np.zeros(img.shape[:2], np.uint8)
        cv2.fillConvexPoly(keep, np.array([nose_top - along * span, nose_top + along * span,
                                           nose_top + along * span + normal * span,
                                           nose_top - along * span + normal * span], np.int32), 255)

        for side in (far, near):
            glass_ring = flat(LENSES[side][0]).astype(np.int32)
            frame_ring = flat(LENSES[side][1]).astype(np.int32)
            edge = np.zeros(img.shape[:2], np.uint8)
            glass = np.zeros(img.shape[:2], np.uint8)
            cv2.fillPoly(edge, [frame_ring], 255, cv2.LINE_AA)
            cv2.fillPoly(glass, [glass_ring], 255, cv2.LINE_AA)
            if side == far:
                edge = cv2.bitwise_and(edge, keep)
                glass = cv2.bitwise_and(glass, keep)
            x0, y0, w, h = cv2.boundingRect(frame_ring)
            x1, y1 = min(x0 + w, WIDTH), min(y0 + h, HEIGHT)
            x0, y0 = max(x0, 0), max(y0, 0)
            if x1 <= x0 or y1 <= y0:
                continue
            region = img[y0:y1, x0:x1].astype(np.float32)
            e = edge[y0:y1, x0:x1, None].astype(np.float32) / 255
            g = glass[y0:y1, x0:x1, None].astype(np.float32) / 255
            ramp = np.linspace(1.3, .8, y1 - y0, dtype=np.float32)[:, None, None]
            painted = region * (1 - e) + np.array(frame_colour, np.float32) * e
            painted = painted * (1 - g) + (region * .07 + lens_colour * ramp * .93) * g
            img[y0:y1, x0:x1] = painted.astype(np.uint8)
            # A soft streak of light across the upper outer corner.
            streak = flat([lens_point(side, -side * LENS_W * .28, LENS_H * .3),
                           lens_point(side, -side * LENS_W * .05, LENS_H * .05)]).astype(np.int32)
            thick = max(2, int(.45 / depth * focal))
            sx, sy, sw, sh = cv2.boundingRect(streak)
            sx, sy = max(sx - thick, 0), max(sy - thick, 0)
            box = (slice(sy, min(sy + sh + 2 * thick, HEIGHT)), slice(sx, min(sx + sw + 2 * thick, WIDTH)))
            overlay = img[box].copy()
            cv2.line(overlay, tuple(streak[0] - [sx, sy]), tuple(streak[1] - [sx, sy]),
                     (210, 214, 225), thick, cv2.LINE_AA)
            if side == far:
                overlay = np.where(keep[box][..., None] > 0, overlay, img[box])
            img[box] = cv2.addWeighted(overlay, .35, img[box], .65, 0)

        cv2.polylines(img, [flat(BRIDGE).astype(np.int32)], False, frame_colour, rim, cv2.LINE_AA)
        cv2.polylines(img, [flat(ARMS[near]).astype(np.int32)], False, frame_colour, rim, cv2.LINE_AA)

    # ── sparkles: a slow orbit round the head, passing behind it
    def sparkle(img, matrix, person, now):
        back = img.copy()
        stars = []
        for k in range(9):
            a = k * 2 * math.pi / 9 + now * .45
            height = 3.5 + 4.5 * math.sin(k * 2.1)
            spot = np.array([math.sin(a) * 12.5, height, -5 + math.cos(a) * 12.5])
            at, q = project(matrix, spot)
            twinkle = .5 + .5 * math.sin(now * 4 + k * 1.9)
            size = (1.6 + 1.8 * twinkle) / max(-q[2], 1) * focal
            stars.append((q[2], math.cos(a) < -.15, at, size, .4 + .6 * twinkle))
        stars.sort(key=lambda star: star[0])
        for _, far, at, size, alpha in stars:
            if far:
                blit(back, "✨", at, size, 0, alpha)
        cover = (np.abs(back.astype(np.int16) - img.astype(np.int16)).max(axis=2) > 0)
        behind(img, back, cover.astype(np.uint8) * 255, person)
        for _, far, at, size, alpha in stars:
            if not far:
                blit(img, "✨", at, size, 0, alpha)

    # ── centre stage: a crop that follows the face, eased
    frame_box = [WIDTH / 2, HEIGHT / 2, 1.0]

    def follow(img, lm):
        if lm is not None:
            xs = [p.x for p in lm]
            ys = [p.y for p in lm]
            cx, cy = (min(xs) + max(xs)) / 2 * WIDTH, (min(ys) + max(ys)) / 2 * HEIGHT
            zoom = 1.45
        else:
            cx, cy, zoom = WIDTH / 2, HEIGHT / 2, 1.0
        ease = .08
        frame_box[0] += (cx - frame_box[0]) * ease
        frame_box[1] += (cy - frame_box[1]) * ease
        frame_box[2] += (zoom - frame_box[2]) * ease
        w, h = WIDTH / frame_box[2], HEIGHT / frame_box[2]
        x = min(max(frame_box[0] - w / 2, 0), WIDTH - w)
        y = min(max(frame_box[1] - h / 2, 0), HEIGHT - h)
        crop = img[int(y):int(y + h), int(x):int(x + w)]
        return cv2.resize(crop, (WIDTH, HEIGHT), interpolation=cv2.INTER_LINEAR)

    # ── reactions: the gesture's own emoji, rising from the hand that made it
    REACTIONS = {"thumbsup": "👍", "heart": "❤️", "peace": "✌️", "thumbsdown": "👎",
                 "horns": "🤘", "ok": "👌", "middle": "🖕"}
    particles = []

    def burst(kind, origin):
        now = time.time()
        sinks = kind == "thumbsdown"
        for k in range(6):
            particles.append(dict(
                glyph=REACTIONS[kind], x=origin[0], y=origin[1],
                vx=random.uniform(-220, 220),
                vy=random.uniform(110, 180) if sinks else -random.uniform(230, 340),
                gravity=240 if sinks else 80,
                size=random.uniform(.11, .17) * HEIGHT,
                spin=random.uniform(-30, 30), wobble=random.uniform(0, 6.3),
                born=now + k * .09, life=random.uniform(1.7, 2.2)))

    def draw_particles(img, dt, now):
        alive = []
        for p in particles:
            age = now - p["born"]
            if age < 0:
                alive.append(p)
                continue
            if age > p["life"]:
                continue
            p["vy"] += p["gravity"] * dt
            p["vx"] *= .985
            p["x"] += p["vx"] * dt
            p["y"] += p["vy"] * dt
            alive.append(p)
            grow = min(1.0, age / .22)
            pop = grow * (1 + .25 * math.sin(min(1.0, age / .22) * math.pi))
            fade = min(1.0, (p["life"] - age) / .5)
            sway = math.sin(age * 5 + p["wobble"]) * 10
            blit(img, p["glyph"], (p["x"] + sway, p["y"]), p["size"] * pop,
                 p["spin"] * age * .4, fade)
        particles[:] = alive

    def palm(hand):
        """The middle of a hand, in frame pixels."""
        xs = [hand[i].x for i in (0, 5, 9, 13, 17)]
        ys = [hand[i].y for i in (0, 5, 9, 13, 17)]
        return (sum(xs) / 5 * WIDTH, sum(ys) / 5 * HEIGHT)

    def heart_hands(landmarks):
        """Both index tips together above both thumb tips together: where."""
        if len(landmarks) != 2:
            return None
        a, b = landmarks

        def gap(p, q):
            return math.hypot(p.x - q.x, p.y - q.y)

        hand = gap(a[0], a[9])
        if (gap(a[8], b[8]) < hand * .6 and gap(a[4], b[4]) < hand * .6
                and a[8].y < a[4].y and b[8].y < b[4].y):
            return ((a[8].x + b[8].x + a[4].x + b[4].x) / 4 * WIDTH,
                    (a[8].y + b[8].y + a[4].y + b[4].y) / 4 * HEIGHT)
        return None

    def hand_pose(hand):
        """The poses the recogniser has no category for, read off the fingers:
        a finger is out when its tip is well past its knuckle from the wrist,
        and folded when it is not. In pixels, so the frame's shape does not
        stretch one axis."""
        def at(i):
            return (hand[i].x * WIDTH, hand[i].y * HEIGHT)

        def gap(i, j):
            (ax, ay), (bx, by) = at(i), at(j)
            return math.hypot(ax - bx, ay - by)

        reach = {tip: gap(0, tip) / max(1e-6, gap(0, tip - 3)) for tip in (8, 12, 16, 20)}
        out = {tip: reach[tip] > 1.55 for tip in reach}
        folded = {tip: reach[tip] < 1.3 for tip in reach}
        # Seen from the front a folded ring finger still reads long, so the
        # middle one only has to reach well past the other three.
        if out[12] and reach[12] > 1.6 * max(reach[8], reach[16], reach[20]):
            return "middle"
        if out[8] and out[20] and folded[12] and folded[16]:
            return "horns"
        if gap(4, 8) < gap(0, 9) * .3 and out[12] and out[16] and out[20]:
            return "ok"
        return None

    gestures = {"Thumb_Up": "thumbsup", "Victory": "peace", "Thumb_Down": "thumbsdown",
                "ILoveYou": "horns"}
    held_kind, held_frames, last_fire = None, 0, 0.0

    stamp = 0
    frame_count = 0
    person_mask = {"mask": None}
    previous = time.time()
    counted, since = 0, time.time()
    faces = 0

    say(state="live", camera=source)
    while True:
        config, changed = read_config(config)
        if changed:
            refresh_palette()
        effect = config.get("effect", "natural")
        reactions = config.get("reactions", {})

        ok, bgr = capture.read()
        if not ok:
            time.sleep(.01)
            continue
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        if rgb.shape[1] != WIDTH or rgb.shape[0] != HEIGHT:
            rgb = cv2.resize(rgb, (WIDTH, HEIGHT))
        now = time.time()
        stamp = max(stamp + 1, int(time.monotonic() * 1000))
        # The models read half the picture: their landmarks are fractions of
        # it, and a quarter of the pixels is a third of the time.
        half = cv2.resize(rgb, (WIDTH // 2, HEIGHT // 2), interpolation=cv2.INTER_AREA)
        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=half)

        landmarks = None
        head = None
        faces = -1
        if effect in ("shades", "crown", "sparkle", "stage"):
            found = face.detect_for_video(image, stamp)
            faces = len(found.face_landmarks)
            landmarks = found.face_landmarks[0] if found.face_landmarks else None
            if landmarks is not None:
                head = solve_pose(landmarks)
            else:
                head = None
                pose["pnp"] = None

        if any(reactions.get(kind) for kind in REACTIONS):
            seen, where = None, None
            # Ten a second is plenty for a hand held still.
            if frame_count % 3 == 0:
                hands.recognize_async(image, stamp)
            result = recognised["result"]
            recognised["result"] = None
            if result is not None:
                if reactions.get("heart"):
                    where = heart_hands(result.hand_landmarks)
                    seen = "heart" if where else None
                if not seen:
                    for guess, hand in zip(result.gestures, result.hand_landmarks):
                        kind = hand_pose(hand)
                        if not (kind and reactions.get(kind)):
                            kind = gestures.get(guess[0].category_name)
                            if guess[0].score <= .6:
                                kind = None
                        if kind and reactions.get(kind):
                            seen, where = kind, palm(hand)
                held_frames = held_frames + 1 if seen and seen == held_kind else (1 if seen else 0)
                held_kind = seen
            if seen and held_frames == 3 and now - last_fire > 2.5:
                burst(seen, where)
                last_fire = now
                say(reaction=seen)

        grade = matrix(effect)
        out = cv2.transform(rgb, grade) if grade is not None else rgb.copy()

        if effect == "blur":
            mask = segmenter.segment_for_video(image, stamp).confidence_masks[0].numpy_view()
            mask = cv2.resize(mask.astype(np.float32), (WIDTH, HEIGHT))
            mask = cv2.GaussianBlur(mask, (0, 0), 5)[..., None]
            small = cv2.resize(out, (WIDTH // 8, HEIGHT // 8), interpolation=cv2.INTER_AREA)
            back = cv2.resize(cv2.GaussianBlur(small, (0, 0), 4), (WIDTH, HEIGHT))
            out = (out * mask + back * (1 - mask)).astype(np.uint8)
        elif head is not None and effect in ("shades", "crown", "sparkle"):
            # The silhouette only hides what passes behind the head, so a
            # third of the frames is enough.
            if person_mask["mask"] is None or frame_count % 3 == 0:
                seen_person = segmenter.segment_for_video(image, stamp).confidence_masks[0].numpy_view()
                person_mask["mask"] = cv2.resize(seen_person.astype(np.float32), (WIDTH, HEIGHT))
            person = person_mask["mask"]
            if effect == "shades":
                shades(out, head, landmarks, person)
            elif effect == "crown":
                crown(out, head, person)
            else:
                sparkle(out, head, person, now)
        if effect == "stage":
            out = follow(out, landmarks)

        draw_particles(out, now - previous, now)
        previous = now

        # A photo asked for by `snap`: this frame, mirrored as the panel's
        # preview shows it.
        if SNAP.exists():
            try:
                target = Path(SNAP.read_text().strip())
                SNAP.unlink()
                part = target.with_suffix(".part.png")
                cv2.imwrite(str(part), cv2.cvtColor(cv2.flip(out, 1), cv2.COLOR_RGB2BGR))
                os.replace(part, target)
            except OSError as error:
                print(f"Cannot take the photo: {error}", file=sys.stderr)

        os.write(out_fd, cv2.cvtColor(out, cv2.COLOR_RGB2YUV_I420).tobytes())

        counted += 1
        frame_count += 1
        if now - since >= 2:
            say(state="live", fps=round(counted / (now - since), 1), faces=faces)
            counted, since = 0, now


def main():
    verb = sys.argv[1] if len(sys.argv) > 1 else "status"
    if verb == "status":
        status()
    elif verb == "configure" and len(sys.argv) > 2:
        configure(sys.argv[2])
    elif verb == "snap":
        snap()
    elif verb == "serve":
        serve()
    elif verb == "run" and len(sys.argv) > 2:
        run(int(sys.argv[2]))
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
