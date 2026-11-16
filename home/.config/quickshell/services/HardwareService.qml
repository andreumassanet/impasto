// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   H A R D W A R E   S E R V I C E                                        │
// │   the GPUs and the processor's power                                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What `StatsService` does not read: every GPU and the processor's power,
// from `scripts/hardware.py` (adapted from end_4's illogical-impulse).
// Each reading is a script run, and waking a discrete GPU to ask is not free,
// so this polls only while something shows it.
Singleton {
    id: root

    readonly property int interval: 3000
    readonly property int historyLength: 60

    property int watchers: 0

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
        // The next sample after a gap has nothing to take a rate from: not the
        // last one before it, which could be hours old.
        if (root.watchers === 0)
            root.previous = null
    }

    // `{ vendor, name, usage (0-1 | null), vramUsedMiB, vramTotalMiB,
    //    freqMHz, maxFreqMHz, temp, power, history }`
    property var gpus: []
    property var gpuHistories: ({})

    property real cpuPower: -1          // W; -1 when RAPL is unreadable
    readonly property bool cpuPowerAvailable: root.cpuPower >= 0

    property var previous: null

    function push(list: var, value: real): var {
        const next = list.concat([value])
        return next.length > root.historyLength ? next.slice(next.length - root.historyLength) : next
    }

    readonly property Timer poller: Timer {
        interval: root.interval
        repeat: true
        running: root.watchers > 0
        triggeredOnStart: true
        onTriggered: {
            if (!reader.running)
                reader.running = true
        }
    }

    readonly property Process reader: Process {
        id: reader

        command: ["python3", "-I", Quickshell.shellPath("scripts/hardware.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apply(JSON.parse(text))
                } catch (error) {
                    console.warn("Hardware: cannot read the report:", error)
                }
            }
        }
    }

    function apply(report: var): void {
        // Nobody is watching any more: the run that was under way is stale.
        if (root.watchers === 0)
            return
        const previous = root.previous
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
        const packagePower = watts("package-0")
        root.cpuPower = packagePower === null ? -1 : packagePower
        root.previous = report
    }
}
