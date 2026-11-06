// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A P T U R E   S E R V I C E                                          │
// │   screenshots · capture, crop and save                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// The capture surface. `capture.py grab-all` photographs the screens, an
// overlay on each draws its picture with the selection on top, and
// `capture.py finish` crops the one picked and sends it to its destination.
// Nothing is frozen, and the result is exactly what was on screen when the key
// was pressed, menus included.
//
// Shape and kind are remembered (`captureShape`, `captureKind`); the
// destination resets to a file every time.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/capture.py")

    // ── TOOLS ───────────────────────────────────────────────────────────────

    // Probed once and filled asynchronously; use `can()`. A missing tool
    // disables its control.
    property var tools: ({})
    property bool ready: false

    readonly property string directory: root.tools.directory ?? ""

    function can(what: string): bool {
        return root.tools[what] === true
    }

    // ── SURFACE ─────────────────────────────────────────────────────────────

    // The photos by screen name: `{ path, width, height }` in physical pixels.
    // The surface works in logical coordinates and the crop in physical ones;
    // `ratio` converts, for the screen that was picked.
    property var photos: ({})
    property int photoWidth: 0
    property int photoHeight: 0

    property bool active: false
    property bool busy: false

    // Delay a caller closing a panel passes to `open()`, so the panel is gone
    // from the photo. It is the island's close animation, 0 with motion off.
    readonly property int settle: Theme.durationIslandGone

    // Every screen is photographed (`captureScreens` is "all") or only the one
    // with the keyboard when the key was pressed. With every screen, the
    // surface opens on all of them and the first selection made on any one
    // wins.
    readonly property bool everyScreen: SettingsService.captureScreens === "all"

    // The screen picked, held for as long as the capture lasts.
    property string screenName: ""

    readonly property var screen: {
        const named = Quickshell.screens.find(screen => screen.name === root.screenName)
        return named ?? MonitorService.primaryScreen ?? Quickshell.screens[0] ?? null
    }

    readonly property real ratio: {
        const screen = root.screen
        if (!screen || screen.width <= 0 || root.photoWidth <= 0)
            return 1
        return root.photoWidth / screen.width
    }

    // Screens to photograph now.
    function screensToGrab(): var {
        if (root.everyScreen)
            return Quickshell.screens.map(screen => screen.name)
        const name = HyprlandService.focusedMonitor
            || MonitorService.primaryScreen?.name
            || Quickshell.screens[0]?.name
            || ""
        return name === "" ? [] : [name]
    }

    // Drops the photos, except the one at `keep`.
    function dropPhotos(keep: string): void {
        for (const name in root.photos) {
            const path = root.photos[name].path
            if (path && path !== keep)
                Quickshell.execDetached([root.script, "drop", path])
        }
        root.photos = ({})
    }

    // ── OPTIONS ─────────────────────────────────────────────────────────────

    readonly property var shapes: ["region", "window", "screen"]
    readonly property var kinds: ["photo", "video"]
    readonly property var destinations: ["file", "clipboard", "editor", "text"]

    readonly property string shape: SettingsService.captureShape
    readonly property string kind: SettingsService.captureKind
    property string to: "file"

    function setShape(id: string): void {
        SettingsService.set("captureShape", id)
    }

    function setKind(id: string): void {
        SettingsService.set("captureKind", id)
    }

    // Destinations whose tool is missing are not offered.
    function offers(id: string): bool {
        if (id === "editor")
            return root.can("editor")
        if (id === "text")
            return root.can("text")
        return true
    }

    // ── OPEN AND CLOSE ──────────────────────────────────────────────────────

    signal opened()

    // A window and a region reach the encoder as the same rectangle, so the
    // shape is passed along with it.
    signal recordRequested(string shape, string geometry)

    // Empty `shape`/`kind` keep the last choice.
    function open(shape: string, kind: string, destination: string, after: int): void {
        if (root.active || root.busy)
            return
        if (shape !== "")
            root.setShape(shape)
        if (kind !== "")
            root.setKind(kind)
        root.to = destination !== "" && root.offers(destination) ? destination : "file"
        root.busy = true
        root.launch.interval = after
        root.launch.restart()
    }

    // Escape or a click on nothing. Also deletes the photos, so a cancelled
    // capture leaves no file behind.
    function cancel(): void {
        if (!root.active)
            return
        root.active = false
        root.dropPhotos("")
    }

    // Logical coordinates on the screen called `name`. An empty box means the
    // whole screen: no crop.
    function fire(name: string, x: real, y: real, width: real, height: real): void {
        const shot = root.photos[name]
        if (!root.active || !shot)
            return
        const whole = width <= 0 || height <= 0
        const picture = shot.path
        const kind = root.kind
        const destination = root.to

        root.screenName = name
        root.photoWidth = shot.width
        root.photoHeight = shot.height

        // Hide the surface first, or it would end up in a recording.
        root.active = false
        root.dropPhotos(kind === "video" ? "" : picture)

        if (kind === "video") {
            // Recordings are of the live screen, so the photos are discarded
            // and only the box is passed on. `shell.qml` connects this to the
            // recorder, which keeps the two services free of a cycle.
            root.recordRequested(whole ? "screen" : root.shape,
                                 whole ? "" : root.box(x, y, width, height))
            return
        }

        const command = [root.script, "finish", picture]
        if (!whole)
            command.push("--geometry", root.crop(x, y, width, height))
        command.push("--to", destination)
        root.shooter.command = command
        root.shooter.running = true
    }

    // The surface works in its own screen's coordinates. `box` is in the
    // compositor's, for the recorder, so the screen's corner goes back on;
    // `crop` is in the photo's pixels, and the photo is that screen alone.
    function box(x: real, y: real, width: real, height: real): string {
        const left = root.screen?.x ?? 0
        const top = root.screen?.y ?? 0
        return `${Math.round(x + left)},${Math.round(y + top)} `
             + `${Math.round(width)}x${Math.round(height)}`
    }

    function crop(x: real, y: real, width: real, height: real): string {
        const r = root.ratio
        return `${Math.round(x * r)},${Math.round(y * r)} `
             + `${Math.round(width * r)}x${Math.round(height * r)}`
    }

    // ── PROCESSES ───────────────────────────────────────────────────────────

    readonly property Process probe: Process {
        command: [root.script, "tools"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.tools = JSON.parse(text)
                    root.ready = true
                } catch (error) {
                    console.warn("Cannot read what capture.py can do:", error)
                }
            }
        }
    }

    readonly property Timer launch: Timer {
        onTriggered: {
            const names = root.screensToGrab()
            if (names.length === 0) {
                root.busy = false
                return
            }
            root.grabber.command = [root.script, "grab-all"].concat(names)
            root.grabber.running = true
        }
    }

    readonly property Process grabber: Process {
        command: [root.script, "grab-all"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false
                let report
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    return
                }
                const taken = {}
                let failure = report.error ?? ""
                for (const name in (report.screens ?? {})) {
                    const photo = report.screens[name]
                    if (photo.path)
                        taken[name] = photo
                    else
                        failure = photo.error ?? failure
                }
                if (Object.keys(taken).length === 0) {
                    OsdService.requested(root.marks.error, failure || "Nothing was captured", -1)
                    return
                }
                root.photos = taken
                root.active = true
                root.opened()
            }
        }
    }

    readonly property Process shooter: Process {
        stdout: StdioCollector {
            onStreamFinished: root.took(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("capture:", text.trim())
            }
        }
    }

    // ── OSD ─────────────────────────────────────────────────────────────────

    readonly property var marks: ({
        file: "󰹑",
        clipboard: "󰹑",
        editor: "󰏫",
        text: "󱄽",
        error: "󰀦"
    })

    function took(text: string): void {
        let report
        try {
            report = JSON.parse(text)
        } catch (error) {
            return
        }
        if (report.cancelled)
            return
        if (report.error) {
            OsdService.requested(root.marks.error, report.error, -1)
            return
        }
        OsdService.requested(root.marks[report.to] ?? root.marks.file,
                             root.said(report), -1)
    }

    function said(report: var): string {
        switch (report.to) {
        case "file":
            // File name only; the directory is always the same.
            return String(report.path ?? "").split("/").pop()
        case "clipboard":
            return report.copied ? "Copied" : "Not copied"
        case "editor":
            return "Opening the editor"
        case "text":
            if (!report.characters)
                return "No text found"
            return report.copied
                ? `${report.characters} characters copied`
                : `${report.characters} characters`
        }
        return ""
    }
}
