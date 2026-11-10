// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N E T W O R K   S E R V I C E                                          │
// │   what we are connected to, and the wifi radio                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

import "../theme"

// Connection state read from NetworkManager through Quickshell's own module,
// so the tile can name the network instead of only saying "on".
//
// The radio switch still goes through nmcli: the module exposes the devices
// but not a writable toggle for the radio itself.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values

    readonly property NetworkDevice wifiDevice:
        root.devices.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property NetworkDevice wiredDevice:
        root.devices.find(device => device.type === DeviceType.Ethernet) ?? null

    readonly property bool wifiEnabled: root.radioOn
    readonly property bool wifiConnected: root.wifiDevice !== null && root.wifiDevice.connected
    readonly property bool wiredConnected: root.wiredDevice !== null && root.wiredDevice.connected

    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full

    // The name of whatever is actually carrying traffic. A cable outranks
    // wifi, which is the order NetworkManager routes them in anyway.
    readonly property string connectionName: {
        if (root.wiredConnected)
            return Tr.t("Wired")
        if (root.wifiConnected && root.wifiDevice.networks) {
            const active = root.wifiDevice.networks.values.find(network => network.connected)
            if (active)
                return active.name
        }
        if (!root.radioOn)
            return Tr.t("Off")
        return root.wifiDevice ? Tr.t("Not connected") : Tr.t("Unavailable")
    }

    // Signal of the connected Wi-Fi network, 0–1. Zero on a cable or offline.
    readonly property real strength: {
        if (!root.wifiConnected || !root.wifiDevice.networks)
            return 0
        const active = root.wifiDevice.networks.values.find(network => network.connected)
        if (!active)
            return 0
        const raw = active.signalStrength ?? 0
        return raw > 1 ? raw / 100 : raw
    }

    // Link type and state, shown under `connectionName`, so it never repeats
    // it. Shared by the bar detail and the desktop widget.
    readonly property string stateLine: {
        if (root.wiredConnected)
            return root.online ? Tr.t("Ethernet · online") : Tr.t("Ethernet · no internet")
        if (root.wifiConnected)
            return root.online ? Tr.t("Wi-Fi · online") : Tr.t("Wi-Fi · no internet")
        if (!root.wifiEnabled)
            return Tr.t("Wi-Fi radio off")
        return root.online ? Tr.t("Online") : Tr.t("Nothing reaches the internet")
    }

    readonly property string icon: {
        if (root.wiredConnected)
            return "󰈁"
        if (!root.radioOn)
            return "󰤮"
        return root.wifiConnected ? "󰤨" : "󰤯"
    }

    property bool radioOn: false

    // `-t -f`: nmcli's table output is localised ("activado") and its column
    // order is unreliable.
    readonly property Process radioQuery: Process {
        command: ["nmcli", "-t", "-f", "WIFI", "radio", "all"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.radioOn = text.trim() === "enabled"
        }
    }

    readonly property Process radioToggle: Process {
        onExited: {
            root.radioQuery.running = true
            // The card has nothing to report for a moment after power-up.
            root.settleTimer.restart()
        }
    }

    // Rescan whenever the radio comes up, whoever turned it on.
    onRadioOnChanged: {
        if (root.radioOn)
            root.settleTimer.restart()
        else
            root.networks = []
    }

    readonly property Timer settleTimer: Timer {
        interval: 1200
        onTriggered: root.scan(false)
    }

    function refresh(): void {
        root.radioQuery.running = true
    }

    function toggleWifi(): void {
        root.radioToggle.command = ["nmcli", "radio", "wifi", root.radioOn ? "off" : "on"]
        root.radioToggle.running = true
    }

    // ── SCANNING AND CONNECTING ─────────────────────────────────────────────

    property var networks: []
    property bool scanning: false
    property string busySsid: ""

    readonly property string script: Quickshell.shellPath("scripts/network.py")

    function strengthIcon(signal: int): string {
        if (signal >= 75) return "󰤨"
        if (signal >= 50) return "󰤥"
        if (signal >= 25) return "󰤢"
        return "󰤟"
    }

    readonly property Process listProcess: Process {
        onExited: root.scanning = false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    root.networks = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the network list:", error)
                }
            }
        }
    }

    readonly property Process connectProcess: Process {
        onExited: {
            root.busySsid = ""
            root.refresh()
            root.scan(false)
        }
    }

    // `rescan` makes the card sweep the band (seconds); `list` returns what it
    // already knows.
    function scan(rescan = false): void {
        // Not gated on radioOn, which may not have been read yet. With the
        // radio off nmcli just returns an empty list.
        root.scanning = true
        root.listProcess.command = [root.script, rescan ? "rescan" : "list"]
        root.listProcess.running = true
    }

    function connect(ssid: string, password = ""): void {
        root.busySsid = ssid
        root.connectProcess.command = password === ""
            ? [root.script, "connect", ssid]
            : [root.script, "connect", ssid, password]
        root.connectProcess.running = true
    }

    function disconnect(ssid: string): void {
        root.busySsid = ssid
        root.connectProcess.command = [root.script, "disconnect", ssid]
        root.connectProcess.running = true
    }

    function forget(ssid: string): void {
        root.busySsid = ssid
        root.connectProcess.command = [root.script, "forget", ssid]
        root.connectProcess.running = true
    }

    function setWifi(on: bool): void {
        root.radioToggle.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        root.radioToggle.running = true
    }
}
