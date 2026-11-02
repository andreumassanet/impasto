// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L U E T O O T H   S E R V I C E                                      │
// │   adapter state and what is connected to it                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

import "../theme"

// The default adapter, flattened for the control centre.
//
// `enabled` on the adapter is writable, so nothing shells out here: the toggle
// is a property assignment and the state comes back over D-Bus.
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: root.adapter !== null
    readonly property bool enabled: root.available && root.adapter.enabled

    // Everything BlueZ currently knows about, listed or not.
    readonly property var allDevices: {
        if (!root.available || !root.adapter.devices)
            return []
        return root.adapter.devices.values
    }

    readonly property var connectedDevices: root.allDevices.filter(device => device.connected)

    // A single device is named; several are counted.
    readonly property string summary: {
        if (!root.available)
            return Tr.t("Unavailable")
        if (!root.enabled)
            return Tr.t("Off")
        const connected = root.connectedDevices
        if (connected.length === 0)
            return Tr.t("No devices")
        if (connected.length === 1)
            return connected[0].name
        return Tr.t("%1 devices").arg(connected.length)
    }

    readonly property string icon: {
        if (!root.available)
            return "󰂲"
        if (!root.enabled)
            return "󰂲"
        return root.connectedDevices.length > 0 ? "󰂱" : "󰂯"
    }

    // `name` is BlueZ's Alias, which falls back to the MAC address when the
    // device never advertised a name; `deviceName` is empty in that case.
    function isNamed(device: var): bool {
        return ((device.deviceName ?? "") + "").length > 0
    }

    // Named, paired, connected or pairing devices. Paired devices stay listed
    // whatever BlueZ has cached for their name.
    readonly property var devices: {
        const listed = root.allDevices.filter(device => root.isNamed(device)
            || device.paired || device.connected || device.pairing)
        // Connected first, then paired, then whatever else is in range.
        return listed.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired) return a.paired ? -1 : 1
            return (a.name ?? "").localeCompare(b.name ?? "")
        })
    }

    // Everything else, shown in a collapsed second list.
    readonly property var unnamedDevices: {
        const rest = root.allDevices.filter(device => !(root.isNamed(device)
            || device.paired || device.connected || device.pairing))
        return rest.sort((a, b) => (a.address ?? "").localeCompare(b.address ?? ""))
    }

    readonly property int unnamedCount: root.unnamedDevices.length

    readonly property bool discovering: root.available && root.adapter.discovering

    function deviceIcon(device: var): string {
        switch (device.icon) {
        case "audio-headset":
        case "audio-headphones": return "󰋋"
        case "audio-card": return "󰓃"
        case "input-mouse": return "󰍽"
        case "input-keyboard": return "󰌌"
        case "phone": return "󰄜"
        case "computer": return "󰟀"
        default: return "󰂯"
        }
    }

    // `connected` is writable on the device.
    function connectDevice(device: var): void {
        if (device)
            device.connected = !device.connected
    }

    function setDiscovering(on: bool): void {
        if (root.available)
            root.adapter.discovering = on
    }

    function toggle(): void {
        if (root.available)
            root.adapter.enabled = !root.adapter.enabled
    }
}
