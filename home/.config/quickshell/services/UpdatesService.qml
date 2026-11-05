// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   U P D A T E S   S E R V I C E                                          │
// │   pending packages · the repositories and the AUR                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Counts pending updates (repositories and AUR) with `updates.py`. Nothing is
// installed from here; the packages panel opens a terminal for that.
//
// `tool` records which source answered: checkupdates (synced to a temporary
// database) or, without it, the local database as last synced.
Singleton {
    id: root

    // Minutes between two looks (`SettingsService.updatesCheckMinutes`); 0 is
    // only when asked.
    readonly property int pollInterval: SettingsService.updatesCheckMinutes * 60000
    readonly property string every: SettingsService.periodLabel(SettingsService.updatesCheckMinutes)

    property int watchers: 0
    property bool available: false
    property bool checking: false

    property int count: 0
    property var packages: []
    // `{ name, from, to, source }`, source "repo" or "aur". `packages` holds
    // only the first few names, for the module's single line.
    property var updates: []
    // Whether the AUR answered; offline the count covers the repositories only.
    property bool aur: false
    property string tool: ""
    property real checkedAt: 0

    // Query on construction: the bar only builds the module once `available`
    // is known, and reading it is what constructs the singleton.
    Component.onCompleted: root.refresh()

    // Wall-clock, so "checked … ago" moves between polls rather than jumping.
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    readonly property string age: {
        if (root.checkedAt <= 0)
            return ""
        const minutes = Math.max(0, Math.round(
            (root.clock.date.getTime() - root.checkedAt) / 60000))
        if (minutes < 1)
            return "just now"
        if (minutes < 60)
            return `${minutes} min ago`
        const hours = Math.floor(minutes / 60)
        return `${hours} h ${minutes % 60} min ago`
    }

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        if (root.checking)
            return
        root.checking = true
        root.query.running = true
    }

    readonly property Timer poller: Timer {
        interval: Math.max(60000, root.pollInterval)
        repeat: true
        running: root.watchers > 0 && root.pollInterval > 0
        onTriggered: root.refresh()
    }

    readonly property Process query: Process {
        command: [Quickshell.shellPath("scripts/updates.py")]
        onExited: root.checking = false
        stdout: StdioCollector {
            // Per stream, never per chunk: JSON.parse on half a document
            // throws, and the collector fires as the pipe fills.
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the updates report:", error)
                    return
                }
                root.available = report.available === true
                if (!root.available)
                    return
                root.count = report.count ?? 0
                root.packages = report.packages ?? []
                root.updates = report.updates ?? []
                root.aur = report.aur === true
                root.tool = report.tool ?? ""
                root.checkedAt = Date.now()
            }
        }
    }
}
