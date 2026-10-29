// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W E A T H E R   S E R V I C E                                          │
// │   weather · current conditions and forecast                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Current conditions from wttr.in via `scripts/weather.py`. With no place
// set, wttr.in geolocates the request's address (no key, no account); the
// place it resolved is shown on the card.
//
// Polled every 15 minutes while something is subscribed. The last reading
// stays in between.
Singleton {
    id: root

    // Minutes between two readings (`SettingsService.weatherRefreshMinutes`); 0
    // is only when asked. Each reading tells wttr.in the connection's address,
    // so nothing is read while nothing shows the weather.
    readonly property int refreshMinutes: SettingsService.weatherRefreshMinutes
    readonly property int pollInterval: root.refreshMinutes * 60000

    property int watchers: 0
    property bool available: false

    // Query on construction, once the settings have been read: the bar needs
    // `available` before the module exists to subscribe, and a query before
    // the place is known is a reading for wherever the IP says.
    Component.onCompleted: {
        if (SettingsService.arrived)
            root.refresh()
    }

    property string place: ""
    property string region: ""
    property int temperature: 0
    property int feelsLike: 0
    property string description: ""
    property string glyph: ""
    // The Breeze icon name (`WeatherIcon`), "" when the script gave none.
    property string icon: ""
    property int humidity: 0
    property int wind: 0
    property string windUnit: "km/h"
    // The dashboard's "Now" grid.
    property int uv: 0
    property int pressure: 0
    property string pressureUnit: "hPa"
    property int visibility: 0
    property string visibilityUnit: "km"
    property int cloud: 0
    property string sunrise: ""
    property string sunset: ""
    // `{ date, low, high, glyph, icon, rain }` per day.
    property var days: []
    property int low: 0
    property int high: 0
    property var hourly: []

    // So the card can show how old the reading is.
    property date readAt: new Date(0)

    // The place setting the reading was asked for. A reading for any other
    // is wrong rather than old, and is fetched again whoever is watching.
    property string readFor: ""
    readonly property string wanted: SettingsService.weatherPlace.trim()
    readonly property bool stale: root.readFor !== root.wanted

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    readonly property string age: {
        if (!root.available)
            return ""
        const minutes = Math.floor((root.clock.date.getTime() - root.readAt.getTime()) / 60000)
        if (minutes < 2)
            return "just now"
        if (minutes < 60)
            return `${minutes} min ago`
        const hours = Math.round(minutes / 60)
        return `${hours} h ago`
    }

    // The three-hour blocks still to come, today's then tomorrow's.
    readonly property var upcoming: {
        const hour = root.clock.date.getHours()
        return (root.hourly ?? []).filter(block => block.tomorrow || block.hour > hour)
    }

    // The next four, running into tomorrow when today has none left.
    readonly property var ahead: root.upcoming.slice(0, 4)

    // A block's label: its hour, with the weekday on tomorrow's first.
    function blockLabel(block: var, index: int, list: var): string {
        const time = `${String(block.hour).padStart(2, "0")}:00`
        const firstOfTomorrow = block.tomorrow && (index === 0 || !list[index - 1].tomorrow)
        if (!firstOfTomorrow)
            return time
        const tomorrow = new Date(root.clock.date.getTime() + 86400000)
        return `${tomorrow.toLocaleDateString(Qt.locale(), "ddd")} ${time}`
    }

    function subscribe(): void {
        root.watchers += 1
        // Only if never read, read for another place or older than the period
        // (never, with "only when asked").
        const minutes = (new Date().getTime() - root.readAt.getTime()) / 60000
        if (!root.available || root.stale || (root.refreshMinutes > 0 && minutes > root.refreshMinutes))
            root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // A query already running was started with the place it had then, so
    // another asked for meanwhile runs when it ends.
    property bool again: false
    // The place the running query was started with, for `readFor`.
    property string asked: ""
    property real askedAt: 0

    function refresh(): void {
        if (!SettingsService.arrived)
            return
        // A run that never reported back in half a minute is given up on.
        const waiting = root.unsettled > 0 && Date.now() - root.askedAt < 30000
        if (root.query.running || waiting) {
            root.again = true
            return
        }
        root.asked = root.wanted
        root.askedAt = Date.now()
        root.unsettled = 2
        root.query.running = true
    }

    readonly property Timer poller: Timer {
        interval: Math.max(60000, root.pollInterval)
        repeat: true
        running: root.watchers > 0 && root.pollInterval > 0
        onTriggered: root.refresh()
    }

    // A new place is a different reading; fetch it now.
    Connections {
        target: SettingsService

        function onWeatherPlaceChanged(): void {
            root.refresh()
        }

        function onArrivedChanged(): void {
            root.refresh()
        }
    }

    property bool placeUnknown: false

    readonly property Process query: Process {
        command: {
            const line = [Quickshell.shellPath("scripts/weather.py")]
            return root.wanted === "" ? line : line.concat([root.wanted])
        }
        onExited: root.settle()
        stdout: StdioCollector {
            onStreamFinished: {
                root.take(text)
                root.settle()
            }
        }
    }

    // A run is over once it has exited and its output has been read, in
    // whichever order those arrive; only then does a queued one start, so
    // the reading is recorded against the place it was asked for.
    property int unsettled: 0
    // A reading is on its way, for the button that asks for one.
    readonly property bool refreshing: root.query.running || root.unsettled > 0

    function settle(): void {
        root.unsettled = Math.max(0, root.unsettled - 1)
        if (root.unsettled > 0 || !root.again)
            return
        root.again = false
        Qt.callLater(root.refresh)
    }

    function take(text: string): void {
        let report = null
        try {
            report = JSON.parse(text)
        } catch (error) {
            console.warn("Cannot parse the weather report:", error)
            return
        }
        // Flagged separately: the last good reading stays on the card,
        // so otherwise an unknown place would look like no change.
        root.placeUnknown = report.reason === "place"
        if (report.available !== true) {
            // Keep the last good reading.
            if (!root.available)
                root.available = false
            return
        }
        root.place = report.place
        root.region = report.region
        root.temperature = report.temperature
        root.feelsLike = report.feelsLike
        root.description = report.description
        root.glyph = report.glyph
        root.icon = report.icon ?? ""
        root.humidity = report.humidity
        root.wind = report.wind
        root.windUnit = report.windUnit ?? "km/h"
        root.uv = report.uv ?? 0
        root.pressure = report.pressure ?? 0
        root.pressureUnit = report.pressureUnit ?? "hPa"
        root.visibility = report.visibility ?? 0
        root.visibilityUnit = report.visibilityUnit ?? "km"
        root.cloud = report.cloud ?? 0
        root.sunrise = report.sunrise ?? ""
        root.sunset = report.sunset ?? ""
        root.days = report.days ?? []
        root.low = report.low
        root.high = report.high
        root.hourly = report.hourly ?? []
        root.readAt = new Date()
        root.readFor = root.asked
        root.available = true
    }
}
