// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A G E N D A   S E R V I C E                                            │
// │   the calendar's events from khal, by day                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The events of the calendars linked in Settings (`calendarLinks`) and of
// those khal reads (`scripts/agenda.py`), for the calendar card: a dot on each day that has any, and a day's in its list.
// Read while a card is subscribed, around the month it shows, and every
// five minutes while it stays open; with no khal, or no calendar set up for
// it, there are none and nothing changes.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/agenda.py")

    // Whether there is any calendar to read; false hides nothing, it only
    // means there are no events.
    property bool configured: false
    property string error: ""
    // How each link read, by address: `{ ok, error, count }`.
    property var links: ({})
    // The events by day, `yyyy-MM-dd`, each list in the order they start.
    property var byDay: ({})

    property int subscribers: 0

    function subscribe(): void {
        root.subscribers += 1
        root.refresh()
    }

    function release(): void {
        root.subscribers = Math.max(0, root.subscribers - 1)
    }

    function on(day: string): var {
        return root.byDay[day] ?? []
    }

    // The month a card shows; the read covers it and the months either side.
    property date month: new Date()

    function show(month: date): void {
        const changed = month.getFullYear() !== root.month.getFullYear()
            || month.getMonth() !== root.month.getMonth()
        root.month = month
        if (changed)
            root.refresh()
    }

    // `fetch` downloads every link again rather than reading its copy, as
    // when the links have just changed.
    function refresh(fetch: bool): void {
        if (root.reader.running) {
            root.again = true
            root.againFetch = root.againFetch || fetch === true
            return
        }
        const from = new Date(root.month.getFullYear(), root.month.getMonth() - 1, 1)
        root.reader.command = [root.script, Qt.formatDate(from, "yyyy-MM-dd"), "100"]
            .concat(fetch === true ? ["--fetch"] : [])
        root.reader.running = true
    }

    // Read again whenever the links change.
    readonly property Connections linkWatch: Connections {
        target: SettingsService
        function onCalendarLinksChanged(): void { root.refresh(true) }
    }

    function addLink(name: string, url: string): void {
        const kept = Array.from(SettingsService.calendarLinks ?? [])
            .filter(link => link.url !== url)
        kept.push({ name: name, url: url })
        SettingsService.set("calendarLinks", kept)
    }

    function removeLink(url: string): void {
        SettingsService.set("calendarLinks",
            Array.from(SettingsService.calendarLinks ?? []).filter(link => link.url !== url))
    }

    // A read asked for while one runs, done when it ends.
    property bool again: false
    property bool againFetch: false

    readonly property Process reader: Process {
        // The links as the shell holds them, ahead of the file's next write.
        environment: ({ IMPASTO_CALENDAR_LINKS: JSON.stringify(SettingsService.calendarLinks ?? []) })
        onExited: {
            if (root.again) {
                const fetch = root.againFetch
                root.again = false
                root.againFetch = false
                root.refresh(fetch)
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let answer = {}
                try {
                    answer = JSON.parse(text)
                } catch (error) {
                    return
                }
                root.configured = answer.configured === true
                root.error = answer.error ?? ""
                const links = {}
                for (const link of answer.links ?? [])
                    links[link.url] = link
                root.links = links
                if (root.error !== "")
                    console.warn("Agenda:", root.error)
                const days = {}
                for (const event of answer.events ?? [])
                    (days[event.day] = days[event.day] ?? []).push(event)
                root.byDay = days
            }
        }
    }

    readonly property Timer poll: Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: root.subscribers > 0
        onTriggered: root.refresh()
    }
}
