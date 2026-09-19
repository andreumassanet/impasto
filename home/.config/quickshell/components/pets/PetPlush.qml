// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   P L U S H                                                      │
// │   the pet drawn soft · one round body, shaded, with its crown            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../../theme"

// One body for every species, lit from above, with the crown its species
// wears: round ears, leaves, a flame, a corona or long droopy ears.
//
// Shades are derived from the coat rather than named, so a palette change
// takes the whole creature with it.
Item {
    id: root

    property var kind: ({ id: "dot", ears: "round" })
    property color coat: Theme.accent
    property real size: 40
    property string mood: "content"
    property bool egg: false
    property real blink: 1

    readonly property real s: root.size
    readonly property color dark: Qt.darker(root.coat, 1.7)
    readonly property color mid: Qt.darker(root.coat, 1.25)
    readonly property color light: Qt.lighter(root.coat, 1.32)
    readonly property string ears: root.kind.ears ?? "round"

    PetEgg {
        anchors.fill: parent
        visible: root.egg
        size: root.s
        coat: root.coat
    }

    Item {
        anchors.fill: parent
        visible: !root.egg

        // ── BEHIND THE BODY ─────────────────────────────────────────────────

        Shape {
            visible: root.ears === "round" || root.ears === "droop"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.mid
                strokeWidth: root.s * 0.085
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                startX: root.s * 0.72
                startY: root.s * 0.86

                PathCubic {
                    control1X: root.s * 0.95; control1Y: root.s * 0.90
                    control2X: root.s * 0.99; control2Y: root.s * 0.60
                    x: root.s * 0.88;         y: root.s * 0.50
                }
            }
        }

        Repeater {
            model: [-1, 1]

            Rectangle {
                required property int modelData

                x: root.s * 0.5 + modelData * root.s * 0.17 - width / 2
                y: root.s * 0.85
                width: root.s * 0.21
                height: root.s * 0.11
                radius: height / 2
                color: root.mid
            }
        }

        // ── THE CROWN ───────────────────────────────────────────────────────

        Repeater {
            model: root.ears === "round" ? [-1, 1] : []

            Item {
                required property int modelData

                x: root.s * 0.5 + modelData * root.s * 0.24 - width / 2
                y: root.s * 0.06
                width: root.s * 0.27
                height: root.s * 0.27

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.coat
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.48
                    height: parent.height * 0.48
                    radius: width / 2
                    opacity: 0.5
                    color: root.dark
                }
            }
        }

        Repeater {
            model: root.ears === "droop" ? [-1, 1] : []

            Rectangle {
                required property int modelData

                x: root.s * 0.5 + modelData * root.s * 0.36 - width / 2
                y: root.s * 0.20
                width: root.s * 0.16
                height: root.s * 0.50
                radius: width / 2
                rotation: modelData * 16
                color: root.mid
            }
        }

        Rectangle {
            visible: root.ears === "leaf"
            x: root.s * 0.485
            y: root.s * 0.04
            width: root.s * 0.04
            height: root.s * 0.22
            radius: width / 2
            color: root.mid
        }

        Repeater {
            model: root.ears === "leaf" ? [-1, 1] : []

            Rectangle {
                required property int modelData

                x: root.s * 0.5 + modelData * root.s * 0.15 - width / 2
                y: 0
                width: root.s * 0.28
                height: root.s * 0.17
                topLeftRadius: modelData < 0 ? height : 0
                bottomRightRadius: modelData < 0 ? height : 0
                topRightRadius: modelData < 0 ? 0 : height
                bottomLeftRadius: modelData < 0 ? 0 : height
                rotation: modelData * 22
                color: root.light
            }
        }

        Shape {
            visible: root.ears === "tuft"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: LinearGradient {
                    x1: 0; y1: 0
                    x2: 0; y2: root.s * 0.32

                    GradientStop { position: 0.0; color: Qt.lighter(root.coat, 1.6) }
                    GradientStop { position: 1.0; color: root.light }
                }

                startX: root.s * 0.5
                startY: -root.s * 0.02

                PathCubic {
                    control1X: root.s * 0.76; control1Y: root.s * 0.10
                    control2X: root.s * 0.72; control2Y: root.s * 0.26
                    x: root.s * 0.5;          y: root.s * 0.32
                }
                PathCubic {
                    control1X: root.s * 0.28; control1Y: root.s * 0.26
                    control2X: root.s * 0.24; control2Y: root.s * 0.10
                    x: root.s * 0.5;          y: -root.s * 0.02
                }
            }
        }

        Repeater {
            model: root.ears === "none" ? 11 : 0

            Rectangle {
                required property int index

                readonly property real angle: index * (Math.PI * 2 / 11) - Math.PI / 2

                x: root.s * 0.5 + Math.cos(angle) * root.s * 0.45 - width / 2
                y: root.s * 0.55 + Math.sin(angle) * root.s * 0.45 - height / 2
                width: root.s * 0.11
                height: root.s * 0.05
                radius: height / 2
                rotation: angle * 180 / Math.PI
                opacity: 0.9
                color: root.light
            }
        }

        // ── THE BODY ────────────────────────────────────────────────────────

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: LinearGradient {
                    x1: 0; y1: root.s * 0.14
                    x2: 0; y2: root.s * 0.96

                    GradientStop { position: 0.0; color: root.light }
                    GradientStop { position: 0.5; color: root.coat }
                    GradientStop { position: 1.0; color: root.mid }
                }

                startX: root.s * 0.5
                startY: root.s * 0.14

                PathCubic {
                    control1X: root.s * 0.78; control1Y: root.s * 0.14
                    control2X: root.s * 0.87; control2Y: root.s * 0.40
                    x: root.s * 0.87;         y: root.s * 0.61
                }
                PathCubic {
                    control1X: root.s * 0.87; control1Y: root.s * 0.85
                    control2X: root.s * 0.73; control2Y: root.s * 0.95
                    x: root.s * 0.5;          y: root.s * 0.95
                }
                PathCubic {
                    control1X: root.s * 0.27; control1Y: root.s * 0.95
                    control2X: root.s * 0.13; control2Y: root.s * 0.85
                    x: root.s * 0.13;         y: root.s * 0.61
                }
                PathCubic {
                    control1X: root.s * 0.13; control1Y: root.s * 0.40
                    control2X: root.s * 0.22; control2Y: root.s * 0.14
                    x: root.s * 0.5;          y: root.s * 0.14
                }
            }
        }

        Rectangle {
            x: root.s * 0.30
            y: root.s * 0.60
            width: root.s * 0.40
            height: root.s * 0.32
            radius: width / 2
            opacity: 0.5
            color: root.light
        }

        // The light it is lit by.
        Rectangle {
            x: root.s * 0.24
            y: root.s * 0.18
            width: root.s * 0.28
            height: root.s * 0.11
            radius: height / 2
            rotation: -24
            opacity: 0.24
            color: Theme.indicator
        }

        PetSoftFace {
            anchors.fill: parent
            size: root.s
            mood: root.mood
            blink: root.blink
            blush: root.dark
            faceY: 0.45
            gap: 0.16
            mouthY: 0.73
        }
    }
}
