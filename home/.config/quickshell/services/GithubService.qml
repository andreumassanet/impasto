// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G I T H U B   S E R V I C E                                            │
// │   a year of green squares · from a public profile                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// A year of contributions from a public GitHub profile, via
// `scripts/github.py`.
//
// Polls only while something is subscribed and keeps the last good grid when
// a request fails. With no username set there is nothing to show.
Singleton {
    id: root

    readonly property int pollInterval: 1800000

    property int watchers: 0
    property bool available: false

    // First read happens when anything touches the singleton. With no
    // username the backend returns immediately.
    Component.onCompleted: root.refresh()

    property string user: ""
    property int total: 0
    property int streak: 0
    property int today: 0
    property int busiest: 0

    // One array per week, seven entries each (Sunday first): a level 0-4, or
    // null for days outside the range in the partial first and last weeks.
    property var weeks: []

    // True when the configured username has no public profile.
    property bool userUnknown: false

    property date readAt: new Date(0)

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    readonly property string age: {
        if (!root.available)
            return ""
        const minutes = Math.floor((root.clock.date.getTime() - root.readAt.getTime()) / 60000)
        if (minutes < 2)
            return Tr.t("just now")
        if (minutes < 60)
            return Tr.t("%1 min ago").arg(minutes)
        const hours = Math.round(minutes / 60)
        return Tr.t("%1 h ago").arg(hours)
    }

    // "3689" -> "3,689", as GitHub writes it. Shared by every face.
    function grouped(count: int): string {
        return `${count}`.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }

    readonly property string totalLabel: root.grouped(root.total)

    // The graph's height on the module's card: seven 9 px days, 3 px apart.
    readonly property int cardGrid: 7 * 9 + 6 * 3

    function subscribe(): void {
        root.watchers += 1
        // Refresh on subscribe only if the reading is missing or stale.
        const minutes = (new Date().getTime() - root.readAt.getTime()) / 60000
        if (!root.available || minutes > 15)
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

    // A new username refreshes immediately instead of waiting for the poll.
    Connections {
        target: SettingsService

        function onGithubUserChanged(): void {
            root.refresh()
        }
    }

    readonly property Process query: Process {
        command: {
            const line = [Quickshell.shellPath("scripts/github.py")]
            const user = SettingsService.githubUser.trim()
            return user === "" ? line : line.concat([user])
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the GitHub report:", error)
                    return
                }
                root.userUnknown = report.reason === "user"
                    && SettingsService.githubUser.trim() !== ""
                if (report.available !== true) {
                    // Keep the last good grid on failure; clear it only when
                    // the username has been removed.
                    if (SettingsService.githubUser.trim() === "")
                        root.available = false
                    return
                }
                root.user = report.user
                root.total = report.total
                root.streak = report.streak
                root.today = report.today
                root.busiest = report.busiest
                root.weeks = report.weeks ?? []
                root.readAt = new Date()
                root.available = true
            }
        }
    }
}
