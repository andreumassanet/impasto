// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   E G G                                                          │
// │   the egg, drawn soft · a speckled shell in its future colour            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../../theme"

// The shell before there is a creature: an ovoid lit from above, speckled in
// the coat the species inside will wear. Shared by the two shaded styles.
Item {
    id: root

    property real size: 40
    property color coat: Theme.accent

    readonly property real s: root.size
    readonly property color shell: Theme.indicator

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: root.s * 0.06
                x2: 0; y2: root.s * 0.97

                GradientStop { position: 0.0; color: root.shell }
                GradientStop { position: 0.6; color: Qt.darker(root.shell, 1.08) }
                GradientStop { position: 1.0; color: Qt.darker(root.shell, 1.26) }
            }

            startX: root.s * 0.5
            startY: root.s * 0.06

            PathCubic {
                control1X: root.s * 0.74; control1Y: root.s * 0.20
                control2X: root.s * 0.84; control2Y: root.s * 0.50
                x: root.s * 0.84;         y: root.s * 0.66
            }
            PathCubic {
                control1X: root.s * 0.84; control1Y: root.s * 0.86
                control2X: root.s * 0.70; control2Y: root.s * 0.97
                x: root.s * 0.5;          y: root.s * 0.97
            }
            PathCubic {
                control1X: root.s * 0.30; control1Y: root.s * 0.97
                control2X: root.s * 0.16; control2Y: root.s * 0.86
                x: root.s * 0.16;         y: root.s * 0.66
            }
            PathCubic {
                control1X: root.s * 0.16; control1Y: root.s * 0.50
                control2X: root.s * 0.26; control2Y: root.s * 0.20
                x: root.s * 0.5;          y: root.s * 0.06
            }
        }
    }

    Repeater {
        model: [
            { x: 0.30, y: 0.34, r: 0.09 },
            { x: 0.58, y: 0.26, r: 0.06 },
            { x: 0.62, y: 0.52, r: 0.10 },
            { x: 0.34, y: 0.66, r: 0.07 },
            { x: 0.50, y: 0.80, r: 0.05 }
        ]

        Rectangle {
            required property var modelData

            x: root.s * modelData.x
            y: root.s * modelData.y
            width: root.s * modelData.r
            height: width
            radius: width / 2
            opacity: 0.85
            color: root.coat
        }
    }

    Rectangle {
        x: root.s * 0.28
        y: root.s * 0.18
        width: root.s * 0.16
        height: root.s * 0.07
        radius: height / 2
        rotation: -34
        opacity: 0.9
        color: root.shell
    }
}
