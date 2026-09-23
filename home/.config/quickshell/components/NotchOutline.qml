// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T C H   O U T L I N E                                              │
// │   the hairline round an attached island · open along the screen edge     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../theme"

// One stroke from the screen edge down the left fillet, round the shape and
// up the right fillet. Nothing runs along the top, where the shape meets the
// edge. Drawn half a pixel inside the fill, as a Rectangle border is.
Item {
    id: root

    // The shape's left and right edges and its height, in the parent's frame.
    property real shapeLeft: 0
    property real shapeRight: 0
    property real shapeHeight: 0
    // The shape's lower corners.
    property real radius: 0
    property color color: Theme.islandBorder

    // The fillet's radius: NotchFillet's square is its diameter wide.
    readonly property real fillet: Theme.radiusNotch * 2
    readonly property real r: Math.max(0, Math.min(root.radius,
        (root.shapeRight - root.shapeLeft) / 2, root.shapeHeight - root.fillet))

    anchors.fill: parent

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 1
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            startX: root.shapeLeft - root.fillet
            startY: -0.5

            PathArc {
                x: root.shapeLeft + 0.5
                y: root.fillet
                radiusX: root.fillet + 0.5
                radiusY: root.fillet + 0.5
            }
            PathLine { x: root.shapeLeft + 0.5; y: root.shapeHeight - root.r }
            PathArc {
                x: root.shapeLeft + root.r
                y: root.shapeHeight - 0.5
                radiusX: Math.max(0, root.r - 0.5)
                radiusY: Math.max(0, root.r - 0.5)
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.shapeRight - root.r; y: root.shapeHeight - 0.5 }
            PathArc {
                x: root.shapeRight - 0.5
                y: root.shapeHeight - root.r
                radiusX: Math.max(0, root.r - 0.5)
                radiusY: Math.max(0, root.r - 0.5)
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.shapeRight - 0.5; y: root.fillet }
            PathArc {
                x: root.shapeRight + root.fillet
                y: -0.5
                radiusX: root.fillet + 0.5
                radiusY: root.fillet + 0.5
            }
        }
    }
}
