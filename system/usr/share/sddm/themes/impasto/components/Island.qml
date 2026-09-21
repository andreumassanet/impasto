// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I S L A N D                                                            │
// │   the island at the top · a padlock that opens on the right password     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "."

// The lock screen's island at rest: hanging from the top edge at the bar's
// size, a padlock inside. Nothing here scans a face, so it never grows.
Item {
    id: root

    property bool opened: false

    readonly property int restWidth: 150

    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    width: root.restWidth
    height: Theme.capsuleHeight + Theme.barTopMargin

    // A concave fillet each side, where the island meets the edge: the square
    // minus a disc on its far corner.
    component Fillet: Shape {
        id: fillet

        property bool mirrored: false

        width: 2 * Theme.radiusNotch
        height: 2 * Theme.radiusNotch
        preferredRendererType: Shape.CurveRenderer

        transform: Scale {
            xScale: fillet.mirrored ? -1 : 1
            origin.x: fillet.width / 2
        }

        ShapePath {
            strokeWidth: 0
            fillColor: Theme.island

            startX: 0
            startY: 0
            PathLine { x: fillet.width; y: 0 }
            PathAngleArc {
                centerX: fillet.width
                centerY: fillet.height
                radiusX: fillet.width
                radiusY: fillet.height
                startAngle: -90
                sweepAngle: -90
            }
            PathLine { x: 0; y: 0 }
        }
    }

    Fillet {
        anchors.right: body.left
        anchors.top: parent.top
        mirrored: true
    }

    Fillet {
        anchors.left: body.right
        anchors.top: parent.top
    }

    Rectangle {
        id: body

        anchors.fill: parent
        color: Theme.island
        radius: Math.min(root.height / 2, Theme.radiusLarge + 4)
        topLeftRadius: 0
        topRightRadius: 0
    }

    // Centred as the bar centres its own: half the notch's pad above, half
    // below.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.barTopMargin / 2
        anchors.top: parent.top
        anchors.topMargin: Theme.barTopMargin / 2

        Padlock {
            anchors.centerIn: parent
            scale: 0.8
            opened: root.opened
        }
    }
}
