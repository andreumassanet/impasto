#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   A G E N D A                                                            │
# │   the next days of your calendars, from khal, as JSON                    │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""The agenda panel's events: `khal list` over the next days, as JSON.

khal reads the calendars you have set up (vdirsyncer, local .ics folders);
nothing here talks to a calendar server. `agenda.py [DAYS] [KHAL_CONFIG]`
prints `{ "configured": bool, "events": [...] }`, each event with its
title, calendar, location, all-day flag, start and end (epoch seconds) and
the date and times to show. Without khal, or with no calendar, it is not
configured and there are no events.

khal prints dates in the `[locale]` formats of its config, which this reads
as `dateformat = %Y-%m-%d` and `timeformat = %H:%M`. With other formats the
answer carries an `error` that says so, rather than guessing a day from 05/11.
"""

import json
import shutil
import subprocess
import sys
import time
from datetime import datetime

FIELDS = ("title", "start-date", "start-time", "end-date", "end-time", "calendar", "location", "all-day", "uid")


class Format(Exception):
    """khal's dates are not in the formats this reads."""


def stamp(date, time_of_day, all_day):
    try:
        if all_day:
            return datetime.strptime(date, "%Y-%m-%d")
        return datetime.strptime(f"{date} {time_of_day}", "%Y-%m-%d %H:%M")
    except ValueError as error:
        raise Format(f"khal's [locale] needs dateformat = %Y-%m-%d and timeformat = %H:%M ({error})")


def events(days, config):
    command = ["khal"] + (["-c", config] if config else []) + ["list"]
    for field in FIELDS:
        command += ["--json", field]
    command += ["today", f"{days}d"]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    found, seen = [], set()
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line.startswith("["):
            continue
        for event in json.loads(line):
            key = (event["uid"], event["start-date"], event["start-time"])
            if key in seen:
                continue
            seen.add(key)
            all_day = event["all-day"] == "True"
            start = stamp(event["start-date"], event["start-time"], all_day)
            end = stamp(event["end-date"], event["end-time"], all_day)
            found.append({
                "title": event["title"], "calendar": event["calendar"],
                "location": event["location"], "allDay": all_day,
                "start": int(start.timestamp()), "end": int(end.timestamp()),
                "date": start.date().isoformat(),
                "time": "" if all_day else start.strftime("%H:%M"),
                "endTime": "" if all_day else end.strftime("%H:%M"),
            })
    found.sort(key=lambda event: (event["start"], not event["allDay"]))
    return found


def main():
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 14
    config = sys.argv[2] if len(sys.argv) > 2 else ""
    error = ""
    try:
        found = events(days, config) if shutil.which("khal") else None
    except Format as problem:
        found, error = [], str(problem)
    print(json.dumps({"configured": found is not None, "generated": int(time.time()),
                      "error": error, "events": found or []}, ensure_ascii=False))


if __name__ == "__main__":
    main()
