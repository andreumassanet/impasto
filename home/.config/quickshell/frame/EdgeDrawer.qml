// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   E D G E   D R A W E R                                                  │
// │   frame · a drawer that grows out of a screen edge                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../theme"
import "../services"
import "../components"

// A drawer that grows out of a screen edge: one shape in the island's ground,
// square against the edge, rounded on the inside, meeting the frame's inner
// line in two fillets. The launcher (bottom), the dock and the sliders (sides)
// are built on it.
//
// The window covers the screen and takes input only on the drawer (and on
// `reach`, a strip along the edge that wakes a hidden drawer). With
// `grabsKeyboard`, an open drawer holds the keyboard and a click outside it
// closes it (`dismissed`), as the island does.
PanelWindow {
    id: root

    // "bottom", "left" or "right".
    required property string edge
    property bool shown: false
    // Size of the content: `along` the edge and `depth` into the screen.
    property real along: 400
    property real depth: 300
    // Where along the edge the drawer is centred, 0 to 1.
    property real position: 0.5
    property bool grabsKeyboard: false
    // A strip this wide along the edge takes the pointer while hidden.
    property int reach: 0
    // Room kept from the windows while the drawer stays out (a dock that
    // does not hide), on its edge.
    property int reserve: 0
    // Whether this counts as "something is open" for the frame's "open" mode.
    property bool framed: root.shown
    readonly property bool edgeHovered: edgeHover.hovered
    readonly property bool hovered: bodyHover.hovered

    default property alias content: holder.data
    // Content beside the drawer rather than in it (the dock's popout): not
    // clipped to the drawer's shape, and taking input where `floatingMask` is.
    property alias floating: floatingLayer.data
    property Item floatingMask: null

    signal dismissed()

    readonly property bool vertical: root.edge !== "bottom"
    readonly property int frameThickness: SettingsService.frameMode === "none"
        ? 0 : SettingsService.frameThickness
    readonly property int fillet: Theme.desktopRadius
    readonly property int innerRadius: Theme.radiusLarge + 6

    // 0 hidden, 1 open; the drawer's depth follows it.
    property real progress: root.shown ? 1 : 0

    Behavior on along {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    Behavior on progress {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // The drawer starts at the frame's inner edge: the frame is the bar's
    // (`FrameRing`), and the two would otherwise be painted over each other.
    readonly property real bodyDepth: root.depth * root.progress
    readonly property real screenAlong: root.vertical ? root.height : root.width
    readonly property real alongStart: Math.max(root.frameThickness + root.fillet,
        Math.min(root.screenAlong - root.along - root.frameThickness - root.fillet,
                 root.screenAlong * root.position - root.along / 2))

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "impasto-drawer"
    WlrLayershell.keyboardFocus: root.grabsKeyboard && root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Counted while open, so the frame in "open" mode appears with it.
    onFramedChanged: DrawerService.noteFramed(root.framed)
    Component.onCompleted: {
        if (root.framed)
            DrawerService.noteFramed(true)
    }
    Component.onDestruction: {
        if (root.framed)
            DrawerService.noteFramed(false)
    }

    mask: Region {
        x: body.x
        y: body.y
        width: root.progress > 0 ? body.width : 0
        height: root.progress > 0 ? body.height : 0

        Region {
            x: root.edge === "right" ? root.width - root.reach : 0
            y: root.edge === "bottom" ? root.height - root.reach : 0
            width: root.vertical ? root.reach : root.width
            height: root.vertical ? root.height : root.reach
        }

        Region {
            item: root.floatingMask
        }
    }

    // A click anywhere else clears the grab, which is the drawer's dismissal.
    HyprlandFocusGrab {
        active: root.grabsKeyboard && root.shown
        windows: [root]
        onCleared: root.dismissed()
    }

    PanelWindow {
        screen: root.screen
        visible: root.reserve > 0
        anchors {
            left: root.edge !== "right"
            right: root.edge !== "left"
            bottom: true
            top: root.edge !== "bottom"
        }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        mask: Region {}
        exclusiveZone: root.reserve
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "impasto-frame"
    }

    // The edge strip.
    Item {
        x: root.edge === "right" ? root.width - root.reach : 0
        y: root.edge === "bottom" ? root.height - root.reach : 0
        width: root.vertical ? root.reach : root.width
        height: root.vertical ? root.height : root.reach

        HoverHandler {
            id: edgeHover
        }
    }

    Item {
        id: body

        visible: root.progress > 0
        x: root.edge === "left" ? root.frameThickness
           : root.edge === "right" ? root.width - root.frameThickness - root.bodyDepth : root.alongStart
        y: root.edge === "bottom" ? root.height - root.frameThickness - root.bodyDepth : root.alongStart
        width: root.vertical ? root.bodyDepth : root.along
        height: root.vertical ? root.along : root.bodyDepth
        clip: true

        HoverHandler {
            id: bodyHover
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.islandGround
            topLeftRadius: root.edge === "bottom" || root.edge === "right" ? root.innerRadius : 0
            topRightRadius: root.edge === "bottom" || root.edge === "left" ? root.innerRadius : 0
            bottomLeftRadius: root.edge === "right" ? root.innerRadius : 0
            bottomRightRadius: root.edge === "left" ? root.innerRadius : 0
        }

        // The content keeps its size and slides out from the edge.
        Item {
            id: holder

            width: root.vertical ? root.depth : root.along
            height: root.vertical ? root.along : root.depth
            x: root.edge === "left" ? root.bodyDepth - root.depth : 0
            y: 0
        }
    }

    Item {
        id: floatingLayer

        anchors.fill: parent
    }

    // The two fillets where the drawer meets the frame's inner line.
    component Fillet: NotchFillet {
        width: root.fillet
        height: root.fillet
        color: Theme.islandGround
        visible: root.progress > 0
        opacity: Math.min(1, root.progress * 3)
    }

    // Bottom edge: flipped vertically, either side of the drawer.
    Fillet {
        visible: root.edge === "bottom" && root.progress > 0
        x: body.x - width
        y: root.height - root.frameThickness - height
        mirrored: true
        transform: Scale { yScale: -1; origin.y: root.fillet / 2 }
    }

    Fillet {
        visible: root.edge === "bottom" && root.progress > 0
        x: body.x + body.width
        y: root.height - root.frameThickness - height
        transform: Scale { yScale: -1; origin.y: root.fillet / 2 }
    }

    // Side edges. A fillet fills the corner away from its curve's centre:
    // unmirrored, the top left; mirrored, the top right. Left drawer: above
    // it the bottom left (turned a quarter back), below it the top left.
    // Right drawer: above it the bottom right (flipped), below it the top right.
    Fillet {
        visible: root.edge === "left" && root.progress > 0
        x: root.frameThickness
        y: body.y - height
        transform: Rotation { origin.x: root.fillet / 2; origin.y: root.fillet / 2; angle: -90 }
    }

    Fillet {
        visible: root.edge === "left" && root.progress > 0
        x: root.frameThickness
        y: body.y + body.height
    }

    Fillet {
        visible: root.edge === "right" && root.progress > 0
        x: root.width - root.frameThickness - width
        y: body.y - height
        mirrored: true
        transform: Scale { yScale: -1; origin.y: root.fillet / 2 }
    }

    Fillet {
        visible: root.edge === "right" && root.progress > 0
        x: root.width - root.frameThickness - width
        y: body.y + body.height
        mirrored: true
    }
}
