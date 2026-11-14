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
import "../components"

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
    CornerGuard {}

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
        || (DockService.dodges && !DockService.busyOn(root.screenName))
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

    // ── MAGNIFICATION ───────────────────────────────────────────────────────
    //
    // The icons near the pointer swell and push their neighbours apart, and
    // the capsule grows to hold them. All of it is worked out from where the
    // pointer is over the capsule at rest, never over the grown one, so an icon
    // moving never moves what it is measured against. Off while dragging,
    // while a menu is open and while the desk is being arranged.
    readonly property bool magnifying: SettingsService.dockMagnify && hover.hovered
        && DockService.dragging === "" && root.menuItem === null
        && !DesktopService.editing

    // Where the pointer is along the capsule at rest. Kept when it leaves, so
    // the icons settle back from where they were.
    property real pointer: 0

    Binding {
        target: root
        property: "pointer"
        value: root.vertical
            ? hover.point.position.y - root.box.y
            : hover.point.position.x - root.box.x
        when: hover.hovered
        restoreMode: Binding.RestoreNone
    }

    // 0 at rest, 1 magnifying, eased so entering and leaving are not a jump.
    property real swell: root.magnifying ? 1 : 0

    Behavior on swell {
        NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
    }

    // Every slot's centre along the capsule at rest: the launcher button, then
    // the applications.
    readonly property var rest: {
        const centres = []
        if (DockService.hasLauncher)
            centres.push(DockService.launcherOffset + Theme.dockLauncher / 2)
        for (let i = 0; i < DockService.count; i++)
            centres.push(DockService.offsetOf(i) + Theme.dockIcon / 2)
        return centres
    }

    // How much each slot grows, as a fraction of the icon: a cosine bell
    // centred on the pointer.
    readonly property var gains: {
        const reach = Theme.dockReach * (Theme.dockIcon + Theme.dockGap)
        const top = (Theme.dockMagnify - 1) * root.swell
        return root.rest.map(centre => {
            const away = Math.abs(root.pointer - centre) / reach
            return away >= 1 ? 0 : top * (1 + Math.cos(Math.PI * away)) / 2
        })
    }

    // What the slots before each one have grown by, in pixels; the last entry
    // is the whole growth.
    readonly property var before: {
        const sums = [0]
        root.gains.forEach((gain, slot) =>
            sums.push(sums[slot] + gain * root.sizeOf(slot)))
        return sums
    }

    readonly property real grown: root.before[root.before.length - 1]

    // How far the capsule's start moves back: the growth on the pointer's near
    // side, so the icon under the pointer stays under it. An aligned dock
    // keeps its end against the margin instead.
    readonly property real backing: {
        if (DockService.alignment === "start")
            return 0
        if (DockService.alignment === "end")
            return root.grown
        let sum = 0
        root.gains.forEach((gain, slot) => {
            const size = root.sizeOf(slot)
            const start = root.rest[slot] - size / 2
            const past = (root.pointer - start) / size
            sum += gain * size * Math.max(0, Math.min(1, past))
        })
        return sum
    }

    // The scale an icon is drawn at grows away from the screen edge.
    readonly property int growFrom: root.edge === "left" ? Item.Left
        : (root.edge === "right" ? Item.Right : Item.Bottom)

    // How long a slot is along the capsule: the launcher's is narrower.
    function sizeOf(slot: int): real {
        return slot === 0 && DockService.hasLauncher ? Theme.dockLauncher : Theme.dockIcon
    }

    // The slot an index of `DockService.items` sits in, or the launcher's.
    function slotOf(index: int): int {
        if (index === DockService.launcherIndex)
            return 0
        return index + (DockService.hasLauncher ? 1 : 0)
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
    //
    // Magnifying, it reaches out by the growth, so a swollen icon takes the
    // pointer all the way to its far edge.
    readonly property real reach: root.magnifying
        ? Math.ceil(Theme.dockIcon * (Theme.dockMagnify - 1)) : 0

    mask: Region {
        x: root.menuItem ? 0 : shelf.x - (root.edge === "left" ? root.bridge : 0)
            - (root.edge === "right" ? root.reach : 0)
        y: root.menuItem ? 0 : shelf.y - (root.edge === "bottom" ? root.reach : 0)
        width: DesktopService.editing ? 0 : (root.menuItem ? root.width
            : shelf.width + (root.vertical ? root.bridge + root.reach : 0))
        height: DesktopService.editing ? 0 : (root.menuItem ? root.height
            : shelf.height + (root.vertical ? 0 : root.bridge + root.reach))
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

        readonly property real swell: root.swell
        readonly property int growFrom: root.growFrom

        // Where a slot resting at `rest` along the capsule is drawn, and the
        // scale it is drawn at.
        function alongOf(slot: int, rest: real): real {
            return rest + (root.before[slot] ?? 0)
                + root.sizeOf(slot) * (root.gains[slot] ?? 0) / 2
        }

        function scaleOf(slot: int): real {
            return 1 + (root.gains[slot] ?? 0)
        }

        x: root.box.x + root.offsetX - (root.vertical ? 0 : root.backing)
        y: root.box.y + root.offsetY - (root.vertical ? root.backing : 0)
        width: root.box.width + (root.vertical ? 0 : root.grown)
        height: root.box.height + (root.vertical ? root.grown : 0)

        // Animate the length as applications open and close; magnifying, it
        // follows the pointer.
        Behavior on width {
            enabled: root.swell === 0
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        Behavior on height {
            enabled: root.swell === 0
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        // The same shadow as the bar and the windows, on its own switch: a
        // blurred copy grown by `shadowSpread`, so the falloff's midpoint sits
        // outside the capsule. The Loader sizes it to the capsule plus the
        // shadow's reach, since a layer effect is clipped to its item.
        Loader {
            anchors.fill: parent
            anchors.margins: -Theme.shadowBarRange
            active: Theme.dockShadowShown
            sourceComponent: caster
        }

        // Classic is the island's black, at the Background setting's opacity
        // over the compositor's blur; glass is the terminal's ground, with
        // its lit edge. The border keeps its own alpha, so a translucent
        // capsule still has an edge.
        Rectangle {
            id: ground

            anchors.fill: parent
            radius: Theme.dockRadius
            color: Theme.groundAt(Theme.dockStyle, SettingsService.dockOpacity / 100)
            border.color: Theme.rimOf(Theme.dockStyle)
            border.width: 1

            GlassSheen {
                shape: ground
                style: Theme.dockStyle
                visible: Theme.dockGlass
            }
        }

        // ── LAUNCHER BUTTON ─────────────────────────────────────────────
        //
        // Not a DockItem: no windows, dot, pinning or drag. It requests the
        // launcher through `shell.qml` rather than opening it.
        Item {
            id: launcher

            visible: DockService.hasLauncher
            width: root.vertical ? Theme.dockIcon : Theme.dockLauncher
            height: root.vertical ? Theme.dockLauncher : Theme.dockIcon

            readonly property real along: shelf.alongOf(0, DockService.launcherOffset)

            x: root.vertical ? Theme.dockPadding : launcher.along
            y: root.vertical ? launcher.along : Theme.dockPadding

            readonly property bool hovered: launcherHover.hovered

            scale: SettingsService.dockMagnify
                ? shelf.scaleOf(0) : (launcher.hovered ? Theme.dockLift : 1)
            transformOrigin: SettingsService.dockMagnify ? root.growFrom : Item.Center

            Behavior on scale {
                enabled: !SettingsService.dockMagnify
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }

            // The grown icon and half the gap either side answer the pointer,
            // so swollen icons leave no dead space between them.
            containmentMask: Item {
                readonly property real span: Theme.dockLauncher * launcher.scale + Theme.dockGap

                parent: launcher
                x: root.vertical ? -Theme.dockPadding : (launcher.width - span) / 2
                y: root.vertical ? (launcher.height - span) / 2 : -Theme.dockPadding
                width: root.vertical ? Theme.dockThickness : span
                height: root.vertical ? span : Theme.dockThickness
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: Theme.radiusMedium
                color: Theme.veilHoverOf(Theme.dockStyle)
                opacity: launcher.hovered && !SettingsService.dockMagnify ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }
            }

            // Nudged toward the divider by half of what the room before it
            // loses, to the padding being narrower than the gap and to the
            // capsule's lit edge, so the room either side looks even.
            readonly property real nudge: (Theme.dockGap - Theme.dockPadding
                + (Theme.dockGlass ? 4 : 1)) / 2

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: root.vertical ? 0 : launcher.nudge
                anchors.verticalCenterOffset: root.vertical ? launcher.nudge : 0
                text: "󰀻"
                font.family: Theme.fontMono
                font.pixelSize: Math.round((Theme.dockIcon - 2 * Theme.dockInset) * 0.58)
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
            model: ScriptModel {
                values: DockService.items
                objectProp: "key"
            }

            DockItem {
                capsule: shelf
                onMenuRequested: key => root.openMenu(key)
            }
        }

        // The separator after the launcher button.
        Rectangle {
            visible: DockService.hasLauncher && DockService.count > 0
            color: Theme.hairline

            readonly property real along: DockService.launcherOffset
                + Theme.dockLauncher + Theme.dockGap + (root.before[1] ?? 0)

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
                    + (root.before[root.slotOf(DockService.pinnedCount)] ?? 0)

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

        readonly property int slot: root.slotOf(label.shownIndex)

        readonly property real centre: label.onLauncher
            ? shelf.alongOf(0, DockService.launcherOffset) + Theme.dockLauncher / 2
            : (label.shownIndex < 0 ? 0
                : shelf.alongOf(label.slot,
                    DockService.offsetOf(DockService.shifted(label.shownIndex)))
                    + Theme.dockIcon / 2)

        // Clear of the icon however far it has grown out of the capsule.
        readonly property real clear: Theme.dockGap
            + Theme.dockIcon * (root.gains[label.slot] ?? 0)

        implicitWidth: plate.width
        implicitHeight: plate.height
        width: implicitWidth
        height: implicitHeight

        x: root.vertical
            ? (root.edge === "left"
                ? shelf.x + shelf.width + label.clear
                : shelf.x - width - label.clear)
            : Math.max(Theme.dockMargin,
                Math.min(root.width - width - Theme.dockMargin,
                         shelf.x + centre - width / 2))

        y: root.vertical
            ? Math.max(Theme.dockMargin,
                Math.min(root.height - height - Theme.dockMargin,
                         shelf.y + centre - height / 2))
            : shelf.y - height - label.clear

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
            color: Theme.groundOf(Theme.dockStyle)
            border.color: Theme.rimOf(Theme.dockStyle)
            border.width: 1

            GlassSheen {
                shape: plate
                style: Theme.dockStyle
                visible: Theme.dockGlass
            }

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
