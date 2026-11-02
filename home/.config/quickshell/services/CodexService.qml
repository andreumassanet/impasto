// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O D E X   S E R V I C E                                              │
// │   the Codex plan's limits, as Codex last recorded them                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Read from Codex's session logs (`codex_usage.py`), which Codex rewrites on
// every turn, so nothing is asked of the network and the figures are as old as
// the last turn (`observed`). A machine that never ran Codex has no logs, and
// the module is not offered there.
Singleton {
    id: root

    readonly property int pollInterval: 120000

    property int watchers: 0
    property bool available: false
    property string plan: ""
    property real observed: 0
    // `{ name, minutes, used, resets }`, the shorter window first.
    property var limits: []

    // Query once on construction, as `ClaudeService` does: the module is
    // offered only once `available` is true.
    Component.onCompleted: root.refresh()

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    // A window past its reset has renewed, but by how much is unknown until
    // Codex runs again.
    function current(limit: var): bool {
        return limit.resets * 1000 > root.clock.date.getTime()
    }

    readonly property var live: root.limits.filter(limit => root.current(limit))

    readonly property real gauge: root.live.reduce((worst, limit) => Math.max(worst, limit.used), 0)
    readonly property bool measured: root.live.length > 0

    // The fullest window still running, which the faces lead with.
    readonly property var fullest: root.live.reduce(
        (worst, limit) => worst === null || limit.used > worst.used ? limit : worst, null)

    readonly property string fullestName: root.fullest ? root.fullest.name.toLowerCase() : ""

    // "80%", or a dash with nothing running to read.
    readonly property string figure: root.measured ? `${Math.round(root.gauge * 100)}%` : "—"

    // "month · resets in 3 h", "week · resets Mon 14:20".
    function windowLine(limit: var): string {
        if (!limit)
            return ""
        const left = limit.resets * 1000 - root.clock.date.getTime()
        const minutes = Math.ceil(left / 60000)
        const when = minutes <= 0 ? Tr.t("renewed")
            : minutes < 60 ? Tr.t("resets in %1 min").arg(minutes)
            : minutes < 24 * 60 ? Tr.t("resets in %1 h").arg(Math.floor(minutes / 60))
            : Tr.t("resets %1").arg(Qt.formatDateTime(new Date(Math.round(limit.resets / 60) * 60000), "ddd HH:mm"))
        return `${limit.name.toLowerCase()} · ${when}`
    }

    readonly property color tint: {
        if (!root.measured)
            return Theme.indicator
        if (root.gauge >= 0.85)
            return Theme.indicatorBad
        if (root.gauge >= 0.6)
            return Theme.indicatorWarn
        return Theme.indicator
    }

    // "read 5 min ago", "read Mon 14:20".
    readonly property string age: {
        if (root.observed <= 0)
            return ""
        const minutes = Math.floor((root.clock.date.getTime() - root.observed * 1000) / 60000)
        if (minutes < 1)
            return Tr.t("read just now")
        if (minutes < 60)
            return Tr.t("read %1 min ago").arg(minutes)
        if (minutes < 24 * 60)
            return Tr.t("read %1 h ago").arg(Math.floor(minutes / 60))
        return Tr.t("read %1").arg(Qt.formatDateTime(new Date(root.observed * 1000), "ddd d MMM"))
    }

    function subscribe(): void {
        root.watchers += 1
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        root.query.running = true
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    readonly property Process query: Process {
        command: [Quickshell.shellPath("scripts/codex_usage.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the Codex usage report:", error)
                    return
                }
                root.available = report.available === true
                if (!root.available)
                    return
                root.plan = report.plan ?? ""
                root.observed = report.observed ?? 0
                root.limits = (report.limits ?? []).slice().sort((a, b) => a.minutes - b.minutes)
            }
        }
    }
}
