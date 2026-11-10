// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D O C K   I T E M                                                      │
// │   one application on the dock · its icon, its dot and its drag           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"
import "../services"

// One application on the dock: the icon and a running dot. The position comes
// from DockService, so the name label can use the same arithmetic.
//
// Magnifying, the icon swells with its neighbours as the dock works out
// (`Dock.qml`); otherwise hovering lifts it slightly and nothing else moves.
Item {
    id: root

    required property var modelData
    required property int index

    // The capsule this sits in, passed in rather than reached through parents.
    required property Item capsule

    readonly property string key: root.modelData.key
    readonly property bool running: root.modelData.running
    readonly property bool active: root.modelData.active

    readonly property bool vertical: DockService.vertical
    readonly property string edge: DockService.edge

    // Only pinned applications can be reordered, and only among themselves.
    readonly property bool movable: root.modelData.pinned && DockService.pinnedCount > 1
    readonly property bool held: DockService.dragging === root.key

    readonly property bool hovered: hover.hovered

    // The menu has to draw outside the capsule and above the other icons, so
    // the request goes up to the dock.
    signal menuRequested(string key)

    readonly property int slot: root.index + (DockService.hasLauncher ? 1 : 0)
    readonly property real along: root.capsule.alongOf(root.slot,
        DockService.offsetOf(DockService.shifted(root.index)))

    width: Theme.dockIcon
    height: Theme.dockIcon

    z: root.held ? 2 : (root.hovered ? 1 : 0)

    // Dragging assigns x or y directly, which would break a plain binding, so
    // the binding is separate and disabled while held (as in Widget).
    Binding {
        target: root
        property: "x"
        value: root.vertical ? Theme.dockPadding : root.along
        when: !drag.active
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: root
        property: "y"
        value: root.vertical ? root.along : Theme.dockPadding
        when: !drag.active
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Animates the neighbours making room, and the held icon returning when the
    // drop changes nothing.
    Behavior on x {
        enabled: !drag.active && root.capsule.swell === 0
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Behavior on y {
        enabled: !drag.active && root.capsule.swell === 0
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    // ── ICON ────────────────────────────────────────────────────────────────

    Item {
        id: slot

        width: Theme.dockIcon
        height: Theme.dockIcon

        scale: SettingsService.dockMagnify
            ? root.capsule.scaleOf(root.slot)
            : (root.hovered || root.held ? Theme.dockLift : 1)
        transformOrigin: SettingsService.dockMagnify ? root.capsule.growFrom : Item.Center

        Behavior on scale {
            enabled: !SettingsService.dockMagnify
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        // Hover highlight, kept inside the gap between icons.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.radiusMedium
            color: Theme.veilHoverOf(Theme.dockStyle)
            opacity: (root.hovered || root.held) && !SettingsService.dockMagnify ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }
        }

        // The desktop entry's icon from the icon theme, falling back to the
        // launcher mark when it is missing.
        readonly property string iconSource: root.modelData.icon
            ? Theme.appIcon(root.modelData.icon) : ""

        Image {
            id: picture

            anchors.fill: parent
            anchors.margins: Theme.dockInset
            source: slot.iconSource
            sourceSize: Qt.size(Theme.dockIcon * 2, Theme.dockIcon * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            visible: slot.iconSource !== "" && status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !picture.visible
            text: "󰀻"
            font.family: Theme.fontMono
            font.pixelSize: Math.round((Theme.dockIcon - 2 * Theme.dockInset) * 0.6)
            color: Theme.textMuted
        }
    }

    // ── RUNNING INDICATOR ───────────────────────────────────────────────────
    //
    // A dot per window, up to three, so the count reads at a glance. The
    // accent for the focused application, muted when it is running but not
    // focused.
    Grid {
        id: dots

        readonly property int shown: Math.min(3, root.modelData.windows.length)

        rows: root.vertical ? dots.shown : 1
        columns: root.vertical ? 1 : dots.shown
        spacing: Theme.dockDot - 1

        // Centred between the drawn icon and the rim on the screen-edge side.
        readonly property real room: Theme.dockPadding + Theme.dockInset

        x: root.edge === "right"
            ? root.width - Theme.dockInset + (room - width) / 2
            : (root.edge === "left"
                ? Theme.dockInset - (room + width) / 2
                : (root.width - width) / 2)
        y: root.edge === "bottom"
            ? root.height - Theme.dockInset + (room - height) / 2
            : (root.height - height) / 2

        opacity: root.running ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        Repeater {
            model: dots.shown

            Rectangle {
                required property int index

                // Hollow for a minimized window.
                readonly property bool away: root.modelData.windows[index]?.minimized ?? false

                width: Theme.dockDot
                height: Theme.dockDot
                radius: Theme.radiusPill
                color: away ? "transparent" : root.active ? Theme.accent : Theme.textMuted
                border.width: away ? 1 : 0
                border.color: Theme.textMuted

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }
        }
    }

    // ── INPUT ───────────────────────────────────────────────────────────────

    // The grown icon and half the gap either side answer the pointer, so
    // swollen icons leave no dead space between them; across the dock it
    // reaches out by the growth, away from the screen edge.
    containmentMask: Item {
        readonly property real span: Theme.dockIcon * slot.scale + Theme.dockGap
        readonly property real grown: Theme.dockIcon * Math.max(0, slot.scale - 1)
        readonly property real before: root.edge === "left" ? 0 : grown

        parent: root
        x: root.vertical ? -Theme.dockPadding - before : (root.width - span) / 2
        y: root.vertical ? (root.height - span) / 2 : -Theme.dockPadding - before
        width: root.vertical ? Theme.dockThickness + grown : span
        height: root.vertical ? span : Theme.dockThickness + grown
    }

    HoverHandler {
        id: hover

        cursorShape: root.held ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        // The next item can be entered before this one is left, so only clear
        // the hover if it still points here.
        onHoveredChanged: {
            if (hover.hovered)
                root.capsule.hoveredIndex = root.index
            else if (root.capsule.hoveredIndex === root.index)
                root.capsule.hoveredIndex = -1
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        // A drag takes the grab, so a press that moved never arrives as a tap.
        onSingleTapped: (point, button) => {
            if (button === Qt.RightButton) {
                root.menuRequested(root.key)
                return
            }
            if (button === Qt.MiddleButton) {
                DockService.launch(root.modelData)
                return
            }
            DockService.activate(root.modelData)
        }
    }

    DragHandler {
        id: drag

        enabled: root.movable
        target: root

        // Constrained to the dock's axis.
        xAxis.enabled: !root.vertical
        yAxis.enabled: root.vertical
        xAxis.minimum: 0
        xAxis.maximum: Math.max(0, root.capsule.width - root.width)
        yAxis.minimum: 0
        yAxis.maximum: Math.max(0, root.capsule.height - root.height)

        onActiveChanged: {
            if (drag.active) {
                DockService.beginDrag(root.key, root.index)
                return
            }
            DockService.endDrag()
        }

    }

    // Tracked live while dragging, so the others make room. Uses the position
    // rather than the handler's translation, because the drop reads the
    // position. Saved only on drop.
    onXChanged: root.track()
    onYChanged: root.track()

    function track(): void {
        if (!drag.active)
            return
        DockService.dropAt = DockService.slotAt(
            (root.vertical ? root.y : root.x) + Theme.dockIcon / 2)
    }
}
