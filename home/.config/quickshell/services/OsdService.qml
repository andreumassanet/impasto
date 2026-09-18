// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O S D   S E R V I C E                                                  │
// │   turns system changes into one transient island event                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell

// Every ephemeral system change arrives at the island through one signal.
//
// Volume, brightness and battery all render in the same layer, so adding an
// event later means emitting `requested`, not writing another layer. A bar is
// drawn when `progress` is 0 or more; pass -1 for a message with no level.
Singleton {
    id: root

    signal requested(string icon, string label, real progress)

    // Bindings fire once as they initialise. Emitting then would pop an OSD
    // every time the shell starts, so nothing is emitted until this is armed.
    property bool armed: false

    // One frame. Holding a volume key fires dozens of changes and the island
    // would stutter through every one of them.
    readonly property int debounce: 16

    // A device connecting reports its own volume, which is not the user asking
    // to see the volume. Ignore it for as long as the switch takes.
    property bool audioSuppressed: false
    readonly property int suppression: 2000

    readonly property Timer armTimer: Timer {
        interval: 600
        running: true
        onTriggered: root.armed = true
    }

    readonly property Timer suppressionTimer: Timer {
        interval: root.suppression
        onTriggered: root.audioSuppressed = false
    }

    readonly property Timer volumeTimer: Timer {
        interval: root.debounce
        // Muted keeps the real level, so raising the volume while muted still
        // shows the new value. Skipped while the volume detail is open: its
        // slider already shows it, and the OSD would cover it.
        onTriggered: {
            if (ModuleService.openId === "volume")
                return
            root.requested(AudioService.icon,
                           `${AudioService.volume}%`,
                           AudioService.volume / 100)
        }
    }

    // The screen whose level changed, which is not always the focused one:
    // the backlight also moves on its own.
    property var brightnessDisplay: null

    readonly property Timer brightnessTimer: Timer {
        interval: root.debounce
        // Skipped while the brightness detail is open.
        onTriggered: {
            const display = root.brightnessDisplay
            if (!display || ModuleService.openId === "brightness")
                return
            root.requested(display.icon, `${display.percent}%`, display.percent / 100)
        }
    }

    readonly property Connections audio: Connections {
        target: AudioService
        enabled: root.armed && !root.audioSuppressed
        function onVolumeChanged(): void { root.volumeTimer.restart() }
        function onMutedChanged(): void { root.volumeTimer.restart() }
    }

    // Not on the reading: that also changes when the focus moves to another
    // screen, which is not the user asking to see it.
    readonly property Connections brightness: Connections {
        target: BrightnessService
        enabled: root.armed
        function onAdjusted(display): void {
            root.brightnessDisplay = display
            root.brightnessTimer.restart()
        }
    }

    // Not debounced: plugging in cannot repeat fast enough to need it.
    readonly property Connections battery: Connections {
        target: BatteryService
        enabled: root.armed
        function onChargingChanged(): void {
            root.requested(BatteryService.icon,
                           BatteryService.charging ? "Charging" : "On battery",
                           BatteryService.percent / 100)
        }
    }

    function suppressAudio(): void {
        root.audioSuppressed = true
        root.suppressionTimer.restart()
    }
}
