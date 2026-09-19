// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   P A P E R                                                      │
// │   the pet cut flat · two tones, a hard edge between them                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../../theme"

// The creature as cut paper: no gradient, one hard diagonal between the lit
// half and the shaded one, geometric crowns and white eyes. The flattest of
// the styles, and the one that reads smallest.
Item {
    id: root

    property var kind: ({ id: "dot", ears: "round" })
    property color coat: Theme.accent
    property real size: 40
    property string mood: "content"
    property bool egg: false
    property real blink: 1

    readonly property real s: root.size
    readonly property color mid: Qt.darker(root.coat, 1.45)
    readonly property color ink: Theme.island
    readonly property string ears: root.kind.ears ?? "round"
    readonly property bool asleep: root.mood === "asleep"

    // ── THE EGG ─────────────────────────────────────────────────────────────

    Item {
        anchors.fill: parent
        visible: root.egg

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: LinearGradient {
                    x1: root.s * 0.10; y1: root.s * 0.10
                    x2: root.s * 0.90; y2: root.s * 0.96

                    GradientStop { position: 0.0;   color: Theme.indicator }
                    GradientStop { position: 0.62;  color: Theme.indicator }
                    GradientStop { position: 0.621; color: Qt.darker(Theme.indicator, 1.3) }
                    GradientStop { position: 1.0;   color: Qt.darker(Theme.indicator, 1.3) }
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
                { x: 0.30, y: 0.34, r: 0.10 },
                { x: 0.58, y: 0.26, r: 0.07 },
                { x: 0.60, y: 0.54, r: 0.11 },
                { x: 0.34, y: 0.68, r: 0.08 }
            ]

            Rectangle {
                required property var modelData

                x: root.s * modelData.x
                y: root.s * modelData.y
                width: root.s * modelData.r
                height: width
                radius: width / 2
                color: root.coat
            }
        }
    }

    // ── THE CREATURE ────────────────────────────────────────────────────────

    Item {
        anchors.fill: parent
        visible: !root.egg

        Repeater {
            model: root.ears === "round" ? [-1, 1] : []

            Shape {
                required property int modelData

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: root.mid
                    strokeWidth: 0
                    startX: root.s * (0.5 + modelData * 0.30)
                    startY: 0

                    PathLine { x: root.s * (0.5 + modelData * 0.46); y: root.s * 0.42 }
                    PathLine { x: root.s * (0.5 + modelData * 0.12); y: root.s * 0.32 }
                    PathLine { x: root.s * (0.5 + modelData * 0.30); y: 0 }
                }
            }
        }

        Repeater {
            model: root.ears === "droop" ? [-1, 1] : []

            Rectangle {
                required property int modelData

                x: root.s * 0.5 + modelData * root.s * 0.38 - width / 2
                y: root.s * 0.06
                width: root.s * 0.18
                height: root.s * 0.54
                radius: width / 2
                rotation: modelData * 12
                color: root.mid
            }
        }

        Repeater {
            model: root.ears === "leaf" ? [-1, 1] : []

            Rectangle {
                required property int modelData

                x: root.s * 0.5 + modelData * root.s * 0.16 - width / 2
                y: -root.s * 0.02
                width: root.s * 0.32
                height: root.s * 0.18
                topLeftRadius: modelData < 0 ? height : 0
                bottomRightRadius: modelData < 0 ? height : 0
                topRightRadius: modelData < 0 ? 0 : height
                bottomLeftRadius: modelData < 0 ? 0 : height
                rotation: modelData * 20
                color: root.mid
            }
        }

        Shape {
            visible: root.ears === "tuft"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.mid
                strokeWidth: 0
                startX: root.s * 0.5
                startY: -root.s * 0.02

                PathLine { x: root.s * 0.76; y: root.s * 0.34 }
                PathLine { x: root.s * 0.24; y: root.s * 0.34 }
                PathLine { x: root.s * 0.5;  y: -root.s * 0.02 }
            }
        }

        Repeater {
            model: root.ears === "none" ? 8 : 0

            Shape {
                required property int index

                readonly property real angle: index * (Math.PI * 2 / 8) - Math.PI / 2

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: root.mid
                    strokeWidth: 0
                    startX: root.s * 0.5 + Math.cos(angle) * root.s * 0.50
                    startY: root.s * 0.55 + Math.sin(angle) * root.s * 0.50

                    PathLine {
                        x: root.s * 0.5 + Math.cos(angle + 0.26) * root.s * 0.34
                        y: root.s * 0.55 + Math.sin(angle + 0.26) * root.s * 0.34
                    }
                    PathLine {
                        x: root.s * 0.5 + Math.cos(angle - 0.26) * root.s * 0.34
                        y: root.s * 0.55 + Math.sin(angle - 0.26) * root.s * 0.34
                    }
                }
            }
        }

        // One silhouette, cut in two along a hard edge.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: LinearGradient {
                    x1: root.s * 0.06; y1: root.s * 0.10
                    x2: root.s * 0.94; y2: root.s * 0.98

                    GradientStop { position: 0.0;   color: root.coat }
                    GradientStop { position: 0.60;  color: root.coat }
                    GradientStop { position: 0.601; color: root.mid }
                    GradientStop { position: 1.0;   color: root.mid }
                }

                startX: root.s * 0.5
                startY: root.s * 0.16

                PathCubic {
                    control1X: root.s * 0.88; control1Y: root.s * 0.16
                    control2X: root.s * 0.94; control2Y: root.s * 0.46
                    x: root.s * 0.94;         y: root.s * 0.66
                }
                PathCubic {
                    control1X: root.s * 0.94; control1Y: root.s * 0.88
                    control2X: root.s * 0.75; control2Y: root.s * 0.97
                    x: root.s * 0.5;          y: root.s * 0.97
                }
                PathCubic {
                    control1X: root.s * 0.25; control1Y: root.s * 0.97
                    control2X: root.s * 0.06; control2Y: root.s * 0.88
                    x: root.s * 0.06;         y: root.s * 0.66
                }
                PathCubic {
                    control1X: root.s * 0.06; control1Y: root.s * 0.46
                    control2X: root.s * 0.12; control2Y: root.s * 0.16
                    x: root.s * 0.5;          y: root.s * 0.16
                }
            }
        }

        // ── FACE ────────────────────────────────────────────────────────────

        Repeater {
            model: root.asleep ? [] : [-1, 1]

            Item {
                id: eye

                required property int modelData

                x: root.s * 0.5 + eye.modelData * root.s * 0.19 - width / 2
                y: root.s * 0.40
                width: root.s * 0.24
                height: root.s * 0.30

                transform: Scale {
                    origin.y: eye.height / 2
                    yScale: root.blink
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.indicator
                }

                // The pupil looks out, away from the other eye.
                Rectangle {
                    x: parent.width * (eye.modelData < 0 ? 0.14 : 0.40)
                    y: parent.height * (root.mood === "lonely" ? 0.44 : 0.32)
                    width: parent.width * 0.46
                    height: width
                    radius: width / 2
                    color: root.ink
                }
            }
        }

        Repeater {
            model: root.asleep ? [-1, 1] : []

            Shape {
                required property int modelData

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: root.ink
                    strokeWidth: root.s * 0.05
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    startX: root.s * (0.5 + modelData * 0.19) - root.s * 0.09
                    startY: root.s * 0.54

                    PathQuad {
                        controlX: root.s * (0.5 + modelData * 0.19)
                        controlY: root.s * 0.46
                        x: root.s * (0.5 + modelData * 0.19) + root.s * 0.09
                        y: root.s * 0.54
                    }
                }
            }
        }

        // The mouth: one flat block, shaped by mood.
        Rectangle {
            x: root.s * 0.5 - width / 2
            y: root.s * 0.76
            width: {
                switch (root.mood) {
                case "beaming": return root.s * 0.22
                case "peckish": return root.s * 0.16
                case "lonely":  return root.s * 0.18
                case "asleep":  return root.s * 0.12
                }
                return root.s * 0.18
            }
            height: {
                switch (root.mood) {
                case "beaming": return root.s * 0.11
                case "peckish": return root.s * 0.045
                case "asleep":  return root.s * 0.045
                }
                return root.s * 0.085
            }
            topLeftRadius: root.mood === "lonely" ? height : 0
            topRightRadius: root.mood === "lonely" ? height : 0
            bottomLeftRadius: root.mood === "lonely" ? 0 : height
            bottomRightRadius: root.mood === "lonely" ? 0 : height
            color: root.ink

            Behavior on width {
                NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
            }
            Behavior on height {
                NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
            }
        }
    }
}
