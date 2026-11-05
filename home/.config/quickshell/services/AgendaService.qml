// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A G E N D A   S E R V I C E                                            │
// │   the next two weeks of your calendars, read from khal                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The events `scripts/agenda.py` lists, read when the agenda opens and every
// few minutes while it stays open. Nothing runs while it is closed.
Singleton {
    id: root

    property int watchers: 0
    property bool configured: false
    property bool loaded: false
    property string error: ""
    // Next 14 days, sorted: `{ title, calendar, location, allDay, start, end,
    // date, time, endTime }`.
    property var events: []
    property real now: Date.now() / 1000

    readonly property string today: Qt.formatDate(new Date(root.now * 1000), "yyyy-MM-dd")
    readonly property var upcoming: root.events.filter(event => event.end > root.now)

    function subscribe(): void {
        root.watchers += 1
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        if (!root.reader.running)
            root.reader.running = true
    }

    readonly property Timer poller: Timer {
        interval: 300000
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    readonly property Process reader: Process {
        command: ["python3", "-I", Quickshell.shellPath("scripts/agenda.py"), "14", SettingsService.agendaKhalConfig]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const answer = JSON.parse(text)
                    root.configured = answer.configured
                    root.error = answer.error ?? ""
                    root.events = answer.events ?? []
                    root.now = Date.now() / 1000
                    root.loaded = true
                } catch (error) {
                    console.warn("Agenda: cannot read the answer:", error)
                }
            }
        }
    }
}
