// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T I M E R   S E R V I C E                                              │
// │   one countdown, owned by the island                                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// A single countdown, started from the launcher and shown on the island.
// The end is a wall-clock time rather than a tick count, so a busy machine
// does not make it drift.
Singleton {
    id: root

    signal finished(string label)

    property bool running: false
    // Keeps `remaining` and `duration`, so resume and restart both work.
    property bool paused: false
    property string label: ""
    property real endsAt: 0
    property real duration: 0
    property real remaining: 0

    readonly property real progress:
        root.duration > 0 ? Math.max(0, Math.min(1, root.remaining / root.duration)) : 0

    readonly property int seconds: Math.max(0, Math.ceil(root.remaining / 1000))

    // Fixed indicator hues, not the palette, like the battery.
    readonly property color tint: {
        if (!root.running)
            return Theme.indicatorDim
        if (root.seconds <= 30)
            return Theme.indicatorBad
        if (root.seconds <= 120)
            return Theme.indicatorWarn
        return Theme.indicatorTimer
    }

    readonly property string display: {
        const total = Math.max(0, Math.ceil(root.remaining / 1000))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const seconds = total % 60
        const pad = value => value < 10 ? `0${value}` : `${value}`
        return hours > 0
            ? `${hours}:${pad(minutes)}:${pad(seconds)}`
            : `${minutes}:${pad(seconds)}`
    }

    readonly property Timer ticker: Timer {
        interval: 250
        repeat: true
        running: root.running && !root.paused
        onTriggered: {
            root.remaining = root.endsAt - Date.now()
            if (root.remaining <= 0)
                root.complete()
        }
    }

    readonly property Process notifier: Process {}

    // "25m", "1h30", "90s", "5" (minutes), "1:30". Returns milliseconds, or 0
    // when the text is not a duration at all.
    function parse(text: string): real {
        const clean = (text ?? "").trim().toLowerCase()
        if (clean === "")
            return 0

        // Clock form first: 5:30 is five minutes thirty, not five hours.
        const clock = clean.match(/^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$/)
        if (clock) {
            return clock[3] !== undefined
                ? (Number(clock[1]) * 3600 + Number(clock[2]) * 60 + Number(clock[3])) * 1000
                : (Number(clock[1]) * 60 + Number(clock[2])) * 1000
        }

        // Unit form: runs of "<number><unit>"; a bare trailing number takes
        // the next unit down ("1h30" is an hour and a half). The whole string
        // is validated first so arithmetic like "12*9" is not read as a time.
        if (!/^\d+(?:\.\d+)?\s*[hms]?(?:\s*\d+(?:\.\d+)?\s*[hms]?)*$/.test(clean))
            return 0

        const units = { h: 3600, m: 60, s: 1 }
        const pattern = /(\d+(?:\.\d+)?)\s*(h|m|s)?/g
        let total = 0
        let matched = false
        let lastUnit = null
        let match
        while ((match = pattern.exec(clean)) !== null) {
            const amount = Number(match[1])
            let unit = match[2]
            if (!unit)
                unit = lastUnit === "h" ? "m" : (lastUnit === "m" ? "s" : "m")
            total += amount * units[unit]
            lastUnit = unit
            matched = true
        }
        return matched ? Math.round(total * 1000) : 0
    }

    function start(milliseconds: real, label = ""): void {
        if (milliseconds <= 0)
            return
        root.duration = milliseconds
        root.endsAt = Date.now() + milliseconds
        root.remaining = milliseconds
        root.label = label
        root.paused = false
        root.running = true
    }

    function pause(): void {
        if (!root.running || root.paused)
            return
        // The last tick may be up to 250 ms old.
        root.remaining = Math.max(0, root.endsAt - Date.now())
        root.paused = true
    }

    // Pushes the end forward by the length of the pause.
    function resume(): void {
        if (!root.running || !root.paused)
            return
        root.endsAt = Date.now() + root.remaining
        root.paused = false
    }

    function toggle(): void {
        if (root.paused)
            root.resume()
        else
            root.pause()
    }

    function restart(): void {
        if (root.duration > 0)
            root.start(root.duration, root.label)
    }

    function cancel(): void {
        root.running = false
        root.paused = false
        root.remaining = 0
        root.label = ""
    }

    function complete(): void {
        const finishedLabel = root.label
        root.running = false
        root.paused = false
        root.remaining = 0

        // Through the shell's own notification daemon, so it lands on the
        // island like any other notification.
        root.notifier.command = ["notify-send", "-u", "critical",
                                 finishedLabel === "" ? Tr.t("Timer finished") : finishedLabel,
                                 Tr.t("The countdown has run out.")]
        root.notifier.running = true
        root.finished(finishedLabel)
        root.label = ""
    }
}
