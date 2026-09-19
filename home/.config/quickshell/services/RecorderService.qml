// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   R E C O R D E R   S E R V I C E                                        │
// │   screen recording state and elapsed time                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One recording at a time. `record.py` owns the encoder, the file and the
// pid; this owns the clock and the bar state. The recording outlives the
// shell, so `status` is queried on startup to pick up a take in progress.
//
// Elapsed time is computed from the start time rather than accumulated per
// tick, so it cannot drift from the file.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/record.py")

    property var tools: ({})

    // Empty when no encoder is installed, which hides the module.
    readonly property string tool: root.tools.tool ?? ""
    readonly property bool available: root.tool !== ""
    readonly property bool canAudio: root.tools.audio === true

    property bool recording: false
    property real startedAt: 0
    property int seconds: 0

    // Read from the take's state file, not the setting, so it survives a
    // shell restart and is unaffected by changing the setting mid-take.
    property string shape: "screen"

    // Whether system audio is recorded; also the take's own value.
    property bool sound: false

    // Bytes on disk; polled only while the detail is open.
    property real size: 0

    // The current file, or the last one written.
    property string path: ""

    readonly property string name: root.path === ""
        ? "" : String(root.path).split("/").pop()

    // Shared by the module card, the control centre tile and the settings.
    readonly property var shapeNames: ({
        screen: "The screen",
        region: "A region",
        window: "A window"
    })

    // The running take's shape, or the one set for the next.
    readonly property string subject: root.shapeNames[
        root.recording ? root.shape : SettingsService.recorderShape]
        ?? root.shapeNames.screen

    readonly property string display: {
        const total = Math.max(0, root.seconds)
        const minutes = Math.floor(total / 60)
        const rest = total % 60
        return `${minutes}:${String(rest).padStart(2, "0")}`
    }

    readonly property Timer clock: Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.seconds =
            Math.max(0, Math.floor(Date.now() / 1000 - root.startedAt))
    }

    readonly property Process probe: Process {
        command: [root.script, "tools"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.tools = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot read what record.py can do:", error)
                }
                // Only then: without an encoder there is nothing to ask about.
                if (root.available)
                    root.ask.running = true
            }
        }
    }

    readonly property Process ask: Process {
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    readonly property Process action: Process {
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("record:", text.trim())
            }
        }
    }

    // `geometry` comes from the capture surface, or "" for the whole screen.
    // `shape` is passed separately: a window and a region are the same
    // rectangle by now.
    function startAt(shape: string, geometry: string): void {
        if (root.recording || root.action.running)
            return
        const command = [root.script, "start", "--shape", shape]
        if (geometry !== "")
            command.push("--geometry", geometry)
        else if (HyprlandService.focusedMonitor !== "")
            command.push("--output", HyprlandService.focusedMonitor)
        if (SettingsService.recorderAudio && root.canAudio)
            command.push("--audio")
        root.action.command = command
        root.action.running = true
    }

    // Handled in `shell.qml`, which opens the capture surface; calling
    // CaptureService directly would create a dependency cycle.
    signal surfaceRequested(string shape, int after)

    function stop(): void {
        if (!root.recording)
            return
        root.action.command = [root.script, "stop"]
        root.action.running = true
    }

    // Shared by the key and the tile. For any shape but the whole screen it
    // opens the capture surface in video mode; the take starts when the
    // surface closes.
    function toggle(after: int): void {
        if (root.recording)
            root.stop()
        else if (SettingsService.recorderShape === "screen")
            root.startAt("screen", "")
        else
            root.surfaceRequested(SettingsService.recorderShape, after)
    }

    // File size; the detail calls this only while it is on screen.
    function measure(): void {
        if (!root.recording || root.ask.running || root.action.running)
            return
        root.ask.running = true
    }

    function ingest(text: string): void {
        let report
        try {
            report = JSON.parse(text)
        } catch (error) {
            return
        }
        if (report.cancelled)
            return
        if (report.error) {
            OsdService.requested("󰀦", report.error, -1)
            return
        }

        const was = root.recording
        root.recording = report.recording === true
        if (report.path)
            root.path = report.path
        if (report.shape)
            root.shape = report.shape
        if (report.audio !== undefined)
            root.sound = report.audio === true
        if (report.size !== undefined)
            root.size = report.size

        if (root.recording) {
            // `started` comes back from a status of something already
            // running; a take just begun starts now.
            root.startedAt = report.started ?? (Date.now() / 1000)
            root.seconds = report.seconds ?? 0
            if (!was)
                OsdService.requested("󰑊", "Recording", -1)
            return
        }

        // A stop reports what it wrote; a status with nothing running says
        // nothing. The OSD shows the length, since the file name does not
        // fit its 260 px; the name is on the module's card.
        if (was && report.seconds !== undefined) {
            root.seconds = report.seconds
            OsdService.requested("󰕧", `Recorded ${root.display}`, -1)
        }
    }
}
