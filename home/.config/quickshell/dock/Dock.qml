// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D O C K                                                                │
// │   dock · pinned and running applications                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

import "../theme"
import "../services"

// The dock: a capsule on a screen edge with the pinned and open applications.
//
// As with the bar, the surface never resizes: it spans its edge and the capsule
// moves inside it, because resizing a layer surface every frame flickers. The
// input mask is computed from the same geometry as the capsule, so clicks
// beside it reach the window behind. Never on the top edge, which is the bar's.
//
// ── ONE PER SCREEN ──────────────────────────────────────────────────────────
//
// One on every screen, all showing the same shelf: the list is what you have
// pinned and what is open anywhere, so every application is reachable from
// wherever you are — the workspaces strip's rule, where the dots are every
// workspace on the desk and only which one is lit is this screen's. What is
// this screen's here is what the pointer and the windows are doing on it: the
// hovered name, the menu, the autohide peek, and going away under a
// fullscreen window (`DockService.coveredOn`).
PanelWindow {
    id: root

    // The dock only requests the launcher; `shell.qml` wires it to the island.
    signal launcherRequested()

    readonly property string screenName: root.screen?.name ?? ""

    // Whether this is the screen being worked on — the same answer the island
    // uses, so the two never disagree about where you are (`shell.qml`).
    required property bool live

    readonly property bool vertical: DockService.vertical
    readonly property string edge: DockService.edge

    // Where the capsule is, in the surface's own coordinates.
    readonly property var box: DockService.box(root.width, root.height)

    // ── AUTOHIDE ────────────────────────────────────────────────────────────
    //
    // One 0–1 progress drives both the capsule's position and the mask, so the
    // mask never lags a frame behind.
    property bool peeked: false

    readonly property bool out: !DockService.autohide || root.peeked
        || DockService.dragging !== "" || root.menuItem !== null

    property real slide: root.out ? 0 : 1

    Behavior on slide {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    readonly property real offsetX: root.slide * DockService.hiddenX
    readonly property real offsetY: root.slide * DockService.hiddenY

    // The gap between the capsule and the edge, added to the input region while
    // hidden, so moving from the trigger strip to the capsule is not leaving.
    readonly property real bridge: DockService.autohide ? Theme.dockMargin : 0

    readonly property Timer retract: Timer {
        // Long enough to cross the gap.
        interval: 350
        onTriggered: root.peeked = false
    }

    // ── SURFACE ─────────────────────────────────────────────────────────────

    // Anchored to three edges: a layer surface anchored to fewer cannot claim
    // an exclusive zone.
    anchors {
        left: !root.vertical || root.edge === "left"
        right: !root.vertical || root.edge === "right"
        top: root.vertical
        bottom: true
    }

    // Always the whole available area, so a menu taller than the dock can be
    // drawn without resizing. The bar's exclusive zone is already taken out.
    implicitWidth: root.screen.width
    implicitHeight: root.screen.height

    WlrLayershell.namespace: "impasto-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // It never reserves: windows pass under it, and the desktop keeps its
    // grid clear of it on its own (`DockService.zone`). A reserved band would
    // have to appear and go with the dock, re-tiling every window on both
    // screens every time a hand crossed.
    exclusiveZone: 0

    color: "transparent"

    // Hidden when empty and under fullscreen windows on its own screen. With
    // the launcher button it is never empty. Set to one dock, it is drawn only
    // on the screen being worked on; it reserves nothing either way, so a
    // crossing moves no window.
    visible: DockService.shownOn(root.screenName)
        && (DockService.everywhere || root.live)

    // ── CONTEXT MENU ────────────────────────────────────────────────────────
    //
    // Tracked by key, not by index: `items` is rebuilt whenever a window opens
    // or closes. The menu closes itself when its item goes away.
    property string menuKey: ""

    readonly property int menuIndex:
        DockService.items.findIndex(item => item.key === root.menuKey)

    readonly property var menuItem:
        root.menuIndex >= 0 ? DockService.items[root.menuIndex] : null

    function openMenu(key: string): void {
        root.menuKey = root.menuKey === key ? "" : key
    }

    function closeMenu(): void {
        root.menuKey = ""
    }

    // The capsule's current rect, extended to the screen edge while hidden,
    // plus the trigger strip. Read off the capsule so the region follows it
    // mid-animation; an input region costs nothing to update.
    //
    // The whole surface while a menu is open, so a click elsewhere closes it.
    // The menu is not a second surface: same-layer surfaces stack in creation
    // order, so one created on demand would sit above the dock and take its
    // clicks.
    //
    // Empty while the desktop is being arranged, so a widget dragged across the
    // dock does not hand it the pointer.
    mask: Region {
        x: root.menuItem ? 0 : shelf.x - (root.edge === "left" ? root.bridge : 0)
        y: root.menuItem ? 0 : shelf.y
        width: DesktopService.editing ? 0 : (root.menuItem ? root.width
            : shelf.width + (root.vertical ? root.bridge : 0))
        height: DesktopService.editing ? 0 : (root.menuItem ? root.height
            : shelf.height + (root.vertical ? 0 : root.bridge))
        regions: DockService.autohide && !root.menuItem && !DesktopService.editing ? [sliver] : []
    }

    Region {
        id: sliver

        x: root.edge === "right" ? root.width - Theme.dockReveal : 0
        y: root.edge === "bottom" ? root.height - Theme.dockReveal : 0
        width: root.vertical ? Theme.dockReveal : root.width
        height: root.vertical ? root.height : Theme.dockReveal
    }

    // Input only arrives inside the mask, so one handler over the surface
    // covers exactly the dock.
    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hover.hovered) {
                root.retract.stop()
                root.peeked = true
                return
            }
            root.retract.restart()
        }
    }

    // Closes an open menu on any click outside it. A MouseArea, because the
    // click must be consumed.
    MouseArea {
        anchors.fill: parent
        enabled: root.menuItem !== null
        acceptedButtons: Qt.AllButtons
        onPressed: root.closeMenu()
    }

    // ── CAPSULE ─────────────────────────────────────────────────────────────

    // Not `id: capsule`: the delegates' `capsule` property would shadow it, and
    // `capsule: capsule` would hand each item itself.
    Item {
        id: shelf

        // The hovered icon's index, set by the items. The name label is drawn
        // here, because it has to sit above the neighbours and outside the
        // capsule.
        property int hoveredIndex: -1

        x: root.box.x + root.offsetX
        y: root.box.y + root.offsetY
        width: root.box.width
        height: root.box.height

        // Animate the length as applications open and close.
        Behavior on width {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        Behavior on height {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        // The same shadow, and the same switch, as the bar and the windows: a
        // blurred copy grown by `shadowSpread`, so the falloff's midpoint sits
        // outside the capsule. The Loader sizes it to the capsule plus the
        // shadow's reach, since a layer effect is clipped to its item.
        Loader {
            anchors.fill: parent
            anchors.margins: -Theme.shadowBarRange
            active: SettingsService.windowShadow
            sourceComponent: caster
        }

        // The island's black; with lower opacity the compositor's blur shows
        // through. The border keeps its own alpha, so a translucent capsule
        // still has an edge.
        Rectangle {
            anchors.fill: parent
            radius: Theme.dockRadius
            color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b,
                           SettingsService.dockOpacity / 100)
            border.color: Theme.islandBorder
            border.width: 1
        }

        // ── LAUNCHER BUTTON ─────────────────────────────────────────────
        //
        // Not a DockItem: no windows, dot, pinning or drag. It requests the
        // launcher through `shell.qml` rather than opening it.
        Item {
            id: launcher

            visible: DockService.hasLauncher
            width: Theme.dockIcon
            height: Theme.dockIcon

            x: root.vertical ? Theme.dockPadding : DockService.launcherOffset
            y: root.vertical ? DockService.launcherOffset : Theme.dockPadding

            readonly property bool hovered: launcherHover.hovered

            scale: launcher.hovered ? Theme.dockLift : 1

            Behavior on scale {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: Theme.radiusMedium
                color: Theme.islandSurfaceHover
                opacity: launcher.hovered ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "󰀻"
                font.family: Theme.fontMono
                font.pixelSize: Math.round(Theme.dockIcon * 0.58)
                color: Theme.text
            }

            HoverHandler {
                id: launcherHover

                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (launcherHover.hovered)
                        shelf.hoveredIndex = DockService.launcherIndex
                    else if (shelf.hoveredIndex === DockService.launcherIndex)
                        shelf.hoveredIndex = -1
                }
            }

            TapHandler {
                onSingleTapped: {
                    root.closeMenu()
                    root.launcherRequested()
                }
            }
        }

        Repeater {
            model: DockService.items

            DockItem {
                capsule: shelf
                onMenuRequested: key => root.openMenu(key)
            }
        }

        // The separator after the launcher button.
        Rectangle {
            visible: DockService.hasLauncher && DockService.count > 0
            color: Theme.hairline

            readonly property real along:
                DockService.launcherOffset + Theme.dockIcon + Theme.dockGap

            width: root.vertical ? Math.round(Theme.dockIcon * 0.5) : 1
            height: root.vertical ? 1 : Math.round(Theme.dockIcon * 0.5)

            x: root.vertical ? (shelf.width - width) / 2 : along
            y: root.vertical ? along : (shelf.height - height) / 2
        }

        // The separator between pinned and unpinned applications, only when
        // both exist.
        Rectangle {
            readonly property real along:
                DockService.offsetOf(DockService.pinnedCount - 1)
                    + Theme.dockIcon + Theme.dockGap

            visible: DockService.divides
            color: Theme.hairline

            width: root.vertical ? Math.round(Theme.dockIcon * 0.5) : 1
            height: root.vertical ? 1 : Math.round(Theme.dockIcon * 0.5)

            x: root.vertical ? (shelf.width - width) / 2 : along
            y: root.vertical ? along : (shelf.height - height) / 2
        }
    }

    Component {
        id: caster

        // `layer.effect` replaces this item's rendering, so only the blurred
        // shape reaches the screen. The copy is grown by `shadowSpread` so the
        // falloff sits outside the capsule.
        Item {
            opacity: Theme.shadowOpacity

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: Theme.shadowBarRange - Theme.shadowBarSpread
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.shadowBarRange - Theme.shadowBarSpread
                radius: Theme.dockRadius + Theme.shadowBarSpread
                color: Theme.shadowColor
            }
        }
    }

    // ── TOOLTIP ─────────────────────────────────────────────────────────────
    //
    // The hovered icon's name, on the inner side of the capsule: above it on
    // the bottom edge, beside it on the sides. Placed with the icon's
    // arithmetic and clamped to the screen.
    Item {
        id: label

        // The index the label draws, kept apart from the hovered one and only
        // updated when there is a new target. During the fade-out it keeps the
        // last name; an empty name would collapse the box and slide it to the
        // left edge.
        property int shownIndex: -1

        readonly property Connections handover: Connections {
            target: shelf

            function onHoveredIndexChanged(): void {
                if (shelf.hoveredIndex !== -1)
                    label.shownIndex = shelf.hoveredIndex
            }
        }

        readonly property bool onLauncher:
            label.shownIndex === DockService.launcherIndex

        readonly property var item: label.shownIndex >= 0
            && label.shownIndex < DockService.count
            ? DockService.items[label.shownIndex] : null

        readonly property string text: label.onLauncher
            ? Tr.t("Applications") : (label.item ? label.item.name : "")

        readonly property real centre: label.onLauncher
            ? DockService.launcherOffset + Theme.dockIcon / 2
            : (label.shownIndex < 0 ? 0
                : DockService.offsetOf(DockService.shifted(label.shownIndex))
                    + Theme.dockIcon / 2)

        implicitWidth: plate.width
        implicitHeight: plate.height
        width: implicitWidth
        height: implicitHeight

        x: root.vertical
            ? (root.edge === "left"
                ? shelf.x + shelf.width + Theme.dockGap
                : shelf.x - width - Theme.dockGap)
            : Math.max(Theme.dockMargin,
                Math.min(root.width - width - Theme.dockMargin,
                         shelf.x + centre - width / 2))

        y: root.vertical
            ? Math.max(Theme.dockMargin,
                Math.min(root.height - height - Theme.dockMargin,
                         shelf.y + centre - height / 2))
            : shelf.y - height - Theme.dockGap

        // Hidden while dragging or while a menu is open. Visibility follows the
        // live hover; only the text uses the held index.
        opacity: shelf.hoveredIndex !== -1 && label.text !== "" && root.out
            && DockService.dragging === "" && !root.menuItem ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        Rectangle {
            id: plate

            width: name.implicitWidth + 20
            height: name.implicitHeight + 12
            radius: Theme.radiusMedium
            color: Theme.island
            border.color: Theme.islandBorder
            border.width: 1

            Text {
                id: name

                anchors.centerIn: parent
                text: label.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }
    }

    // ── MENU ────────────────────────────────────────────────────────────────
    //
    // Loaded on open and placed like the label: on the inner side of the
    // capsule, aligned with its icon, clamped to the screen. Its height is why
    // the surface covers the screen.
    Loader {
        id: menu

        readonly property real centre: root.menuIndex < 0 ? 0
            : DockService.offsetOf(DockService.shifted(root.menuIndex))
                + Theme.dockIcon / 2

        active: root.menuItem !== null

        x: root.vertical
            ? (root.edge === "left"
                ? shelf.x + shelf.width + Theme.dockGap
                : shelf.x - width - Theme.dockGap)
            : Math.max(Theme.dockMargin,
                Math.min(root.width - width - Theme.dockMargin,
                         shelf.x + centre - width / 2))

        y: root.vertical
            ? Math.max(Theme.dockMargin,
                Math.min(root.height - height - Theme.dockMargin,
                         shelf.y + centre - height / 2))
            : shelf.y - height - Theme.dockGap

        sourceComponent: DockMenu {
            item: root.menuItem
            onClosed: root.closeMenu()
        }
    }
}
