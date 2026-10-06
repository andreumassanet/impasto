#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   L Y R I C S                                                            │
# │   the playing track's lyrics · lrclib.net, cached                        │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""One track's lyrics from lrclib.net, timed per line when it has them.

Usage: lyrics.py <artist> <title> <album> <seconds>

Prints {"available": true, "synced": bool, "instrumental": bool, "lines":
[{"t": seconds, "text": "..."}]} — `t` is -1 for unsynced lyrics — or
{"available": false, "reason": "missing" | "network"}.

Answers are cached in the state directory — a miss for a week, a failure
for a quarter of an hour — so a track asked for again costs nothing.
"""

import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ENDPOINT = "https://lrclib.net/api"
TIMEOUT = 8
AGENT = "impasto (github.com/andreumassanet/impasto)"
MISS_TTL = 7 * 24 * 3600
# A failure is asked again later, not on every look while it lasts.
FAIL_TTL = 15 * 60

STAMP = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
# What video sites add to a title or a channel name.
NOISE = re.compile(r"\s*[\(\[](official|lyric|audio|video|visuali[sz]er|hd|4k|mv)[^\)\]]*[\)\]]",
                   re.IGNORECASE)


def cache_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    path = os.path.join(base, "quickshell", "lyrics")
    os.makedirs(path, exist_ok=True)
    return path


def clean(artist, title):
    artist = re.sub(r"\s*-\s*Topic$", "", artist).strip()
    title = NOISE.sub("", title).strip()
    # "Artist - Title" with no artist of its own, as a browser tab sends it.
    if not artist and " - " in title:
        artist, title = (part.strip() for part in title.split(" - ", 1))
    return artist, title


class Busy(Exception):
    """lrclib answered, but not with an answer: a 5xx, or no answer at all."""


def ask(path, params):
    url = f"{ENDPOINT}/{path}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"User-Agent": AGENT})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as answer:
            return json.load(answer)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise Busy(f"HTTP {error.code}") from error
    except (urllib.error.URLError, OSError, ValueError) as error:
        raise Busy(str(error)) from error


def folded(text):
    return re.sub(r"\W+", " ", text.casefold()).strip()


def lookup(artist, title, album, seconds):
    """The best record over three questions, any of which may be refused.

    The exact record first, which lrclib matches within two seconds; then a
    search by fields, then a free search, since a busy server refuses some
    questions and answers others, and a record with only plain lyrics often
    has a timed twin under a longer artist ("Feid" and "Feid, ICON"). Timed
    beats plain, then the closest length. Busy everywhere and nothing found
    is a failure, retried later; answered everywhere and nothing found is a
    miss.
    """
    found = []
    busy = False

    def take(results):
        found.extend(entry for entry in results if entry)

    if seconds > 0:
        params = {"artist_name": artist, "track_name": title, "duration": round(seconds)}
        if album:
            params["album_name"] = album
        try:
            take([ask("get", params)])
        except Busy:
            busy = True
        if found and found[0].get("syncedLyrics"):
            return found[0]

    questions = [{"track_name": title, **({"artist_name": artist} if artist else {})},
                 {"q": f"{artist} {title}".strip()}]
    for params in questions:
        try:
            take(ask("search", params) or [])
        except Busy:
            busy = True
            continue
        if any(entry.get("syncedLyrics") for entry in found):
            break

    wanted = folded(title)
    candidates = [entry for entry in found
                  if wanted in folded(entry.get("trackName") or "")
                  and (seconds <= 0 or abs((entry.get("duration") or 0) - seconds) <= 8)
                  and (entry.get("syncedLyrics") or entry.get("plainLyrics") or entry.get("instrumental"))]
    if not candidates:
        if busy:
            raise Busy("no answer")
        return None

    def rank(entry):
        off = abs((entry.get("duration") or 0) - seconds) if seconds > 0 else 0
        return (not entry.get("syncedLyrics"), off)

    return min(candidates, key=rank)


def parse(entry):
    if entry.get("instrumental"):
        return {"available": True, "synced": False, "instrumental": True, "lines": []}
    lines = []
    for raw in (entry.get("syncedLyrics") or "").splitlines():
        stamps = STAMP.findall(raw)
        text = STAMP.sub("", raw).strip()
        for minutes, seconds in stamps:
            lines.append({"t": int(minutes) * 60 + float(seconds), "text": text})
    if lines:
        lines.sort(key=lambda line: line["t"])
        return {"available": True, "synced": True, "instrumental": False, "lines": lines}
    plain = [line.strip() for line in (entry.get("plainLyrics") or "").splitlines()]
    if any(plain):
        return {"available": True, "synced": False, "instrumental": False,
                "lines": [{"t": -1, "text": line} for line in plain]}
    return None


def report(artist, title, album, seconds):
    artist, title = clean(artist, title)
    if not title:
        return {"available": False, "reason": "missing"}

    key = hashlib.sha1(f"{artist}\n{title}\n{album}\n{round(seconds)}".encode()).hexdigest()
    path = os.path.join(cache_dir(), f"{key}.json")
    try:
        with open(path) as file:
            kept = json.load(file)
        ttl = FAIL_TTL if kept.get("reason") == "network" else MISS_TTL
        if kept.get("available") or time.time() - kept.get("at", 0) < ttl:
            kept.pop("at", None)
            return kept
    except (OSError, ValueError):
        pass

    try:
        entry = lookup(artist, title, album, seconds)
        result = (parse(entry) if entry else None) or {"available": False, "reason": "missing"}
    except Busy as error:
        sys.stderr.write(f"lyrics: {error}\n")
        result = {"available": False, "reason": "network"}

    staging = f"{path}.tmp"
    with open(staging, "w") as file:
        json.dump({**result, "at": time.time()}, file)
    os.replace(staging, path)
    return result


if __name__ == "__main__":
    args = sys.argv[1:] + [""] * 4
    try:
        length = float(args[3] or 0)
    except ValueError:
        length = 0
    try:
        print(json.dumps(report(args[0], args[1], args[2], length)))
    except Exception as error:  # a card must never take the shell down
        sys.stderr.write(f"lyrics failed: {error}\n")
        print(json.dumps({"available": False, "reason": "network"}))
