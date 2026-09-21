// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P A D L O C K                                                          │
// │   the island's glyph · a shackle that lifts and swings open              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "."

// The shell's padlock, drawn to the same numbers: the shackle lifts and
// swings out on its left leg, with a little overshoot.
Item {
    id: root

    property bool opened: false
    property color tint: Theme.text

    property real lift: root.opened ? 1 : 0

    Behavior on lift {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Easing.OutBack }
    }

    implicitWidth: 20
    implicitHeight: 24

    Shape {
        width: 20
        height: 24
        preferredRendererType: Shape.CurveRenderer

        transform: [
            Translate { y: -4 * root.lift },
            Rotation { origin.x: 5.2; origin.y: 12; angle: -14 * root.lift }
        ]

        ShapePath {
            strokeWidth: 2.6
            strokeColor: root.tint
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            startX: 5.2
            startY: 12
            PathLine { x: 5.2; y: 8 }
            PathArc { x: 14.8; y: 8; radiusX: 4.8; radiusY: 4.8 }
            PathLine { x: 14.8; y: 12 }
        }
    }

    Rectangle {
        x: 1
        y: 11
        width: 18
        height: 13
        radius: 4
        color: root.tint
    }
}
