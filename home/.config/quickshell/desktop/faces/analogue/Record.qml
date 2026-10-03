// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   R   E   C   O   R   D                                                  │
// │   what is playing, as a record · it turns while it plays                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell.Widgets

import "../../../theme"
import "../../../services"

// A record on a turntable: a grooved disc, the artwork on the label, the
// spindle, and a tonearm that is down while playing and lifted otherwise. The
// disc spins during playback and stops where it is.
//
// Always the island's black, whatever the palette.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property real size: 130
    property bool playing: false
    property string art: ""

    readonly property real r: root.size * 0.42
    readonly property real cx: root.size * 0.46
    readonly property real cy: root.size * 0.52

    width: root.size
    height: root.size

    Item {
        id: disc

        x: root.cx - root.r
        y: root.cy - root.r
        width: 2 * root.r
        height: 2 * root.r

        Rectangle {
            anchors.fill: parent
            radius: root.r
            color: Theme.island
            border.color: root.ink.dim
            border.width: 1
        }

        Repeater {
            model: 7

            Rectangle {
                required property int index

                anchors.centerIn: parent
                width: 2 * (root.r * 0.45 + index * root.r * 0.5 / 7)
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(root.ink.text.r, root.ink.text.g, root.ink.text.b, 0.09)
                border.width: 1
            }
        }

        ClippingRectangle {
            anchors.centerIn: parent
            width: root.r * 0.72
            height: width
            radius: width / 2
            color: root.ink.accent

            Image {
                anchors.fill: parent
                source: root.art
                visible: root.art !== "" && status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 120
                sourceSize.height: 120
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 6
            height: 6
            radius: 3
            color: Theme.island
        }

        // 33⅓ rpm. A RotationAnimator runs on the render thread, and only while
        // the widget is visible.
        RotationAnimator on rotation {
            running: root.playing && root.visible && Theme.lively
            from: 0
            to: 360
            duration: 1800
            loops: Animation.Infinite
        }
    }

    Item {
        id: arm

        x: root.size * 0.9
        y: root.size * 0.1
        transformOrigin: Item.TopLeft
        rotation: root.playing ? 32 : 10

        Behavior on rotation { NumberAnimation { duration: Theme.durationMedium * 2 } }

        Rectangle {
            x: -2
            y: 0
            width: 4
            height: root.size * 0.5
            radius: 2
            color: root.ink.text
        }

        Rectangle {
            x: -6
            y: root.size * 0.5 - 4
            width: 12
            height: 16
            radius: 3
            color: root.ink.text
        }

        Rectangle {
            x: -7
            y: -7
            width: 14
            height: 14
            radius: 7
            color: root.ink.raised
            border.color: root.ink.muted
            border.width: 2
        }
    }
}
