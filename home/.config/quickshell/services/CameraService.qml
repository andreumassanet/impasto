// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A M E R A   S E R V I C E                                            │
// │   camera effects · the virtual camera, its effect and its reactions      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// `camera.py serve` keeps the "impasto camera" device listed for every
// program, and turns the webcam on only while one of them streams from it.
// The effect, the reactions and the palette go to it through `configure`.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/camera.py")

    // Declared for the island, which is sized before the panel exists.
    readonly property int panelWidth: 820
    readonly property int panelHeight: 517

    // What `status` found: whether the effects can run, and what is missing.
    property bool ready: false
    property bool checked: false
    property var missing: []

    // What the server last said.
    property string state: "off"
    property var readers: []
    property real fps: 0
    property int faces: -1
    property string error: ""

    // Who sees the camera besides the panel's own preview.
    readonly property var others: root.readers.filter(name => name !== "qs" && name !== "quickshell")

    readonly property bool enabled: SettingsService.cameraEnabled
    readonly property bool serving: root.server.running

    readonly property var effects: [
        { id: "natural", label: "Natural",      mark: "" },
        { id: "palette", label: "Palette",      mark: "" },
        { id: "mono",    label: "Mono",         mark: "" },
        { id: "warm",    label: "Warm",         mark: "" },
        { id: "blur",    label: "Blur back",    mark: "" },
        { id: "stage",   label: "Centre Stage", mark: "" },
        { id: "shades",  label: "Shades",       mark: "🕶️" },
        { id: "crown",   label: "Crown",        mark: "👑" },
        { id: "sparkle", label: "Sparkle",      mark: "✨" }
    ]

    readonly property var reactions: [
        { id: "thumbsup",   gesture: "👍", label: "Thumbs up" },
        { id: "thumbsdown", gesture: "👎", label: "Thumbs down" },
        { id: "heart",      gesture: "🫶", label: "Heart" },
        { id: "peace",      gesture: "✌️", label: "Peace" },
        { id: "horns",      gesture: "🤘", label: "Horns" },
        { id: "ok",         gesture: "👌", label: "OK" },
        { id: "middle",     gesture: "🖕", label: "Middle finger" }
    ]

    readonly property string effect: SettingsService.cameraEffect

    function reacting(id: string): bool {
        return SettingsService.cameraReactions.indexOf(id) >= 0
    }

    function setReaction(id: string, on: bool): void {
        const kept = SettingsService.cameraReactions.filter(entry => entry !== id)
        SettingsService.set("cameraReactions", on ? kept.concat([id]) : kept)
    }

    // The effect tiles are one sample portrait, a generated face, with each
    // effect laid on it; the mask is the person cut out, for the blur.
    readonly property string samples:
        `${Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"}/impasto/camera`
    readonly property string sample: `file://${root.samples}/sample.jpg`
    readonly property string sampleMask: `file://${root.samples}/sample-mask.png`

    // Where the sample's face is, as fractions of the picture, for the marks.
    readonly property point sampleEyes: Qt.point(0.498, 0.512)
    readonly property point sampleForehead: Qt.point(0.508, 0.279)

    // ── STATUS ──────────────────────────────────────────────────────────────

    readonly property Process checker: Process {
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const found = JSON.parse(text)
                    root.ready = found.ready
                    root.missing = found.missing ?? []
                } catch (error) {
                    console.warn("Cannot read the camera's status:", error)
                }
                root.checked = true
                root.tend()
            }
        }
    }

    // Asked again whenever the panel opens, which also gives a server that
    // was left off another chance.
    function check(): void {
        root.failures = 0
        if (!root.checker.running)
            root.checker.running = true
    }

    Component.onCompleted: root.check()

    // ── SERVER ──────────────────────────────────────────────────────────────

    readonly property bool wanted: root.ready && root.enabled

    onWantedChanged: root.tend()

    // Managed by `tend()`, as the clipboard watcher is: a binding on
    // `running` breaks the first time the process exits. The script takes a
    // pidfile, so a restart still ends with one server.
    readonly property Process server: Process {
        command: [root.script, "serve"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.hear(JSON.parse(line))
                } catch (error) {}
            }
        }
        onExited: {
            root.state = "off"
            root.readers = []
            root.exited()
        }
    }

    property real started: 0
    // Servers that died within seconds of starting, in a row. Reloads in
    // quick succession cost one or two while the displaced server lets go
    // of the device; one that keeps dying is broken.
    property int failures: 0
    property bool waiting: false

    readonly property Timer retry: Timer {
        interval: 3000
        onTriggered: {
            root.waiting = false
            root.tend()
        }
    }

    function exited(): void {
        if (Date.now() - root.started < 5000)
            root.failures += 1
        else
            root.failures = 0
        root.tend()
    }

    function tend(): void {
        if (!root.wanted) {
            if (root.server.running)
                root.server.running = false
            return
        }
        if (root.server.running || root.waiting)
            return
        if (root.failures > 4) {
            console.warn("The camera server will not stay up; leaving it off.")
            return
        }
        if (root.failures > 0 && Date.now() - root.started < 3000) {
            root.waiting = true
            root.retry.start()
            return
        }
        root.started = Date.now()
        root.configure()
        root.server.running = true
    }

    function hear(said: var): void {
        if (said.state !== undefined) {
            root.state = said.state
            if (said.state !== "error")
                root.error = ""
            if (said.state !== "live") {
                root.fps = 0
                root.faces = -1
            }
        }
        if (said.readers !== undefined)
            root.readers = said.readers
        if (said.error !== undefined)
            root.error = said.error
        if (said.fps !== undefined) {
            root.fps = said.fps
            root.faces = said.faces ?? -1
        }
    }

    // ── PHOTO ───────────────────────────────────────────────────────────────

    // A photo, mirrored as the preview shows it, saved in the camera's own
    // folder and copied. Only while the camera runs, which the panel's preview ensures.
    property bool snapping: false

    signal snapped(bool ok)

    readonly property Process snapper: Process {
        // What follows the time in a saved file's name.
        environment: ({ IMPASTO_CAPTURE_SUFFIX: SettingsService.captureSuffix })
        command: [root.script, "snap"]
        stdout: StdioCollector {
            onStreamFinished: {
                let reply = {}
                try {
                    reply = JSON.parse(text)
                } catch (error) {}
                if (reply.saved) {
                    OsdService.requested("󰄀", reply.copied ? Tr.t("Photo saved and copied") : Tr.t("Photo saved"), -1)
                    root.snapped(true)
                } else {
                    OsdService.requested("󰀦", reply.error ?? Tr.t("No photo was taken"), -1)
                    root.snapped(false)
                }
            }
        }
        onExited: root.snapping = false
    }

    function snap(): void {
        if (root.snapping || root.state !== "live")
            return
        root.snapping = true
        root.snapper.running = true
    }

    // ── CONFIGURATION ───────────────────────────────────────────────────────

    readonly property string configuration: JSON.stringify({
        effect: root.effect,
        reactions: root.reactions.reduce((all, entry) => {
            all[entry.id] = root.reacting(entry.id)
            return all
        }, {}),
        palette: {
            accent: String(Theme.accent),
            red: String(Theme.red),
            yellow: String(Theme.yellow),
            green: String(Theme.green),
            blue: String(Theme.blue)
        }
    })

    onConfigurationChanged: root.writer.restart()

    readonly property Timer writer: Timer {
        interval: 120
        onTriggered: root.configure()
    }

    // A write asked for while one runs goes when it exits, with the
    // configuration as it is then; stopping it could lose both.
    property bool reconfigure: false
    readonly property Process configurer: Process {
        onExited: if (root.reconfigure) {
            root.reconfigure = false
            root.configure()
        }
    }

    function configure(): void {
        if (root.configurer.running) {
            root.reconfigure = true
            return
        }
        root.configurer.command = [root.script, "configure", root.configuration]
        root.configurer.running = true
    }
}
