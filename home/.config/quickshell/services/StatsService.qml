// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S T A T S   S E R V I C E                                              │
// │   machine load, and enough history to draw it                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Machine load, with a short history per rate that is recorded all the time
// so the graphs already have data when a panel opens.
//
// `stats.py` stays resident and prints one JSON line per interval, re-reading
// mounts and sensors only every tenth tick; a sample costs about 2 ms.
Singleton {
    id: root

    // 100 samples at 3 s: five minutes. One rate for every series keeps the
    // time axis uniform.
    readonly property int pollInterval: 3000
    readonly property int historyLength: 100

    property bool ready: false

    property real cpu: 0
    property var cores: []
    property string cpuModel: ""
    property var load: [0, 0, 0]

    property real memoryUsed: 0
    property real memoryTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0

    property var disks: []
    property real networkDown: 0
    property real networkUp: 0
    property var temperature: null
    property int uptime: 0

    property var cpuHistory: []
    property var memoryHistory: []
    property var downHistory: []
    property var upHistory: []
    property var temperatureHistory: []

    readonly property real memoryFraction:
        root.memoryTotal > 0 ? root.memoryUsed / root.memoryTotal : 0
    readonly property string window: Tr.t("last %1 min").arg(Math.round(root.historyLength * root.pollInterval / 1000 / 60))

    readonly property string thermalWord: {
        if (!root.temperature)
            return ""
        const celsius = root.temperature.celsius
        if (celsius < 45) return Tr.t("Cool")
        if (celsius < 65) return Tr.t("Warm")
        if (celsius < 85) return Tr.t("Hot")
        return Tr.t("Very hot")
    }

    readonly property real swapFraction:
        root.swapTotal > 0 ? root.swapUsed / root.swapTotal : 0

    // SplitParser, not StdioCollector: this stream never ends.
    readonly property Process sampler: Process {
        id: sampler

        command: [Quickshell.shellPath("scripts/stats.py"), "watch",
                  `${root.pollInterval / 1000}`]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.ingest(line)
        }

        // Restart after a delay, so a script that fails immediately is not
        // respawned in a tight loop.
        onExited: revive.start()
    }

    readonly property Timer revive: Timer {
        interval: 5000
        onTriggered: sampler.running = true
    }

    function push(series: var, value: real): var {
        const next = series.concat([value])
        return next.length > root.historyLength
            ? next.slice(next.length - root.historyLength)
            : next
    }

    function ingest(text: string): void {
        if (!text || text.trim() === "")
            return
        let data
        try {
            data = JSON.parse(text)
        } catch (error) {
            console.warn("Cannot parse the machine stats:", error)
            return
        }
        if (!data.cpu)
            return

        root.cpu = data.cpu.total
        root.cores = data.cpu.cores ?? []
        root.cpuModel = data.cpu.model ?? ""
        root.load = data.cpu.load ?? [0, 0, 0]

        root.memoryUsed = data.memory.used
        root.memoryTotal = data.memory.total
        root.swapUsed = data.memory.swapUsed
        root.swapTotal = data.memory.swapTotal

        root.disks = data.disks ?? []
        root.networkDown = data.network.down
        root.networkUp = data.network.up
        root.temperature = data.temperature
        root.uptime = data.uptime

        root.cpuHistory = root.push(root.cpuHistory, root.cpu / 100)
        root.memoryHistory = root.push(root.memoryHistory, root.memoryFraction)
        root.downHistory = root.push(root.downHistory, root.networkDown)
        root.upHistory = root.push(root.upHistory, root.networkUp)
        if (root.temperature)
            root.temperatureHistory = root.push(root.temperatureHistory, root.temperature.celsius)

        root.ready = true
    }

    // ── FORMATTING ──────────────────────────────────────────────────────────

    readonly property var byteUnits: ["B", "KiB", "MiB", "GiB", "TiB"]

    function bytes(value: real, decimals = 1): string {
        let amount = Math.max(0, value)
        let unit = 0
        while (amount >= 1024 && unit < root.byteUnits.length - 1) {
            amount /= 1024
            unit += 1
        }
        return `${amount.toFixed(unit === 0 ? 0 : decimals)} ${root.byteUnits[unit]}`
    }

    function rate(value: real): string {
        return `${root.bytes(value, 0)}/s`
    }

    function duration(seconds: int): string {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        if (days > 0)
            return `${days}d ${hours}h`
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`
    }
}
