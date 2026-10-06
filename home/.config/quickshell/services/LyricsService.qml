// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L Y R I C S   S E R V I C E                                            │
// │   the playing track's lyrics · the line being sung                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "."

// Asked for only while something on screen holds a subscribe(), and only
// with the setting on: every lookup tells lrclib.net what is playing.
Singleton {
    id: root

    property int watchers: 0
    readonly property bool wanted: root.watchers > 0 && SettingsService.lyrics
        && MediaService.available && MediaService.title !== ""

    // Lyrics are looked up per track; the length is part of it because
    // lrclib matches on it.
    readonly property string track: MediaService.available
        ? [MediaService.artist, MediaService.title, MediaService.album,
           Math.round(MediaService.length)].join("\n")
        : ""

    property string readFor: ""
    property var lines: []
    property bool synced: false
    property bool instrumental: false
    readonly property bool loading: root.wanted && root.readFor !== root.track
    // Kept once read, so a detail opening as the glance closes is sized for
    // the lyrics without asking again.
    readonly property bool available: SettingsService.lyrics && root.readFor === root.track
        && (root.lines.length > 0 || root.instrumental)

    // The line being sung: the last one already started, -1 before the first.
    property int current: -1
    // Only timed lyrics have a line being sung.
    readonly property string currentText: root.available && root.synced && root.current >= 0
        ? root.lines[root.current].text : ""

    // The line after it, for faces that show what is coming.
    readonly property string nextText: root.available && root.synced
        && root.current + 1 < root.lines.length ? root.lines[root.current + 1].text : ""

    // What a face says when there is no line to show, empty when there is
    // one (or the song has not reached its first line yet).
    readonly property string status: !SettingsService.lyrics ? "Lyrics are off"
        : !MediaService.available ? "Nothing playing"
        : root.loading ? "Looking for lyrics"
        : root.instrumental ? "Instrumental"
        : !root.available ? "No lyrics for this one"
        : !root.synced ? "Lyrics, untimed"
        : ""

    // MPRIS reports the position only when asked, once a second at most, so
    // between readings the clock runs on from the last one.
    property real anchorPosition: 0
    property real anchorTime: 0

    Connections {
        target: MediaService.active

        function onPositionChanged(): void {
            root.anchorPosition = MediaService.position
            root.anchorTime = Date.now()
            root.place()
        }
    }

    // A pause stops the clock where it is; playing again starts it from there.
    Connections {
        target: MediaService

        // Asking the player again re-reads the position, which re-anchors.
        function onPlayingChanged(): void {
            if (MediaService.available)
                MediaService.active.positionChanged()
        }
    }

    readonly property Timer ticker: Timer {
        interval: 120
        repeat: true
        running: root.available && root.synced && MediaService.playing
        onTriggered: root.place()
    }

    // Lines are sung a moment before their stamp reads as late.
    readonly property real lead: 0.25

    function place(): void {
        if (!root.available || !root.synced) {
            root.current = -1
            return
        }
        const elapsed = MediaService.playing ? (Date.now() - root.anchorTime) / 1000 : 0
        const now = root.anchorPosition + elapsed + root.lead
        let index = -1
        for (let i = 0; i < root.lines.length; i++) {
            if (root.lines[i].t > now)
                break
            index = i
        }
        root.current = index
    }

    function subscribe(): void {
        root.watchers += 1
        MediaService.subscribe()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
        MediaService.release()
    }

    onWantedChanged: root.fetch()
    onTrackChanged: {
        root.current = -1
        root.anchorPosition = 0
        root.anchorTime = Date.now()
        root.fetch()
    }
    onAvailableChanged: root.place()

    // A new track while one is asked for waits for that one to come back.
    property bool again: false
    property string asked: ""

    function fetch(): void {
        if (!root.wanted || root.readFor === root.track)
            return
        if (query.running) {
            root.again = true
            return
        }
        root.asked = root.track
        query.command = [Quickshell.shellPath("scripts/lyrics.py"),
                         MediaService.artist, MediaService.title, MediaService.album,
                         String(Math.round(MediaService.length))]
        query.running = true
    }

    Process {
        id: query

        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
        onExited: {
            if (root.again) {
                root.again = false
                Qt.callLater(root.fetch)
            }
        }
    }

    function take(text: string): void {
        let report = null
        try {
            report = JSON.parse(text)
        } catch (error) {
            console.warn("Cannot parse the lyrics report:", error)
            return
        }
        root.lines = report.available === true ? (report.lines ?? []) : []
        root.synced = report.synced === true
        root.instrumental = report.instrumental === true
        root.readFor = root.asked
        root.place()
    }
}
