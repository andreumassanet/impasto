// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   S O F T   F A C E                                              │
// │   the drawn face · eyes that blink and shut, a mouth per mood            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../../theme"

// Glossy eyes, a touch of colour under them and one mouth per mood. Shared by
// the two shaded styles, which differ in the body and not in the face.
//
// Everything is placed in fractions of `size`, so the body says where the face
// belongs and the face draws itself there.
Item {
    id: root

    property real size: 40
    property string mood: "content"
    // 1 open, 0 shut. Driven by PetFace's blink.
    property real blink: 1
    property color ink: Theme.island
    property color blush: Theme.accent

    // · where the face sits on the body
    property real faceY: 0.45
    property real gap: 0.16
    property real mouthY: 0.72

    readonly property bool asleep: root.mood === "asleep"
    readonly property real s: root.size

    // ── EYES ────────────────────────────────────────────────────────────────

    Repeater {
        model: root.asleep ? [] : [-1, 1]

        Item {
            id: eye

            required property int modelData

            x: root.s * 0.5 + eye.modelData * root.s * root.gap - width / 2
            y: root.s * root.faceY
            width: root.s * 0.19
            height: root.s * 0.24

            transform: Scale {
                origin.y: eye.height / 2
                yScale: root.blink
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.ink
            }

            Rectangle {
                x: parent.width * 0.14
                y: parent.height * 0.12
                width: parent.width * 0.42
                height: width
                radius: width / 2
                color: Theme.indicator
            }

            Rectangle {
                x: parent.width * 0.48
                y: parent.height * 0.64
                width: parent.width * 0.24
                height: width
                radius: width / 2
                opacity: 0.5
                color: Theme.indicator
            }
        }
    }

    // Shut, and curved the way an eye closes.
    Repeater {
        model: root.asleep ? [-1, 1] : []

        Shape {
            required property int modelData

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.ink
                strokeWidth: root.s * 0.04
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                startX: root.s * (0.5 + modelData * root.gap) - root.s * 0.08
                startY: root.s * (root.faceY + 0.10)

                PathQuad {
                    controlX: root.s * (0.5 + modelData * root.gap)
                    controlY: root.s * (root.faceY + 0.02)
                    x: root.s * (0.5 + modelData * root.gap) + root.s * 0.08
                    y: root.s * (root.faceY + 0.10)
                }
            }
        }
    }

    // ── COLOUR UNDER THE EYES ───────────────────────────────────────────────

    Repeater {
        model: [-1, 1]

        Rectangle {
            required property int modelData

            x: root.s * 0.5 + modelData * root.s * 0.28 - width / 2
            y: root.s * (root.mouthY - 0.07)
            width: root.s * 0.12
            height: root.s * 0.06
            radius: height / 2
            opacity: 0.4
            color: root.blush
        }
    }

    // ── MOUTH ───────────────────────────────────────────────────────────────

    Shape {
        visible: root.mood === "content" || root.asleep
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.s * 0.045
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: root.s * 0.43
            startY: root.s * root.mouthY

            PathQuad {
                controlX: root.s * 0.5
                controlY: root.s * (root.mouthY + (root.asleep ? 0.05 : 0.08))
                x: root.s * 0.57
                y: root.s * root.mouthY
            }
        }
    }

    // Open, flat on top and round below.
    Shape {
        visible: root.mood === "beaming"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.ink
            strokeWidth: 0
            startX: root.s * 0.38
            startY: root.s * (root.mouthY - 0.01)

            PathLine { x: root.s * 0.62; y: root.s * (root.mouthY - 0.01) }
            PathCubic {
                control1X: root.s * 0.62; control1Y: root.s * (root.mouthY + 0.15)
                control2X: root.s * 0.38; control2Y: root.s * (root.mouthY + 0.15)
                x: root.s * 0.38;         y: root.s * (root.mouthY - 0.01)
            }
        }
    }

    Rectangle {
        visible: root.mood === "peckish"
        x: root.s * 0.5 - width / 2
        y: root.s * (root.mouthY + 0.01)
        width: root.s * 0.16
        height: root.s * 0.045
        radius: height / 2
        color: root.ink
    }

    Shape {
        visible: root.mood === "lonely"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.s * 0.045
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: root.s * 0.43
            startY: root.s * (root.mouthY + 0.05)

            PathQuad {
                controlX: root.s * 0.5; controlY: root.s * (root.mouthY - 0.03)
                x: root.s * 0.57;       y: root.s * (root.mouthY + 0.05)
            }
        }
    }
}
