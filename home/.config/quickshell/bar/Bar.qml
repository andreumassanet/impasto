// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A R                                                                  │
// │   the bar · the island and its two sides, in three styles                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../theme"
import "../services"
import "./widgets"
import "./modules"
import "./island"
import "./island/controls"
import "../components"

// The island in the middle and the two sides (`SettingsService.barZone`), in
// one of three styles:
//
//   grouped   the sides sit against the island and move aside as it grows
//   spread    the sides sit at the screen edges and hold still
//   island    everything in one capsule; the band morphs into whatever the
//             island opens
//
// Every detail opens in the island. The window is full-screen and never
// resizes; the input mask covers the bar and the island, and a focus grab
// closes the island on any click outside it.
PanelWindow {
    id: root

    readonly property alias island: island

    // Distance from the screen edge to the ends. Matches the compositor's
    // outer gap so the bar lines up with tiled windows.
    readonly property int edgeMargin: SettingsService.barSideMargin

    readonly property string style: SettingsService.barStyle
    readonly property bool spread: root.style === "spread"
    readonly property bool unified: root.style === "island"
    readonly property bool grouped: !root.spread && !root.unified

    // Stretch the band across the screen instead of fitting its contents.
    // Only the one-capsule style has a band.
    readonly property bool fullWidth: root.unified && SettingsService.barFullWidth

    readonly property bool holding: island.expanded

    // Maximum panel width. Spread, the sides stay put, so a panel gets the room
    // between them; otherwise the sides move aside and it gets the whole bar.
    readonly property int panelRoom: root.spread
        ? root.width - 2 * (root.edgeMargin
            + Math.max(leftZone.width, rightZone.width) + Theme.capsuleSpacing)
        : root.width - 2 * root.edgeMargin

    // Computed rather than read from `island.x`, which comes from an anchor
    // resolved during layout and would lag a frame behind the width.
    readonly property real islandLeft: (root.width - island.width) / 2
    readonly property real islandRight: root.islandLeft + island.width

    // ── ONE CAPSULE ─────────────────────────────────────────────────────────
    //
    // A band a capsule tall, with the sides at its ends and the island in the
    // middle. When the island shows anything beyond the clock, the band morphs
    // into it and the sides are clipped by its closing ends.

    // Inset of each side from the band's edge, clear of the curve.
    readonly property int hostedInset: 12

    // The same at both ends, so the clock stays centred on the screen.
    readonly property real hostedSlot: root.unified
        ? root.hostedInset + Math.max(leftZone.width, rightZone.width) + Theme.capsuleSpacing * 2
        : 0

    // The island's width inside the band, animated on the island's clock so
    // the band widens with it. An OSD is wider than the clock and pushes the
    // sides out rather than overlapping them.
    property real restWidth: island.state.layer === island.state.layerOsd
        ? Math.max(ModuleService.restWidth, island.size.width)
        : ModuleService.restWidth

    Behavior on restWidth {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // The band at rest: the island's rest width plus a slot for each side.
    readonly property real bodyWidth: {
        if (!root.unified)
            return island.width
        if (root.fullWidth)
            return root.width - 2 * root.edgeMargin
        return root.restWidth + 2 * root.hostedSlot
    }

    readonly property real bandRow: Theme.capsuleHeight + island.notchPad

    // The island is showing more than the clock: a panel, a detail, the
    // glance or a notification. An OSD fits in the band and does not count.
    readonly property bool islandTaken: island.expanded
        || island.state.layer === island.state.layerSummary
        || island.state.layer === island.state.layerNotification
    readonly property real bodyX: root.fullWidth
        ? root.edgeMargin : (root.width - root.bodyWidth) / 2

    // 0 at rest, 1 once the island has taken over the band. Animated on the
    // island's clock and curve so the two land together.
    property real bandInto: root.unified && root.islandTaken ? 1 : 0

    Behavior on bandInto {
        enabled: island.animated
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // Interpolates from the rest width to the island's animated width as
    // `bandInto` goes from 0 to 1. Both run on the same curve, so this is one
    // morph with no clock of its own. The max() stops a spring curve's
    // overshoot from making the band narrower than the island.
    readonly property real bandWidth: root.bandInto === 0 && !root.islandTaken
        ? root.bodyWidth
        : island.width + (root.bodyWidth - root.restWidth) * Math.max(0, 1 - root.bandInto)
    readonly property real bandX: (root.width - root.bandWidth) / 2

    // Attached (notch mode), only the island reaches the screen edge; the
    // sides stay capsules, centred on `laneY`.
    readonly property int islandTopMargin: SettingsService.islandAttached ? 0 : Theme.barTopMargin

    // The line everything on the bar is centred on. Attached, the island
    // reaches the screen edge, so its centre is half a margin higher and the
    // sides move up to match.
    readonly property real laneY: SettingsService.islandAttached
        ? Theme.barTopMargin / 2 : Theme.barTopMargin

    readonly property int collapsedHeight: Theme.barBand

    // Grouped, the sides make room for a module detail but hide for a panel.
    // In one capsule they hide whenever the island takes the band.
    readonly property bool sidesAway: root.unified
        ? root.islandTaken
        : island.expanded && root.grouped && island.state.openPanel !== "module"

    anchors {
        top: true
        left: true
        right: true
    }

    // ── SURFACE ─────────────────────────────────────────────────────────────
    //
    // The layer surface is full-screen and never resizes: resizing it on every
    // animation frame makes the bar jitter, because the compositor applies the
    // new size a frame before or after the matching buffer. Input is handled by
    // the mask, which is cheap to change per frame.
    implicitHeight: root.screen.height

    // Input region: the bar's band, plus the island's shape (the band's, in
    // one capsule) with 12 px below it so the bottom edge still counts. The
    // whole screen only while the control centre is being arranged, since
    // blocks are dragged out of the tray card, which moves. Outside clicks are
    // left to the focus grab, so windows under an open panel stay usable.
    readonly property real shapeLeft: root.unified
        ? Math.min(root.bandX, root.islandLeft) : root.islandLeft
    readonly property real shapeRight: root.unified
        ? Math.max(root.bandX + root.bandWidth, root.islandRight) : root.islandRight
    readonly property bool wholeScreen: root.holding && ControlsService.editing

    // No input at all while desktop widgets are being arranged: dragging one
    // over the bar would move the pointer to this surface, and the desktop
    // would drop the widget.
    mask: Region {
        width: DesktopService.editing ? 0 : root.width
        height: DesktopService.editing ? 0
            : root.wholeScreen ? root.height : root.collapsedHeight

        Region {
            x: root.shapeLeft
            width: DesktopService.editing ? 0 : root.shapeRight - root.shapeLeft
            height: root.islandTopMargin + island.height + 12
        }
    }

    // Pinned to what the bar paints, so tiled windows never move while the
    // island grows.
    exclusiveZone: Theme.barReserve
    color: "transparent"

    // ── FOCUS ───────────────────────────────────────────────────────────────
    //
    // On-demand keyboard focus plus a Hyprland focus grab while the island is
    // open. The grab keeps the keyboard here when the pointer crosses a window
    // (with `follow_mouse`, on-demand focus alone loses it), and a click on any
    // other surface clears it, which closes the island. The compositor
    // restores focus when the grab ends. Both stand down while the capture
    // surface is up, so an open panel waits under it instead of closing.
    readonly property bool holdsKeyboard: island.expanded && !CaptureService.active

    WlrLayershell.keyboardFocus: root.holdsKeyboard
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: root.holdsKeyboard
        windows: [root]
        onCleared: root.dismiss()
    }

    // ── OPENING A DETAIL ────────────────────────────────────────────────────
    //
    // Every activation on the bar comes through here
    // (`ModuleService.activate`). Clicking the open module again closes it; any
    // other replaces it.
    function activate(id: string, from: string): void {
        if (ModuleService.openId === id) {
            root.dismiss()
            return
        }

        // Always in the island, whatever the style or screen.
        ModuleService.openHost = "island"
        ModuleService.openId = id
        island.open("module")
    }

    function dismiss(): void {
        if (island.expanded)
            island.close()
        ModuleService.close()
    }

    Connections {
        target: ModuleService

        function onActivationRequested(id: string, from: string): void {
            root.activate(id, from)
        }

        // Bar buttons for panels (launcher, overview) toggle them.
        function onPanelToggled(panel: string): void {
            island.toggle(panel)
        }

        // The service closed the detail, e.g. the player went away.
        function onOpenIdChanged(): void {
            if (ModuleService.openId === "" && island.state.openPanel === "module")
                island.close()
        }
    }

    // Lets a bar button stay lit while its panel is open.
    Binding {
        target: ModuleService
        property: "shownPanel"
        value: island.state.openPanel
    }

    Connections {
        target: island.state

        // The island left the detail (Escape, a click outside, another panel).
        function onOpenPanelChanged(): void {
            if (island.state.openPanel !== "module" && ModuleService.openHost === "island")
                ModuleService.close()
        }
    }

    // Clicks on the bar outside the open island close it. The bar is inside
    // the focus grab, so the grab never sees them.
    MouseArea {
        anchors.fill: parent
        enabled: root.holding
        onClicked: root.dismiss()
    }

    // ── SHADOW ──────────────────────────────────────────────────────────────
    //
    // Same numbers and setting as the window shadow. The band, the island and
    // the notch fillets touch, so they share one flattened layer; separate
    // shadows would draw a seam where they overlap. The side capsules cast
    // their own (`BarZone`).
    //
    // Cast from a copy of the shapes: layering the real bar would re-blur the
    // full-screen surface every time the clock or the spectrum repaints.
    //
    // The copy is grown by `Theme.shadowBarSpread` and blurred. MultiEffect's
    // `shadowEnabled` would also draw the source, showing the enlarged copy as
    // a black rim. `layer.effect` rather than a hidden `source` item, which
    // does not work inside a Repeater.
    Loader {
        anchors.fill: parent
        active: SettingsService.windowShadow
        sourceComponent: shadowBody
    }

    Component {
        id: shadowBody

        Item {
            id: caster

            anchors.fill: parent
            opacity: Theme.shadowOpacity

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: Theme.shadowBarRange - Theme.shadowBarSpread
            }

            readonly property int spread: Theme.shadowBarSpread

            Rectangle {
                x: band.x - caster.spread
                y: band.y - caster.spread
                width: band.width + 2 * caster.spread
                height: band.height + 2 * caster.spread
                radius: band.radius + caster.spread
                topLeftRadius: band.topLeftRadius > 0 ? band.topLeftRadius + caster.spread : 0
                topRightRadius: band.topRightRadius > 0 ? band.topRightRadius + caster.spread : 0
                visible: body.visible
                color: Theme.shadowColor
            }

            Rectangle {
                x: root.islandLeft - caster.spread
                y: island.y - caster.spread
                width: island.width + 2 * caster.spread
                height: island.height + 2 * caster.spread
                radius: island.radius + caster.spread
                topLeftRadius: island.topLeftRadius > 0 ? island.topLeftRadius + caster.spread : 0
                topRightRadius: island.topRightRadius > 0 ? island.topRightRadius + caster.spread : 0
                color: Theme.shadowColor
            }

            Repeater {
                model: [notchLeft, notchRight]

                NotchFillet {
                    required property var modelData

                    x: modelData.x
                    y: modelData.y
                    width: modelData.width
                    height: modelData.height
                    visible: modelData.visible
                    opacity: modelData.opacity
                    mirrored: modelData.mirrored
                    color: Theme.shadowColor
                }
            }

        }
    }

    // ── BAND ────────────────────────────────────────────────────────────────
    //
    // Two shapes of the same black: the band, and the island on top of it.
    // Neither has an outline, which would draw the seam between them.
    Item {
        id: body

        anchors.fill: parent
        visible: root.unified

        // Grows with the island; at rest both share height and radius.
        Rectangle {
            id: band

            x: root.bandX
            y: root.islandTopMargin
            width: root.bandWidth
            height: Math.max(root.bandRow, island.height)
            radius: island.radius
            topLeftRadius: SettingsService.islandAttached ? 0 : band.radius
            topRightRadius: SettingsService.islandAttached ? 0 : band.radius
            color: island.surfaceColor

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            // Clicking the band opens the island. The sides sit above it and
            // take their own clicks.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: island.open("controls")
            }
        }
    }

    DynamicIsland {
        id: island

        hosted: root.unified
        roomForPanel: root.panelRoom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.islandTopMargin

        Behavior on anchors.topMargin {
            enabled: island.animated
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }
    }

    // The island's hairline, drawn round the band once it takes the island's
    // shape. Above both, since the opaque island covers the band's own edge.
    // None at rest and none in paper mode.
    Rectangle {
        id: outline

        x: band.x
        y: band.y
        width: band.width
        height: band.height
        radius: band.radius
        topLeftRadius: band.topLeftRadius
        topRightRadius: band.topRightRadius
        visible: root.unified && !island.paper
        color: "transparent"
        border.width: 1
        border.color: root.islandTaken ? Theme.islandBorder : "transparent"

        Behavior on border.color { ColorAnimation { duration: Theme.durationMedium } }
    }

    // The control centre's tray card while its grid is being arranged. On this
    // surface so blocks can be dragged from it onto the island; it fills the
    // surface and starts under the island.
    Item {
        id: overlay

        anchors.fill: parent
        z: 3

        Loader {
            anchors.fill: parent
            active: ControlsService.editing
            sourceComponent: ControlsTray {
                host: overlay
                homeTop: root.islandTopMargin + island.height + Theme.desktopGutter
            }
        }
    }

    // Notch fillets flaring from the island's edges out to the screen edge.
    // In one capsule they follow whichever edge is further out, the band's or
    // the island's, since a spring curve can push the island past the band.
    NotchFillet {
        id: notchLeft

        x: (root.unified ? Math.min(root.bandX, root.islandLeft) : root.islandLeft) - width
        anchors.top: parent.top
        visible: SettingsService.islandAttached
        mirrored: true
        color: island.surfaceColor
    }

    NotchFillet {
        id: notchRight

        x: root.unified ? Math.max(root.bandX + root.bandWidth, root.islandRight) : root.islandRight
        anchors.top: parent.top
        visible: SettingsService.islandAttached
        color: island.surfaceColor
    }

    // ── SIDES ───────────────────────────────────────────────────────────────
    //
    // Grouped, the sides are anchored to the island's animated edges, so they
    // move aside on its clock with nothing else to animate. Spread, they stay
    // in the corners. In one capsule they are the band's ends; while it morphs
    // they are clipped by it and fade out faster than it closes.
    Item {
        id: sides

        readonly property bool cropped: root.unified && root.bandInto > 0

        x: sides.cropped ? band.x : 0
        y: 0
        width: sides.cropped ? band.width : root.width
        height: root.height
        clip: sides.cropped

        BarZone {
            id: leftZone

            entries: SettingsService.barItems("left")
            chromeless: root.unified
            x: (root.unified ? root.bodyX + root.hostedInset
                : root.spread ? root.edgeMargin
                : root.islandLeft - Theme.capsuleSpacing - leftZone.width) - sides.x
            y: root.laneY
            opacity: root.sidesAway ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: root.unified && root.sidesAway ? Theme.durationFast : Theme.durationMedium
                    easing.type: Theme.easing
                }
            }
        }

        BarZone {
            id: rightZone

            entries: SettingsService.barItems("right")
            chromeless: root.unified
            x: (root.unified ? root.bodyX + root.bodyWidth - root.hostedInset - rightZone.width
                : root.spread ? root.width - root.edgeMargin - rightZone.width
                : root.islandRight + Theme.capsuleSpacing) - sides.x
            y: root.laneY
            opacity: root.sidesAway ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: root.unified && root.sidesAway ? Theme.durationFast : Theme.durationMedium
                    easing.type: Theme.easing
                }
            }
        }
    }
}
