#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   W E A T H E R                                                          │
# │   current weather and forecast                                           │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""One wttr.in reading, reduced to what the weather card shows.

With no place configured, wttr.in locates the request by IP, which needs no
key but is only approximate. A named place (a city, a postcode, an airport
code, a `~landmark`) is sent as is. The place that answered is always
reported back.

Any failure is reported as unavailable, never as a guessed value.
"""

import json
import subprocess
import sys
import urllib.parse
from datetime import datetime

ENDPOINT = "https://wttr.in/{place}?format=j1"
TIMEOUT = 12


class PlaceNotFound(Exception):
    """The name was asked for and wttr.in does not know it."""

# wttr.in's condition codes, folded into the handful of shapes worth drawing.
# Its own icon set is line art meant for a terminal; these are Material glyphs
# the rest of the shell already uses.
GLYPHS = [
    ({113}, "󰖨", "󰖔"),                                    # clear
    ({116}, "󰖕", "󰼱"),                                    # partly cloudy
    ({119, 122}, "󰖐", "󰖐"),                               # cloudy, overcast
    ({143, 248, 260}, "󰖑", "󰖑"),                          # mist and fog
    ({176, 263, 266, 293, 296, 353}, "󰼳", "󰼳"),           # light rain
    ({299, 302, 305, 308, 356, 359}, "󰖖", "󰖖"),           # rain
    ({179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371}, "󰼶", "󰼶"),  # snow
    ({200, 386, 389, 392, 395}, "󰙾", "󰙾"),                # thunder
]

FALLBACK = ("󰖐", "󰖐")


# KDE Breeze's full-colour weather icons
# (/usr/share/icons/breeze/applets/48/weather-NAME.svg), by the same codes.
ICONS = [
    ({113}, "clear", "clear-night"),
    ({116}, "few-clouds", "few-clouds-night"),
    ({119}, "clouds", "clouds-night"),
    ({122}, "overcast", "overcast"),
    ({143}, "mist", "mist"),
    ({248, 260}, "fog", "fog"),
    ({176, 263, 266, 293, 296, 353}, "showers-scattered-day", "showers-scattered-night"),
    ({299, 302, 305, 308, 356, 359}, "showers-day", "showers-night"),
    ({281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377}, "freezing-rain-day", "freezing-rain-night"),
    ({179, 227, 323, 326, 368}, "snow-scattered-day", "snow-scattered-night"),
    ({230, 329, 332, 335, 338, 371}, "snow-day", "snow-night"),
    ({182, 185}, "snow-rain", "snow-rain"),
    ({200, 386, 389}, "storm-day", "storm-night"),
    ({392, 395}, "snow-storm-day", "snow-storm-night"),
]


def icon(code, daytime):
    for codes, day, night in ICONS:
        if code in codes:
            return day if daytime else night
    return "clouds" if daytime else "clouds-night"


def glyph(code, daytime):
    for codes, day, night in GLYPHS:
        if code in codes:
            return day if daytime else night
    return FALLBACK[0] if daytime else FALLBACK[1]


def fetch(place):
    # Quoted: place names carry spaces and non-ASCII characters.
    url = ENDPOINT.format(place=urllib.parse.quote(place.strip(), safe=""))
    result = subprocess.run(
        ["curl", "-sS", "--max-time", str(TIMEOUT), url],
        capture_output=True, text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError(result.stderr.strip() or "no answer from wttr.in")
    # An unknown place comes back as 200 with plain text instead of JSON; it
    # is reported apart from a network failure so the settings can show it.
    if not result.stdout.lstrip().startswith("{"):
        raise PlaceNotFound(result.stdout.strip()[:120])
    return json.loads(result.stdout)


def daytime_now(current, today):
    """Whether the sun is up where the reading is: the local observation time
    against today's sunrise and sunset. True when wttr.in sends none of them."""
    try:
        astronomy = today["astronomy"][0]
        observed = datetime.strptime(current["localObsDateTime"].split(" ", 1)[1], "%I:%M %p")
        sunrise = datetime.strptime(astronomy["sunrise"], "%I:%M %p")
        sunset = datetime.strptime(astronomy["sunset"], "%I:%M %p")
    except (KeyError, IndexError, ValueError):
        return True
    return sunrise <= observed < sunset


def report(place):
    data = fetch(place)
    current = data["current_condition"][0]
    area = data["nearest_area"][0]
    today = data["weather"][0]

    code = int(current["weatherCode"])
    # The icon at night is the night one: by the observation's local time and
    # today's sun, since wttr.in gives `isdaytime` only per hour block.
    daytime = daytime_now(current, today)

    return {
        "available": True,
        "place": area["areaName"][0]["value"],
        "region": area["country"][0]["value"],
        "temperature": int(current["temp_C"]),
        "feelsLike": int(current["FeelsLikeC"]),
        "description": current["weatherDesc"][0]["value"].strip(),
        "glyph": glyph(code, daytime),
        "icon": icon(code, daytime),
        "humidity": int(current["humidity"]),
        # The rest of the dashboard's "Now" grid.
        "uv": int(current.get("uvIndex", 0)),
        "pressure": int(current.get("pressure", 0)),
        "pressureUnit": "hPa",
        "visibility": int(current.get("visibility", 0)),
        "visibilityUnit": "km",
        "cloud": int(current.get("cloudcover", 0)),
        "sunrise": today.get("astronomy", [{}])[0].get("sunrise", ""),
        "sunset": today.get("astronomy", [{}])[0].get("sunset", ""),
        "wind": int(current["windspeedKmph"]),
        "windUnit": "km/h",
        "low": int(today["mintempC"]),
        "high": int(today["maxtempC"]),
        # Today and tomorrow, in wttr.in's three-hour steps, so the evening
        # still has a forecast.
        "hourly": [
            {
                "hour": int(block["time"]) // 100,
                "temperature": int(block["tempC"]),
                "glyph": glyph(int(block["weatherCode"]), 6 <= int(block["time"]) // 100 < 21),
                "icon": icon(int(block["weatherCode"]), 6 <= int(block["time"]) // 100 < 21),
                "rain": int(block["chanceofrain"]),
                "tomorrow": day > 0,
            }
            for day, blocks in enumerate(w["hourly"] for w in data["weather"][:2])
            for block in blocks
        ],
        # Every day wttr.in has (three), for the dashboard.
        "days": [
            {
                "date": day["date"],
                "low": int(day["mintempC"]),
                "high": int(day["maxtempC"]),
                "glyph": glyph(int(day["hourly"][len(day["hourly"]) // 2]["weatherCode"]), True),
                "icon": icon(int(day["hourly"][len(day["hourly"]) // 2]["weatherCode"]), True),
                "rain": max(int(block["chanceofrain"]) for block in day["hourly"]),
            }
            for day in data["weather"]
        ],
    }


if __name__ == "__main__":
    # Every argument is part of the place, so callers need not quote it.
    place = " ".join(sys.argv[1:]).strip()
    try:
        print(json.dumps(report(place)))
    except PlaceNotFound as error:
        # Shown in the settings; on any other failure the shell keeps its
        # last good reading.
        sys.stderr.write(f"weather: {error}\n")
        print(json.dumps({"available": False, "reason": "place"}))
    except Exception as error:  # a card must never take the shell down
        sys.stderr.write(f"weather failed: {error}\n")
        print(json.dumps({"available": False}))
