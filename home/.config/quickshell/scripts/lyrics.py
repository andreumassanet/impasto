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

Answers are cached in the state directory, a miss for a week, so a track
asked for again costs nothing. A failure is not cached: the shell asks
again on its own schedule.
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
# A busy lrclib is asked once more, this long after, before giving up.
RETRY_AFTER = 2

STAMP = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
# What video sites add to a title or a channel name.
NOISE = re.compile(r"\s*[\(\[](official|lyric|audio|video|visuali[sz]er|hd|4k|mv)[^\)\]]*[\)\]]",
                   re.IGNORECASE)
BRACKETS = re.compile(r"\s*[\(\[][^\)\]]*[\)\]]")
# What a video title adds after a bar: the channel, the series, "Lyric Video".
TAIL = re.compile(r"\s+[|｜].*$")
DASH = re.compile(r"\s+[-–—]\s+")


def cache_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    path = os.path.join(base, "quickshell", "lyrics")
    os.makedirs(path, exist_ok=True)
    return path


def clean(artist, title):
    artist = re.sub(r"\s*-\s*Topic$", "", artist).strip()
    title = NOISE.sub("", TAIL.sub("", title)).strip()
    # "Artist - Title", as a browser tab sends it: split when there is no
    # artist, or when the channel is the artist the title starts with.
    parts = DASH.split(title, 1)
    if len(parts) == 2 and (not artist or folded(parts[0]) == folded(artist)):
        artist, title = (part.strip() for part in parts)
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
        # Not found, or a question it will not take (an empty artist): an
        # answer. A server error or a rate limit is not one.
        if error.code < 500 and error.code != 429:
            return None
        raise Busy(f"HTTP {error.code}") from error
    except (urllib.error.URLError, OSError, ValueError) as error:
        raise Busy(str(error)) from error


def folded(text):
    return re.sub(r"\W+", " ", text.casefold()).strip()


def lookup(artist, title, album, seconds, sent=""):
    """The best record over four questions, any of which may be refused.

    The exact record first, which lrclib matches within two seconds; then a
    search by fields, then a free search, since a busy server refuses some
    questions and answers others, and a record with only plain lyrics often
    has a timed twin under a longer artist ("Feid" and "Feid, ICON"). Last,
    the bare song name, for a video title no cleaning reads: a record found
    that way is taken only when its name and its artist are both in what the
    player sent and its length is within two seconds. Timed beats plain,
    then the closest length. Busy everywhere and nothing found is a failure,
    retried later; answered everywhere and nothing found is a miss.
    """
    found = []
    busy = False
    wanted = folded(title)
    heard = f" {folded(sent or f'{artist} {title}')} "

    def fits(entry):
        if not (entry.get("syncedLyrics") or entry.get("plainLyrics") or entry.get("instrumental")):
            return False
        off = abs((entry.get("duration") or 0) - seconds)
        if seconds > 0 and off > 8:
            return False
        name = folded(entry.get("trackName") or "")
        if wanted in name:
            return True
        singer = folded(entry.get("artistName") or "")
        return (seconds > 0 and off <= 2 and bool(name) and bool(singer)
                and f" {name} " in heard and f" {singer} " in heard)

    def take(results):
        found.extend(entry for entry in results if entry and fits(entry))

    if seconds > 0 and artist:
        params = {"artist_name": artist, "track_name": title, "duration": round(seconds)}
        if album:
            params["album_name"] = album
        try:
            take([ask("get", params)])
        except Busy:
            busy = True
        if found and found[0].get("syncedLyrics"):
            return found[0]

    song = DASH.split(BRACKETS.sub("", title).strip(), 1)[-1].strip()
    questions = [{"track_name": title, **({"artist_name": artist} if artist else {})},
                 {"q": f"{artist} {title}".strip()}]
    if song and song != title:
        questions.append({"track_name": song})
    for params in questions:
        try:
            take(ask("search", params) or [])
        except Busy:
            busy = True
            continue
        if any(entry.get("syncedLyrics") for entry in found):
            break

    if not found:
        if busy:
            raise Busy("no answer")
        return None

    def rank(entry):
        off = abs((entry.get("duration") or 0) - seconds) if seconds > 0 else 0
        return (not entry.get("syncedLyrics"), off)

    return min(found, key=rank)


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
    sent = f"{artist} {title}"
    artist, title = clean(artist, title)
    if not title:
        return {"available": False, "reason": "missing"}

    key = hashlib.sha1(f"{artist}\n{title}\n{album}\n{round(seconds)}".encode()).hexdigest()
    path = os.path.join(cache_dir(), f"{key}.json")
    try:
        with open(path) as file:
            kept = json.load(file)
        if kept.get("available") or (kept.get("reason") == "missing"
                                     and time.time() - kept.get("at", 0) < MISS_TTL):
            kept.pop("at", None)
            return kept
    except (OSError, ValueError):
        pass

    try:
        try:
            entry = lookup(artist, title, album, seconds, sent)
        except Busy:
            time.sleep(RETRY_AFTER)
            entry = lookup(artist, title, album, seconds, sent)
        result = (parse(entry) if entry else None) or {"available": False, "reason": "missing"}
    except Busy as error:
        sys.stderr.write(f"lyrics: {error}\n")
        return {"available": False, "reason": "network"}

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
