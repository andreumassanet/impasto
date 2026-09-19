// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B R I G H T N E S S   S E R V I C E                                    │
// │   brightness per screen · the backlight on sysfs, monitors over DDC/CI   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// One entry per screen. The laptop panel is the backlight, watched on sysfs
// so the OSD also reacts to the hardware keys, and set through brightnessctl.
// An external monitor is set over DDC/CI with ddcutil, on the I2C bus that
// `ddcutil detect` pairs with its connector. The keys and every single
// reading follow the focused screen, or the first one that can be dimmed.
Singleton {
    id: root

    // A level was set here, or the backlight moved on its own. A reading
    // taken off a monitor is not a change and does not emit it.
    signal adjusted(var display)

    readonly property var displays: root.variants.instances
    readonly property var dimmable: root.displays.filter(display => display.available)
    readonly property var current: {
        const focused = HyprlandService.focusedMonitor
        return root.dimmable.find(display => display.name === focused)
            ?? root.dimmable[0] ?? null
    }

    readonly property bool available: root.current !== null
    readonly property int percent: root.current?.percent ?? 0
    readonly property string icon: root.iconFor(root.percent)

    function iconFor(percent: int): string {
        if (percent < 34)
            return "󰃞"
        return percent < 67 ? "󰃟" : "󰃠"
    }

    function setPercent(value: int): void {
        root.current?.setPercent(value)
    }

    function step(delta: int): void {
        root.current?.step(delta)
    }

    // A monitor's own buttons change it without telling anyone, so whatever
    // shows the levels asks for them again when it opens.
    function refresh(): void {
        for (const display of root.displays)
            display.read()
    }

    function isPanel(name: string): bool {
        return /^(eDP|LVDS|DSI)-/.test(name)
    }


    // ── BACKLIGHT ───────────────────────────────────────────────────────────
    //
    // The device (intel_backlight, amdgpu_bl0, …) is discovered once.

    property string device: ""
    property int raw: 0
    property int maximum: 0

    readonly property int backlightPercent: root.maximum > 0
        ? Math.round(root.raw / root.maximum * 100) : 0

    onRawChanged: {
        const panel = root.displays.find(display => display.backlight)
        if (panel)
            root.adjusted(panel)
    }

    readonly property Process discovery: Process {
        command: ["sh", "-c", "ls -1 /sys/class/backlight/ 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim()
                if (name !== "")
                    root.device = name
            }
        }
    }

    readonly property FileView maxView: FileView {
        path: root.device === "" ? "" : `/sys/class/backlight/${root.device}/max_brightness`
        onLoaded: root.maximum = parseInt(text().trim()) || 0
    }

    readonly property FileView levelView: FileView {
        path: root.device === "" ? "" : `/sys/class/backlight/${root.device}/brightness`
        watchChanges: true
        onLoaded: root.raw = parseInt(text().trim()) || 0
        onFileChanged: reload()
    }


    // ── DDC ─────────────────────────────────────────────────────────────────
    //
    // Connector → I2C bus. A laptop panel never answers DDC, so a desk with
    // nothing else plugged in never runs ddcutil at all.

    property var buses: ({})

    readonly property bool external: Quickshell.screens.some(screen => !root.isPanel(screen.name))

    function detect(): void {
        if (!root.external) {
            root.buses = ({})
            return
        }
        if (root.detector.running) {
            root.redetect.restart()
            return
        }
        root.detector.running = true
    }

    // `--brief` prints one block per display, and only a "Display N" block
    // answered over DDC. Its connector is "card1-DP-1" where Hyprland says
    // "DP-1".
    function parse(text: string): var {
        const found = {}
        for (const block of text.split(/\n\s*\n/)) {
            if (!/^Display \d+/.test(block.trim()))
                continue
            const bus = block.match(/I2C bus:\s*\/dev\/i2c-(\d+)/)
            const connector = block.match(/DRM connector:\s*card\d+-(\S+)/)
            if (bus && connector)
                found[connector[1]] = bus[1]
        }
        return found
    }

    readonly property Process detector: Process {
        command: ["sh", "-c", "command -v ddcutil >/dev/null && exec ddcutil detect --brief"]
        stdout: StdioCollector {
            onStreamFinished: root.buses = root.parse(text)
        }
    }

    // Plugging a screen in changes the list more than once.
    readonly property Timer redetect: Timer {
        interval: 1500
        onTriggered: root.detect()
    }

    readonly property Connections hotplug: Connections {
        target: Quickshell
        function onScreensChanged(): void { root.redetect.restart() }
    }

    Component.onCompleted: root.detect()


    // ── SCREENS ─────────────────────────────────────────────────────────────

    readonly property Variants variants: Variants {
        model: Quickshell.screens

        QtObject {
            id: display

            required property ShellScreen modelData

            // Null for a moment when the screen is unplugged.
            readonly property string name: display.modelData?.name ?? ""
            readonly property bool panel: root.isPanel(display.name)
            readonly property string title: display.panel
                ? "Built-in" : (display.modelData?.model || display.name)
            readonly property string bus: display.panel ? "" : (root.buses[display.name] ?? "")

            // The panel's. A lone screen with no DDC bus keeps it too, which
            // is how a monitor driven by the ddcci kernel module shows up.
            readonly property bool backlight: root.maximum > 0
                && (display.panel || (display.bus === "" && Quickshell.screens.length === 1))

            // Over DDC: the last level read or asked for, the monitor's own
            // maximum, and whether the last reading came back at all.
            property int level: 0
            property int ceiling: 0
            property bool answering: false

            readonly property bool available: display.backlight
                || (display.bus !== "" && display.answering)
            readonly property int percent: display.backlight ? root.backlightPercent : display.level
            readonly property string icon: root.iconFor(display.percent)

            // Asked for and not yet written, or -1.
            property int wanted: -1
            property int written: -1

            function setPercent(value: int): void {
                if (!display.available)
                    return
                const clamped = Math.max(1, Math.min(100, value))
                if (clamped === (display.wanted >= 0 ? display.wanted : display.percent))
                    return
                display.wanted = clamped
                // The backlight reports itself through sysfs.
                if (!display.backlight) {
                    display.level = display.wanted
                    root.adjusted(display)
                }
                display.flush()
            }

            // From the level last asked for, so a held key does not step
            // from a reading that has not caught up. At either end it writes
            // nothing, and still shows where it stopped.
            function step(delta: int): void {
                const from = display.wanted >= 0 ? display.wanted : display.percent
                if (Math.max(1, Math.min(100, from + delta)) === from)
                    root.adjusted(display)
                else
                    display.setPercent(from + delta)
            }

            // One write at a time. A DDC write takes a tenth of a second or
            // more and a slider asks faster than that, so only the newest
            // level waits.
            function flush(): void {
                if (display.wanted < 0 || display.writer.running || display.reader.running)
                    return
                display.written = display.wanted
                display.writer.command = display.backlight
                    ? ["brightnessctl", "--quiet", "set", `${display.written}%`]
                    : ["ddcutil", "--bus", display.bus, "--noverify", "--skip-ddc-checks",
                       "setvcp", "10", `${Math.round(display.written / 100 * display.ceiling)}`]
                display.writer.running = true
            }

            function read(): void {
                if (display.bus === "" || display.reader.running || display.writer.running)
                    return
                display.reader.command = ["ddcutil", "--bus", display.bus, "--skip-ddc-checks",
                                          "getvcp", "10", "--brief"]
                display.reader.running = true
            }

            // A failed write is not retried: the monitor is read instead,
            // and one that does not answer that either drops out.
            readonly property Process writer: Process {
                onExited: code => {
                    if (display.wanted === display.written || (code !== 0 && !display.backlight))
                        display.wanted = -1
                    if (code !== 0 && !display.backlight)
                        Qt.callLater(display.read)
                    else
                        Qt.callLater(display.flush)
                }
            }

            // "VCP 10 C <level> <maximum>"
            readonly property Process reader: Process {
                stdout: StdioCollector {
                    onStreamFinished: {
                        const words = text.trim().split(/\s+/)
                        const level = parseInt(words[3])
                        const maximum = parseInt(words[4])
                        display.answering = words[0] === "VCP" && words[2] === "C"
                            && level >= 0 && maximum > 0
                        if (!display.answering)
                            return
                        display.ceiling = maximum
                        if (display.wanted < 0)
                            display.level = Math.round(level / maximum * 100)
                    }
                }
                onExited: Qt.callLater(display.flush)
            }

            onBusChanged: display.read()
            Component.onCompleted: display.read()
        }
    }
}
