// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F R A M E   R I N G                                                    │
// │   frame · the border round the screen, in the island's ground            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../theme"
import "../services"

// The border, drawn inside the bar's own full-screen surface so it shares the
// island's layer and ground: the island and the drawers grow out of it as one
// piece. The outer edge is the screen's, the inner edge is rounded like the
// windows. No input: the bar's mask decides that.
Item {
    id: root

    // Whether it is drawn now; fades in and out.
    property bool shown: false
    // Where the bar's band crosses the top edge. Translucent grounds would
    // darken where two shapes overlap, so the ring is cut away under it.
    property real holeLeft: 0
    property real holeRight: 0
    property real holeHeight: 0

    readonly property int thickness: SettingsService.frameThickness

    anchors.fill: parent
    opacity: root.shown ? 1 : 0
    visible: root.opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Outer edge, inner rounded edge and the band's place along the top,
        // all by the odd-even rule, so nothing is painted twice.
        ShapePath {
            fillColor: Theme.islandGround
            fillRule: ShapePath.OddEvenFill
            strokeWidth: 0

            PathRectangle {
                x: 0
                y: 0
                width: root.width
                height: root.height
            }

            PathRectangle {
                x: root.thickness
                y: root.thickness
                width: root.width - 2 * root.thickness
                height: root.height - 2 * root.thickness
                radius: Theme.desktopRadius
            }

            // A pixel narrower each side, so the band overlaps the ring and
            // no seam of wallpaper shows between them.
            PathRectangle {
                x: root.holeLeft + 1
                y: 0
                width: Math.max(0, root.holeRight - root.holeLeft - 2)
                height: root.holeHeight
            }
        }
    }
}
