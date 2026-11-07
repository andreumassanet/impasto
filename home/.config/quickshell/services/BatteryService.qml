// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A T T E R Y   S E R V I C E                                          │
// │   charge level and power state · reactive, via upower                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

import "../theme"

// Battery state, pushed by UPower rather than polled out of sysfs.
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: root.device !== null
        && root.device.ready
        && root.device.isLaptopBattery

    // UPower reports a 0–1 fraction, not a percentage.
    readonly property int percent: root.available ? Math.round(root.device.percentage * 100) : 0

    readonly property int state: root.available ? root.device.state : UPowerDeviceState.Unknown
    readonly property bool charging: root.state === UPowerDeviceState.Charging
    readonly property bool full: root.state === UPowerDeviceState.FullyCharged
    readonly property bool low: root.available && !root.charging && !root.full && root.percent <= 20

    // Listed rather than computed: the Material Design battery glyphs are not
    // contiguous. Empty is U+F008E, the nine partial levels U+F007A–U+F0082,
    // and full U+F0079, before them.
    readonly property var levelIcons: [
        "󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"
    ]

    // Fixed indicator hues rather than the palette, so a colour means the same
    // charge level whatever the wallpaper.
    readonly property color tint: {
        if (!root.available)
            return Theme.indicatorDim
        if (root.charging || root.full)
            return Theme.indicatorGood
        if (root.percent <= 15)
            return Theme.indicatorBad
        if (root.percent <= 35)
            return Theme.indicatorWarn
        return Theme.indicatorGood
    }

    // Seconds; 0 while UPower has no estimate, typically for a minute or two
    // after the charger is plugged or unplugged.
    readonly property int secondsToEmpty: root.available ? root.device.timeToEmpty : 0
    readonly property int secondsToFull: root.available ? root.device.timeToFull : 0

    // Empty rather than "0 min" when there is no estimate.
    readonly property string estimate: {
        if (!root.available)
            return ""
        if (root.full)
            return Tr.t("Fully charged")
        const seconds = root.charging ? root.secondsToFull : root.secondsToEmpty
        if (seconds <= 0)
            return root.charging ? Tr.t("Charging") : ""
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.round((seconds % 3600) / 60)
        const span = hours > 0 ? `${hours} h ${minutes} min` : `${minutes} min`
        return root.charging ? Tr.t("%1 to full").arg(span) : Tr.t("%1 left").arg(span)
    }

    // ── DETAILS ─────────────────────────────────────────────────────────────
    //
    // Extra fields for the detail card, from the same UPower device.

    // Watts, unsigned; the direction is in `stateWord`.
    readonly property real watts: root.available ? Math.abs(root.device.changeRate) : 0

    // Wh in the cell right now, and what it held when it was new.
    readonly property real energy: root.available ? root.device.energy : 0
    readonly property real energyCapacity: root.available ? root.device.energyCapacity : 0

    // Remaining capacity versus design, only when the battery reports it.
    readonly property bool healthKnown: root.available && root.device.healthSupported
    readonly property int health: root.healthKnown
        ? Math.round(root.device.healthPercentage) : 0

    readonly property string stateWord: {
        if (!root.available)
            return ""
        if (root.full)
            return Tr.t("Full")
        if (root.charging)
            return Tr.t("Charging")
        return Tr.t("On battery")
    }

    readonly property string icon: {
        if (!root.available)
            return "󰂑"
        if (root.charging)
            return "󰂄"
        if (root.low)
            return "󰂃"
        const step = Math.max(0, Math.min(10, Math.round(root.percent / 10)))
        return root.levelIcons[step]
    }
}
