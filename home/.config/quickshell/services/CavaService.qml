// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A V A   S E R V I C E                                                │
// │   audio spectrum from cava                                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Audio spectrum of the output stream, from cava. Runs only while something
// is subscribed.
Singleton {
    id: root

    // Lows first, as cava sends them. The edges draw every band.
    readonly property int bandCount: 64
    property var bands: new Array(root.bandCount).fill(0)

    // The highest each band has been lately, falling `peakFall` a frame: about
    // a second from the top, so a peak is down before cava goes to sleep.
    readonly property real peakFall: 0.035
    property var peaks: new Array(root.bandCount).fill(0)

    // The island's eight: four groups of bands, mirrored so the lows meet in
    // the middle.
    readonly property int barCount: 8
    readonly property var values: {
        const half = root.barCount / 2
        const size = root.bandCount / half
        const groups = []
        for (let group = 0; group < half; group++) {
            let total = 0
            for (let index = 0; index < size; index++)
                total += root.bands[group * size + index]
            groups.push(total / size)
        }
        return groups.slice().reverse().concat(groups)
    }

    property int watchers: 0

    readonly property bool active: root.watchers > 0

    // Mean of the bars as a single level, for the player's ring chip. Raised
    // to 0.55 because cava reports linear amplitude and loudness is perceived
    // roughly logarithmically.
    readonly property real level: {
        if (root.values.length === 0)
            return 0
        let total = 0
        for (const value of root.values)
            total += Math.max(0, value)
        return Math.pow(total / root.values.length, 0.55)
    }

    readonly property Process process: Process {
        command: ["cava", "-p", Quickshell.shellPath("scripts/cava.conf")]
        running: root.active

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.parse(line)
        }
    }

    function parse(line: string): void {
        const fields = line.split(";")
        const next = []
        for (let index = 0; index < root.bandCount; index++) {
            const value = Number(fields[index])
            next.push(Number.isFinite(value) ? Math.max(0, Math.min(1, value / 100)) : 0)
        }
        const fallen = next.map((value, index) =>
            Math.max(value, root.peaks[index] - root.peakFall, 0))
        // Silence is the same line thirty times a second; once the peaks are
        // down, nothing downstream needs to hear it again.
        if (next.every((value, index) => value === root.bands[index])
                && fallen.every((value, index) => value === root.peaks[index]))
            return
        root.bands = next
        root.peaks = fallen
    }

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
        if (root.watchers === 0) {
            root.bands = new Array(root.bandCount).fill(0)
            root.peaks = new Array(root.bandCount).fill(0)
        }
    }
}
