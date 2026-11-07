// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S U N S E T   S E R V I C E                                            │
// │   night light · runs hyprsunset while enabled                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Night light through hyprsunset, which sets the gamma ramp. Unlike a screen
// shader, that stays out of screenshots and survives `hyprctl reload`.
//
// The same process darkens the picture past the backlight's floor
// (`BrightnessService.dim`), as a gamma below 100 %, so it runs while either
// is wanted, at the identity when only the dim is. The compositor restores
// the ramp when the client disconnects. Changes go through `hyprctl
// hyprsunset` rather than a restart, which would flash daylight, coalesced
// to 120 ms while a slider is dragged.
Singleton {
    id: root

    // 6500 K is a no-op in hyprsunset, so the cool end stops short of it.
    readonly property int warmest: 2500
    readonly property int coolest: 6000

    readonly property string icon: root.on ? "󰃜" : "󰃝"

    readonly property int temperature: SettingsService.nightTemperature

    // hyprsunset is optional; checked once so the tile can say it is missing.
    property bool available: false

    readonly property bool on: SettingsService.nightLight && root.filter.running

    readonly property int gamma: Math.round(100 * (1 - BrightnessService.dim))

    readonly property string detail: {
        if (!root.available)
            return Tr.t("Needs hyprsunset")
        return root.on ? `${root.temperature} K` : Tr.t("Daylight")
    }

    // Warmths to pick with one press, on the night light's page.
    readonly property var presets: [
        { label: "Candle",  kelvin: 2500 },
        { label: "Warm",    kelvin: 3500 },
        { label: "Soft",    kelvin: 4500 },
        { label: "Neutral", kelvin: 5500 }
    ]

    function setTemperature(kelvin: int): void {
        SettingsService.set("nightTemperature", Math.round(kelvin / 100) * 100)
    }

    // The night light's page, declared since the island takes its size
    // before the panel exists: a heading, the warmth, and the presets.
    readonly property int panelWidth: 440
    readonly property int panelHeight: 2 * Theme.panelPadding + Theme.detailHeader
        + Theme.detailSection(1) + Theme.detailSection(root.presets.length)

    readonly property Process probe: Process {
        command: ["sh", "-c", "command -v hyprsunset"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() !== ""
        }
    }

    // Bound to the setting, which also restores it at login. `shell.qml`
    // touches this singleton at startup so that happens before anything
    // opens the control centre.
    readonly property Process filter: Process {
        command: ["hyprsunset",
            ...(SettingsService.nightLight ? ["--temperature", String(root.temperature)] : ["--identity"]),
            "--gamma", String(root.gamma)]
        running: root.available && (SettingsService.nightLight || root.gamma < 100)

        // Exited on its own, usually because another client already holds
        // the gamma ramp. Turn the setting off to match, and say so.
        onExited: {
            if (!SettingsService.nightLight)
                return
            SettingsService.set("nightLight", false)
            OsdService.requested(root.icon, Tr.t("Night light stopped"), -1)
        }
    }

    // Started with whatever is wanted then; later changes are pushed.
    readonly property var wanted: [SettingsService.nightLight, root.temperature, root.gamma]
    onWantedChanged: {
        if (root.filter.running)
            root.retune.restart()
    }

    readonly property Timer retune: Timer {
        interval: 120
        onTriggered: {
            Quickshell.execDetached(SettingsService.nightLight
                ? ["hyprctl", "hyprsunset", "temperature", String(root.temperature)]
                : ["hyprctl", "hyprsunset", "identity"])
            Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", String(root.gamma)])
        }
    }

    function toggle(): void {
        if (!root.available)
            return
        SettingsService.set("nightLight", !SettingsService.nightLight)
    }
}
