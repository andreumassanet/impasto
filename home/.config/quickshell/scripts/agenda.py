#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   A G E N D A                                                            │
# │   the calendar's events, from links and from khal, as JSON               │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Events for the calendar card, over a range of days, as JSON.

Two sources. The links in the shell's `calendarLinks` setting, each a
calendar's address in iCalendar form (Google's secret address, Outlook's
published ICS), downloaded at most every fifteen minutes into the cache and
read here, repeating events included. And khal, when it is set up, for
whoever syncs calendars with vdirsyncer. `agenda.py FROM DAYS [--fetch]`
prints `{ "configured": bool, "error": str, "links": [...], "events": [...] }`,
each event with its title, calendar, location, all-day flag, day and times,
and each link with whether it was read.

khal prints dates in the formats of its own config, so it is handed a copy of
that config with the formats this reads; the person's file is never written.
"""

import hashlib
import http.client
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from datetime import date, datetime, timedelta

FIELDS = ("title", "start-date", "start-time", "end-date", "end-time",
          "calendar", "location", "all-day", "uid")
DATE, TIME = "%Y-%m-%d", "%H:%M"

STATE = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
CACHE = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
SETTINGS = os.path.join(STATE, "quickshell", "settings.json")
DOWNLOADS = os.path.join(CACHE, "impasto", "calendars")
# A link is downloaded again once its copy is this old.
STALE = 15 * 60


def khal_config():
    """Where khal reads its config, as khal itself looks for it."""
    config_home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    for path in (os.path.join(config_home, "khal", "config"),
                 os.path.expanduser("~/.khal/khal.conf")):
        if os.path.isfile(path):
            return path
    return ""


def readable_copy(path, folder):
    """The config with dates and times in the formats parsed below."""
    from configobj import ConfigObj
    config = ConfigObj(path, encoding="utf-8")
    locale = config.setdefault("locale", {})
    locale["dateformat"] = locale["longdateformat"] = DATE
    locale["timeformat"] = TIME
    locale["datetimeformat"] = locale["longdatetimeformat"] = f"{DATE} {TIME}"
    copy = os.path.join(folder, "config")
    config.filename = copy
    config.write()
    return copy


def moment(date, time_of_day, all_day):
    return datetime.strptime(date if all_day else f"{date} {time_of_day}",
                             DATE if all_day else f"{DATE} {TIME}")


def events(start, days, config):
    command = ["khal", "-c", config, "list"]
    for field in FIELDS:
        command += ["--json", field]
    command += [start, f"{days}d"]
    result = subprocess.run(command, capture_output=True, text=True, timeout=20)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip().splitlines()[-1] if result.stderr.strip() else "khal failed")
    found, seen = [], set()
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line.startswith("["):
            continue
        for event in json.loads(line):
            all_day = event["all-day"] == "True"
            key = (event["uid"], event["start-date"], event["start-time"])
            if key in seen:
                continue
            seen.add(key)
            begins = moment(event["start-date"], event["start-time"], all_day)
            ends = moment(event["end-date"], event["end-time"], all_day)
            found.append({
                "title": event["title"], "calendar": event["calendar"],
                "location": event["location"], "allDay": all_day,
                "day": begins.date().isoformat(), "start": int(begins.timestamp()),
                "time": "" if all_day else begins.strftime(TIME),
                "endTime": "" if all_day else ends.strftime(TIME),
            })
    found.sort(key=lambda event: (event["start"], not event["allDay"]))
    return found


# ── LINKS ────────────────────────────────────────────────────────────────────


def links():
    """`calendarLinks` from the shell's settings: `{ name, url }` each. The
    shell hands them over in the environment, ahead of the file's write."""
    try:
        if os.environ.get("IMPASTO_CALENDAR_LINKS"):
            found = json.loads(os.environ["IMPASTO_CALENDAR_LINKS"])
        else:
            with open(SETTINGS, encoding="utf-8") as handle:
                found = json.load(handle).get("calendarLinks")
    except (OSError, ValueError):
        return []
    return [link for link in found if isinstance(link, dict) and link.get("url")] \
        if isinstance(found, list) else []


def fetched(url, fetch):
    """The calendar behind `url`, from the cache while it is fresh."""
    address = url.strip()
    if address.startswith("webcal://"):
        address = "https://" + address[len("webcal://"):]
    copy = os.path.join(DOWNLOADS, hashlib.sha1(address.encode()).hexdigest() + ".ics")
    fresh = os.path.exists(copy) and time.time() - os.path.getmtime(copy) < STALE
    if fetch or not fresh:
        request = urllib.request.Request(address, headers={"User-Agent": "impasto"})
        try:
            with urllib.request.urlopen(request, timeout=20) as answer:
                body = answer.read()
            if b"BEGIN:VCALENDAR" not in body[:4096]:
                raise ValueError("not a calendar")
            os.makedirs(DOWNLOADS, exist_ok=True)
            with open(copy + ".part", "wb") as handle:
                handle.write(body)
            os.replace(copy + ".part", copy)
        except (OSError, ValueError, http.client.HTTPException) as error:
            # The last good copy still answers while the network does not.
            if not os.path.exists(copy):
                raise RuntimeError(str(getattr(error, "reason", error)))
    with open(copy, "rb") as handle:
        return handle.read()


def when(value):
    """An event's start or end: a date for an all-day one, else local time."""
    if isinstance(value, datetime):
        return value.astimezone() if value.tzinfo else value
    return value


def link_events(link, start, days, fetch):
    import icalendar
    import recurring_ical_events
    calendar = icalendar.Calendar.from_ical(fetched(link["url"], fetch))
    begin = datetime.strptime(start, DATE)
    found = []
    for event in recurring_ical_events.of(calendar).between(begin, begin + timedelta(days=days)):
        starts = when(event.get("DTSTART").dt)
        ends = when(event.get("DTEND").dt) if event.get("DTEND") else starts
        all_day = not isinstance(starts, datetime)
        moment_of = datetime.combine(starts, datetime.min.time()) if all_day else starts.replace(tzinfo=None)
        found.append({
            "title": str(event.get("SUMMARY", "")), "calendar": link.get("name", ""),
            "location": str(event.get("LOCATION", "")), "allDay": all_day,
            "day": (starts if all_day else starts.date()).isoformat(),
            "start": int(moment_of.timestamp()),
            "time": "" if all_day else starts.strftime(TIME),
            "endTime": "" if all_day or not isinstance(ends, datetime) else ends.strftime(TIME),
        })
    return found


def main():
    arguments = [argument for argument in sys.argv[1:] if argument != "--fetch"]
    fetch = "--fetch" in sys.argv
    start = arguments[0] if arguments else datetime.now().strftime(DATE)
    days = int(arguments[1]) if len(arguments) > 1 else 42
    path = khal_config() if shutil.which("khal") else ""
    subscribed = links()
    answer = {"configured": path != "" or bool(subscribed), "error": "", "links": [], "events": []}
    if path:
        try:
            with tempfile.TemporaryDirectory() as folder:
                answer["events"] += events(start, days, readable_copy(path, folder))
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
            answer["error"] = str(error)
    for link in subscribed:
        report = {"url": link["url"], "ok": True, "error": "", "count": 0}
        try:
            found = link_events(link, start, days, fetch)
            report["count"] = len(found)
            answer["events"] += found
        except Exception as error:  # a bad link must not take the others with it
            report.update(ok=False, error=str(error) or type(error).__name__)
        answer["links"].append(report)
    answer["events"].sort(key=lambda event: (event["start"], not event["allDay"]))
    print(json.dumps(answer, ensure_ascii=False))


if __name__ == "__main__":
    main()
