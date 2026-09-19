// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   C R E A T U R E                                                │
// │   the pet drawn as itself · one silhouette per species                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../../theme"

// A different animal for each species rather than one body in five colours:
// a cat with a tail, a seed under two leaves, a flame, a sun in its corona, a
// cloud with long ears. Shaded like `PetPlush` and wearing the same face, so
// the two styles differ in shape and not in finish.
//
// The body is keyed on the species id, and an unknown one comes out round.
Item {
    id: root

    property var kind: ({ id: "dot", ears: "round" })
    property color coat: Theme.accent
    property real size: 40
    property string mood: "content"
    property bool egg: false
    property real blink: 1

    readonly property real s: root.size
    readonly property color dark: Qt.darker(root.coat, 1.75)
    readonly property color mid: Qt.darker(root.coat, 1.28)
    readonly property color light: Qt.lighter(root.coat, 1.35)
    readonly property string id: root.kind.id ?? "dot"

    // · where the face sits, and whether the body carries a belly
    readonly property var build: ({
        dot:    { faceY: 0.44, gap: 0.16, mouthY: 0.70, belly: false },
        sprout: { faceY: 0.50, gap: 0.15, mouthY: 0.76, belly: true },
        ember:  { faceY: 0.50, gap: 0.15, mouthY: 0.76, belly: false },
        sol:    { faceY: 0.46, gap: 0.17, mouthY: 0.72, belly: false },
        drift:  { faceY: 0.48, gap: 0.16, mouthY: 0.74, belly: false }
    })[root.id] ?? ({ faceY: 0.45, gap: 0.16, mouthY: 0.72, belly: false })

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
            visible: root.id === "dot"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.mid
                strokeWidth: root.s * 0.08
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                startX: root.s * 0.72
                startY: root.s * 0.86

                PathCubic {
                    control1X: root.s * 1.00; control1Y: root.s * 0.92
                    control2X: root.s * 1.02; control2Y: root.s * 0.50
                    x: root.s * 0.86;         y: root.s * 0.38
                }
            }
        }

        Repeater {
            model: root.id === "dot" ? [-1, 1] : []

            Shape {
                required property int modelData

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: root.mid
                    strokeColor: root.mid
                    strokeWidth: root.s * 0.07
                    joinStyle: ShapePath.RoundJoin
                    startX: root.s * (0.5 + modelData * 0.26)
                    startY: root.s * 0.06

                    PathLine { x: root.s * (0.5 + modelData * 0.38); y: root.s * 0.34 }
                    PathLine { x: root.s * (0.5 + modelData * 0.14); y: root.s * 0.30 }
                    PathLine { x: root.s * (0.5 + modelData * 0.26); y: root.s * 0.06 }
                }
            }
        }

        Repeater {
            model: root.id === "sol" ? 12 : 0

            Rectangle {
                required property int index

                readonly property real angle: index * (Math.PI * 2 / 12) - Math.PI / 2

                x: root.s * 0.5 + Math.cos(angle) * root.s * 0.44 - width / 2
                y: root.s * 0.56 + Math.sin(angle) * root.s * 0.44 - height / 2
                width: root.s * 0.12
                height: root.s * 0.05
                radius: height / 2
                rotation: angle * 180 / Math.PI
                color: root.light
            }
        }

        Repeater {
            model: root.id === "drift" ? [-1, 1] : []

            Rectangle {
                required property int modelData

                x: root.s * 0.5 + modelData * root.s * 0.43 - width / 2
                y: root.s * 0.46
                width: root.s * 0.16
                height: root.s * 0.46
                radius: width / 2
                rotation: modelData * 24
                color: root.mid
            }
        }

        // ── THE BODIES ──────────────────────────────────────────────────────

        // A round cat.
        Shape {
            visible: root.id !== "sprout" && root.id !== "ember"
                && root.id !== "sol" && root.id !== "drift"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: LinearGradient {
                    x1: 0; y1: root.s * 0.16
                    x2: 0; y2: root.s * 0.96

                    GradientStop { position: 0.0; color: root.light }
                    GradientStop { position: 0.48; color: root.coat }
                    GradientStop { position: 1.0; color: root.mid }
                }

                startX: root.s * 0.5
                startY: root.s * 0.16

                PathCubic {
                    control1X: root.s * 0.74; control1Y: root.s * 0.16
                    control2X: root.s * 0.84; control2Y: root.s * 0.38
                    x: root.s * 0.84;         y: root.s * 0.58
                }
                PathCubic {
                    control1X: root.s * 0.84; control1Y: root.s * 0.84
                    control2X: root.s * 0.72; control2Y: root.s * 0.96
                    x: root.s * 0.5;          y: root.s * 0.96
                }
                PathCubic {
                    control1X: root.s * 0.28; control1Y: root.s * 0.96
                    control2X: root.s * 0.16; control2Y: root.s * 0.84
                    x: root.s * 0.16;         y: root.s * 0.58
                }
                PathCubic {
                    control1X: root.s * 0.16; control1Y: root.s * 0.38
                    control2X: root.s * 0.26; control2Y: root.s * 0.16
                    x: root.s * 0.5;          y: root.s * 0.16
                }
            }
        }

        // A seed, narrow at the top.
        Shape {
            visible: root.id === "sprout"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: LinearGradient {
                    x1: 0; y1: root.s * 0.22
                    x2: 0; y2: root.s * 0.97

                    GradientStop { position: 0.0; color: root.light }
                    GradientStop { position: 0.48; color: root.coat }
                    GradientStop { position: 1.0; color: root.mid }
                }

                startX: root.s * 0.5
                startY: root.s * 0.22

                PathCubic {
                    control1X: root.s * 0.66; control1Y: root.s * 0.22
                    control2X: root.s * 0.84; control2Y: root.s * 0.44
                    x: root.s * 0.84;         y: root.s * 0.66
                }
                PathCubic {
                    control1X: root.s * 0.84; control1Y: root.s * 0.87
                    control2X: root.s * 0.70; control2Y: root.s * 0.97
                    x: root.s * 0.5;          y: root.s * 0.97
                }
                PathCubic {
                    control1X: root.s * 0.30; control1Y: root.s * 0.97
                    control2X: root.s * 0.16; control2Y: root.s * 0.87
                    x: root.s * 0.16;         y: root.s * 0.66
                }
                PathCubic {
                    control1X: root.s * 0.16; control1Y: root.s * 0.44
                    control2X: root.s * 0.34; control2Y: root.s * 0.22
                    x: root.s * 0.5;          y: root.s * 0.22
                }
            }
        }

        Rectangle {
            visible: root.id === "sprout"
            x: root.s * 0.48
            y: root.s * 0.06
            width: root.s * 0.04
            height: root.s * 0.22
            radius: width / 2
            color: root.mid
        }

        Repeater {
            model: root.id === "sprout" ? [-1, 1] : []

            Rectangle {
                required property int modelData

                x: root.s * 0.5 + modelData * root.s * 0.16 - width / 2
                y: root.s * 0.02
                width: root.s * 0.30
                height: root.s * 0.17
                topLeftRadius: modelData < 0 ? height : 0
                bottomRightRadius: modelData < 0 ? height : 0
                topRightRadius: modelData < 0 ? 0 : height
                bottomLeftRadius: modelData < 0 ? 0 : height
                rotation: modelData * 22
                color: root.light
            }
        }

        // A flame.
        Shape {
            visible: root.id === "ember"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: LinearGradient {
                    x1: 0; y1: root.s * 0.02
                    x2: 0; y2: root.s * 0.97

                    GradientStop { position: 0.0; color: Qt.lighter(root.coat, 1.7) }
                    GradientStop { position: 0.32; color: root.light }
                    GradientStop { position: 0.62; color: root.coat }
                    GradientStop { position: 1.0; color: root.mid }
                }

                startX: root.s * 0.5
                startY: root.s * 0.02

                PathCubic {
                    control1X: root.s * 0.60; control1Y: root.s * 0.22
                    control2X: root.s * 0.86; control2Y: root.s * 0.36
                    x: root.s * 0.86;         y: root.s * 0.64
                }
                PathCubic {
                    control1X: root.s * 0.86; control1Y: root.s * 0.86
                    control2X: root.s * 0.72; control2Y: root.s * 0.97
                    x: root.s * 0.5;          y: root.s * 0.97
                }
                PathCubic {
                    control1X: root.s * 0.28; control1Y: root.s * 0.97
                    control2X: root.s * 0.14; control2Y: root.s * 0.86
                    x: root.s * 0.14;         y: root.s * 0.64
                }
                PathCubic {
                    control1X: root.s * 0.14; control1Y: root.s * 0.36
                    control2X: root.s * 0.40; control2Y: root.s * 0.22
                    x: root.s * 0.5;          y: root.s * 0.02
                }
            }
        }

        // A sun.
        Shape {
            visible: root.id === "sol"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: LinearGradient {
                    x1: 0; y1: root.s * 0.20
                    x2: 0; y2: root.s * 0.92

                    GradientStop { position: 0.0; color: root.light }
                    GradientStop { position: 0.48; color: root.coat }
                    GradientStop { position: 1.0; color: root.mid }
                }

                startX: root.s * 0.5
                startY: root.s * 0.20

                PathCubic {
                    control1X: root.s * 0.70; control1Y: root.s * 0.20
                    control2X: root.s * 0.86; control2Y: root.s * 0.36
                    x: root.s * 0.86;         y: root.s * 0.56
                }
                PathCubic {
                    control1X: root.s * 0.86; control1Y: root.s * 0.76
                    control2X: root.s * 0.70; control2Y: root.s * 0.92
                    x: root.s * 0.5;          y: root.s * 0.92
                }
                PathCubic {
                    control1X: root.s * 0.30; control1Y: root.s * 0.92
                    control2X: root.s * 0.14; control2Y: root.s * 0.76
                    x: root.s * 0.14;         y: root.s * 0.56
                }
                PathCubic {
                    control1X: root.s * 0.14; control1Y: root.s * 0.36
                    control2X: root.s * 0.30; control2Y: root.s * 0.20
                    x: root.s * 0.5;          y: root.s * 0.20
                }
            }
        }

        // A cloud.
        Shape {
            visible: root.id === "drift"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: LinearGradient {
                    x1: 0; y1: root.s * 0.22
                    x2: 0; y2: root.s * 0.94

                    GradientStop { position: 0.0; color: root.light }
                    GradientStop { position: 0.5; color: root.coat }
                    GradientStop { position: 1.0; color: root.mid }
                }

                startX: root.s * 0.12
                startY: root.s * 0.66

                PathCubic {
                    control1X: root.s * 0.06; control1Y: root.s * 0.46
                    control2X: root.s * 0.16; control2Y: root.s * 0.30
                    x: root.s * 0.32;         y: root.s * 0.32
                }
                PathCubic {
                    control1X: root.s * 0.36; control1Y: root.s * 0.16
                    control2X: root.s * 0.60; control2Y: root.s * 0.14
                    x: root.s * 0.66;         y: root.s * 0.30
                }
                PathCubic {
                    control1X: root.s * 0.84; control1Y: root.s * 0.28
                    control2X: root.s * 0.94; control2Y: root.s * 0.44
                    x: root.s * 0.88;         y: root.s * 0.66
                }
                PathCubic {
                    control1X: root.s * 0.92; control1Y: root.s * 0.88
                    control2X: root.s * 0.74; control2Y: root.s * 0.96
                    x: root.s * 0.5;          y: root.s * 0.96
                }
                PathCubic {
                    control1X: root.s * 0.26; control1Y: root.s * 0.96
                    control2X: root.s * 0.08; control2Y: root.s * 0.88
                    x: root.s * 0.12;         y: root.s * 0.66
                }
            }
        }

        // ── SHADING AND FACE ────────────────────────────────────────────────

        Rectangle {
            visible: root.build.belly
            x: root.s * 0.32
            y: root.s * 0.62
            width: root.s * 0.36
            height: root.s * 0.30
            radius: width / 2
            opacity: 0.45
            color: root.light
        }

        Rectangle {
            x: root.s * 0.26
            y: root.s * (root.id === "ember" ? 0.28 : 0.22)
            width: root.s * 0.26
            height: root.s * 0.10
            radius: height / 2
            rotation: -26
            opacity: 0.22
            color: Theme.indicator
        }

        PetSoftFace {
            anchors.fill: parent
            size: root.s
            mood: root.mood
            blink: root.blink
            blush: root.dark
            faceY: root.build.faceY
            gap: root.build.gap
            mouthY: root.build.mouthY
        }
    }
}
