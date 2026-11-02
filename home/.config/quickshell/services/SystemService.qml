// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S Y S T E M   S E R V I C E                                            │
// │   radios and power profile · polled radios, the pushed profile           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

import "../theme"

// Wi-Fi and Bluetooth have no push interface reachable from here, so they
// are polled, only while a panel holds a subscribe(). The power profile is
// pushed by power-profiles-daemon over D-Bus; the poll only says whether the
// daemon answers at all.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/system.py")
    readonly property int pollInterval: 4000

    property int watchers: 0

    property bool wifi: false
    property bool bluetooth: false
    property bool powerAvailable: false

    // False until the first successful read, so the UI can hold back rather
    // than showing a plausible-looking default.
    property bool ready: false

    // The daemon's own names. Performance is offered only where the machine
    // has it.
    readonly property var powerProfiles: [
        { id: "power-saver", label: "Saver", icon: "󰌪" },
        { id: "balanced", label: "Balanced", icon: "󰗑" }
    ].concat(PowerProfiles.hasPerformanceProfile
        ? [{ id: "performance", label: "Performance", icon: "󰓅" }] : [])

    readonly property string powerProfile: !root.powerAvailable ? ""
        : PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver"
        : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    readonly property string powerLabel:
        root.powerProfiles.find(profile => profile.id === root.powerProfile)?.label ?? ""
    readonly property bool performanceMode: root.powerProfile === "performance"

    // The power page, declared since the island takes its size before the
    // panel exists: a heading and one row per profile.
    readonly property int panelWidth: 440
    readonly property int panelHeight: 2 * Theme.panelPadding + Theme.detailHeader
        + Theme.detailSection(root.powerProfiles.length)

    readonly property Process statusProcess: Process {
        command: [root.script, "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    readonly property Process actionProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    readonly property Timer pollTimer: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    function ingest(text: string): void {
        if (!text || text.trim() === "")
            return
        let state
        try {
            state = JSON.parse(text)
        } catch (error) {
            console.warn("Cannot parse the system state:", error)
            return
        }

        // A null field means the tool behind it is missing; keep the last
        // known value rather than snapping the control to a wrong one.
        if (state.wifi !== null) root.wifi = state.wifi
        if (state.bluetooth !== null) root.bluetooth = state.bluetooth
        root.powerAvailable = Boolean(state.powerProfile)
        root.ready = true
    }

    function refresh(): void {
        root.statusProcess.running = true
    }

    // Pair with release().
    function subscribe(): void {
        root.watchers += 1
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function setPowerProfile(id: string): void {
        PowerProfiles.profile = id === "power-saver" ? PowerProfile.PowerSaver
            : id === "performance" ? PowerProfile.Performance : PowerProfile.Balanced
    }

    // The tile's press: performance on, or back to balanced.
    function togglePerformance(): void {
        root.setPowerProfile(root.performanceMode ? "balanced" : "performance")
    }

    function toggle(target: string): void {
        // Toggling Bluetooth swaps the audio sink; that volume change is not
        // worth an OSD.
        if (target === "bluetooth")
            OsdService.suppressAudio()
        root.actionProcess.command = [root.script, "toggle", target]
        root.actionProcess.running = true
    }
}
