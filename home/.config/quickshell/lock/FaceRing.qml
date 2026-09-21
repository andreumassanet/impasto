// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F A C E   R I N G                                                      │
// │   the lock's face unlock · the scan around the padlock                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// A ring of ticks while the camera looks: a bright head circles it with a
// tail behind. A match lets the tail run all the way round; the colour is
// the island's to choose.
Item {
    id: root

    // Across the inside of the ring.
    property real diameter: 72

    property bool scanning: false
    property bool closed: false
    property color hue: Theme.text

    // 0 hidden, 1 drawn: the ticks grow out from the ring as it appears.
    property real shown: 0

    readonly property real tick: 7
    readonly property int count: 48

    // The share of a turn the tail covers behind the head.
    readonly property real tail: 0.42

    // Where the head is, in turns clockwise from the top.
    property real head: 0

    // How much of the ring behind the head is lit whole, 0 to 1.
    property real fill: 0

    width: root.diameter + 2 * root.tick
    height: width
    visible: root.shown > 0
    opacity: root.shown

    Behavior on hue { ColorAnimation { duration: Theme.durationFast } }

    // One turn a second, which reads as looking rather than as waiting.
    NumberAnimation on head {
        from: 0
        to: 1
        duration: 1000
        loops: Animation.Infinite
        running: root.scanning && !root.closed
    }

    NumberAnimation {
        id: close

        target: root
        property: "fill"
        from: 0
        to: 1
        duration: Theme.durationMorph
        easing.type: Easing.OutCubic
    }

    onClosedChanged: {
        if (root.closed) {
            close.restart()
        } else {
            close.stop()
            root.fill = 0
        }
    }

    Repeater {
        model: root.count

        Item {
            id: spoke

            required property int index

            // Turns behind the head, 0 at the head itself.
            readonly property real behind: (root.head - spoke.index / root.count + 1) % 1
            readonly property real glow: Math.max(
                0.2,
                root.scanning ? 1 - spoke.behind / root.tail : 0,
                spoke.behind <= root.fill ? 1 : 0)

            anchors.fill: parent
            rotation: spoke.index * 360 / root.count

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.tick * (1 - root.shown)
                width: 2.4
                height: root.tick * root.shown
                radius: width / 2
                color: root.hue
                opacity: spoke.glow
            }
        }
    }
}
