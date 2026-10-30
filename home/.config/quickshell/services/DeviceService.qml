// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D E V I C E   S E R V I C E                                            │
// │   batteries of connected devices · mice, keyboards, headsets, pads       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// The batteries of what is connected to the machine, as
// `{ name, glyph, level, charging }` with `level` from 0 to 1. Two sources:
// BlueZ through `BluetoothService` (earbuds, Bluetooth mice) and UPower (mice
// and keyboards on a receiver, some headsets). A device both report appears
// once, by name. The laptop's own battery is the battery module's.
Singleton {
    id: root

    // Nerd Font glyphs, by what the device says it is.
    function glyphFor(kind: string): string {
        if (/mouse/i.test(kind)) return "󰍽"
        if (/keyboard/i.test(kind)) return "󰌌"
        if (/head|ear|audio|buds/i.test(kind)) return "󰋋"
        if (/phone/i.test(kind)) return "󰄜"
        if (/gaming|joystick|controller/i.test(kind)) return "󰊴"
        if (/pen|tablet/i.test(kind)) return "󰏪"
        return "󰂯"
    }

    readonly property var bluetoothDevices: BluetoothService.connectedDevices
        .filter(device => device.batteryAvailable)
        .map(device => ({
            name: device.name,
            glyph: root.glyphFor((device.icon ?? "") + " " + device.name),
            level: device.battery,
            charging: false
        }))

    readonly property var upowerDevices: UPower.devices.values
        .filter(device => device.isPresent && !device.isLaptopBattery
            && device.type !== UPowerDeviceType.LinePower
            && device.type !== UPowerDeviceType.Battery && device.percentage > 0)
        .map(device => ({
            name: device.model || "Device",
            glyph: root.glyphFor((device.iconName ?? "") + " " + (device.model ?? "")),
            level: device.percentage,
            charging: device.state === UPowerDeviceState.Charging
        }))

    // Bluetooth first: it names the device the way the user paired it.
    readonly property var devices: {
        const all = [...root.bluetoothDevices]
        // A UPower device is dropped only for a Bluetooth one of the same name:
        // two of the same model (a pair of pads) are two devices.
        for (const device of root.upowerDevices)
            if (!root.bluetoothDevices.some(other => other.name.toLowerCase() === device.name.toLowerCase()))
                all.push(device)
        return all
    }
}
