// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S Y S T E M   M O N I T O R   S E R V I C E                            │
// │   GPUs, CPU temperature, disks and per-interface network totals          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

// From end_4 illogical-impulse (services/SystemMonitor.qml). The readings of
// a system monitor: every GPU, the CPU's temperature and power
// (scripts/system_monitor.py), disks (same script, once per open), and
// per-interface network throughput and totals since boot (/proc/net/dev).
// Load and memory are StatsService's. Polls only while subscribed.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int watchers: 0
    readonly property bool active: root.watchers > 0
    readonly property int interval: 3000
    readonly property int historyLength: 60

    function subscribe(): void {
        root.watchers += 1
        if (root.watchers === 1)
            diskProcess.running = true
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // `{ vendor, name, usage (0-1 | null), vramUsedMiB, vramTotalMiB,
    //    freqMHz, maxFreqMHz, temp, power, history }`
    property var gpus: []
    property var gpuHistories: ({})

    property real cpuTemp: 0
    property real cpuPower: -1          // W; -1 when RAPL is unreadable
    readonly property bool cpuPowerAvailable: root.cpuPower >= 0

    // `{ mount, total, used }` in bytes
    property var disks: []

    // Rates in bytes/s, totals in bytes since boot.
    property real ethRx: 0
    property real ethTx: 0
    property real wifiRx: 0
    property real wifiTx: 0
    property real ethRxTotal: 0
    property real ethTxTotal: 0
    property real wifiRxTotal: 0
    property real wifiTxTotal: 0
    property var downHistory: []
    property var upHistory: []
    property real peakRate: 1024 * 1024
    property var previousNet: null
    property var previousHardware: null

    function push(list: var, value: real): var {
        const next = list.concat([value])
        return next.length > root.historyLength ? next.slice(next.length - root.historyLength) : next
    }

    function formatBytes(bytes: real, perSecond = false): string {
        const units = perSecond ? ["B/s", "KB/s", "MB/s", "GB/s"] : ["B", "KB", "MB", "GB", "TB"]
        let value = bytes
        let index = 0
        while (value >= 1024 && index < units.length - 1) {
            value /= 1024
            index++
        }
        return `${value >= 100 || index === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[index]}`
    }

    function formatRate(bytesPerSecond: real): string {
        return root.formatBytes(bytesPerSecond, true)
    }

    // `{ name, address }` per interface with a global IPv4 address, read at
    // start and whenever the connection changes, so a card that lists them is
    // sized before it opens. Container and virtual interfaces are left out.
    property var addresses: []

    function refreshAddresses(): void {
        addressProcess.running = true
    }

    Component.onCompleted: root.refreshAddresses()

    Connections {
        target: NetworkService

        function onConnectionNameChanged(): void {
            root.refreshAddresses()
        }
    }

    Process {
        id: addressProcess

        command: ["ip", "-4", "-o", "addr", "show", "scope", "global"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.addresses = text.trim().split("\n").filter(line => line !== "").map(line => {
                    const fields = line.trim().split(/\s+/)
                    return { name: fields[1], address: fields[3] }
                }).filter(entry => !/^(docker|br-|veth)/.test(entry.name))
            }
        }
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            if (!hardwareProcess.running)
                hardwareProcess.running = true
            netFile.reload()
            root.parseNet(netFile.text())
        }
    }

    Process {
        id: hardwareProcess

        command: ["python3", "-I", Quickshell.shellPath("scripts/system_monitor.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyHardware(JSON.parse(text))
                } catch (error) {
                    console.warn("System monitor: cannot read the hardware report:", error)
                }
            }
        }
    }

    Process {
        id: diskProcess

        command: ["python3", "-I", Quickshell.shellPath("scripts/system_monitor.py"), "disks"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.disks = JSON.parse(text).disks ?? []
                } catch (error) {
                    console.warn("System monitor: cannot read the disk report:", error)
                }
            }
        }
    }

    function applyHardware(report: var): void {
        const previous = root.previousHardware
        const elapsed = previous ? report.time - previous.time : 0
        const histories = Object.assign({}, root.gpuHistories)

        // RAPL watts for one domain, from the energy delta.
        const watts = name => {
            const now = report.rapl?.[name]
            const before = previous?.rapl?.[name]
            if (!now || !before || elapsed <= 0)
                return null
            let delta = now.uj - before.uj
            if (delta < 0 && now.max)
                delta += now.max
            return delta / 1e6 / (elapsed / 1000)
        }

        root.gpus = report.gpus.map((gpu, index) => {
            const out = Object.assign({}, gpu)
            if (gpu.vendor === "intel") {
                const before = previous?.gpus?.[index]
                out.usage = before && gpu.rc6Ms !== null && before.rc6Ms !== null && elapsed > 0
                    ? Math.max(0, Math.min(1, 1 - (gpu.rc6Ms - before.rc6Ms) / elapsed)) : null
                // No temperature sensor for i915.
                out.temp = null
                out.power = watts("uncore")
            }
            const key = `${index}:${gpu.name}`
            histories[key] = root.push(histories[key] ?? [], out.usage ?? 0)
            out.history = histories[key]
            return out
        })
        root.gpuHistories = histories
        root.cpuTemp = report.cpuTemp ?? 0
        const packagePower = watts("package-0")
        root.cpuPower = packagePower === null ? -1 : packagePower
        root.previousHardware = report
    }

    FileView {
        id: netFile

        path: "/proc/net/dev"
    }

    function parseNet(content: string): void {
        const now = Date.now()
        const totals = { ethernet: [0, 0], wifi: [0, 0] }
        for (const line of content.split("\n")) {
            const match = line.match(/^\s*([^:\s]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/)
            if (!match)
                continue
            const kind = /^(en|eth)/.test(match[1]) ? "ethernet" : /^wl/.test(match[1]) ? "wifi" : null
            if (!kind)
                continue
            totals[kind][0] += Number(match[2])
            totals[kind][1] += Number(match[3])
        }
        root.ethRxTotal = totals.ethernet[0]
        root.ethTxTotal = totals.ethernet[1]
        root.wifiRxTotal = totals.wifi[0]
        root.wifiTxTotal = totals.wifi[1]

        const previous = root.previousNet
        root.previousNet = { at: now, totals: totals }
        if (!previous)
            return
        const seconds = (now - previous.at) / 1000
        if (seconds <= 0)
            return
        const rate = (kind, index) => Math.max(0, (totals[kind][index] - previous.totals[kind][index]) / seconds)
        root.ethRx = rate("ethernet", 0)
        root.ethTx = rate("ethernet", 1)
        root.wifiRx = rate("wifi", 0)
        root.wifiTx = rate("wifi", 1)
        const down = root.ethRx + root.wifiRx
        const up = root.ethTx + root.wifiTx
        // Graphs follow a slowly decaying peak, so idle traffic stays flat.
        root.peakRate = Math.max(1024 * 1024, root.peakRate * 0.98, down, up)
        root.downHistory = root.push(root.downHistory, down / root.peakRate)
        root.upHistory = root.push(root.upHistory, up / root.peakRate)
    }
}
