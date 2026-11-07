// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O V E R   R I N G                                                    │
// │   bars of the audio spectrum around a round cover                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell.Io

import "../theme"
import "../services"

// Drawn around the middle of this item, outside a circle of `innerRadius`
// and growing out to `reach` past it; the parent leaves room for the bars.
// Listens to cava only while `active` and cava is installed. Without cava
// it draws nothing and says nothing; `shown` tells the parent which.
Item {
    id: root

    property bool active: false
    property real innerRadius: 32
    property real reach: 8
    property real barWidth: 2

    // cava reports linear amplitude; a fractional power keeps quiet passages
    // visible.
    property real curve: 0.55

    // Whether cava is on the PATH, asked once the ring is first wanted.
    property bool found: false
    property bool probed: false
    readonly property bool shown: root.active && root.found

    // Held while listening, so every subscribe is paired with a release.
    property bool listening: false

    visible: root.shown

    readonly property Process probe: Process {
        command: ["sh", "-c", "command -v cava >/dev/null"]
        running: root.active && !root.probed
        onExited: code => {
            root.found = code === 0
            root.probed = true
        }
    }

    onShownChanged: root.sync()
    Component.onCompleted: root.sync()
    Component.onDestruction: {
        if (root.listening)
            CavaService.release()
    }

    function sync(): void {
        if (root.shown === root.listening)
            return
        root.listening = root.shown
        if (root.listening)
            CavaService.subscribe()
        else
            CavaService.release()
    }

    // One bar a band, lows at the top and clockwise.
    Repeater {
        model: root.shown ? CavaService.bandCount : 0

        Rectangle {
            id: bar

            required property int index

            readonly property real level: Math.pow(Math.max(0, CavaService.bands[bar.index] ?? 0), root.curve)

            x: root.width / 2 - bar.width / 2
            y: root.height / 2 - root.innerRadius - bar.height
            width: root.barWidth
            height: root.barWidth + bar.level * root.reach
            radius: bar.width / 2
            color: Theme.accent
            opacity: 0.45 + bar.level * 0.55
            transform: Rotation {
                origin.x: bar.width / 2
                origin.y: root.innerRadius + bar.height
                angle: bar.index * 360 / CavaService.bandCount
            }
        }
    }
}
