// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L O C K                                                              │
// │   control centre block · placement and dragging                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import Quickshell
import "../../../theme"
import "../../../services"

// One block on the control centre grid: position, size, face, and the drag
// that moves it while arranging. Draws nothing itself; the face is already a
// card.
//
// Built once per key and reading its row from the service, so a drop or a
// resize reshapes it in place instead of rebuilding it (a player keeps
// playing, a list keeps its scroll).
Item {
    id: root

    required property string modelData

    // Named `board` because a property would shadow the container's `surface`
    // id.
    required property Item board

    signal panelRequested(string panel)
    signal settingsRequested()
    signal dismissed()

    readonly property string key: root.modelData

    // Null briefly after the row is removed, before the Repeater destroys the
    // delegate.
    readonly property var block: ControlsService.entryOf(root.key)
    readonly property string blockId: root.block ? root.block.id : ""
    readonly property string size: ControlsService.sizeOf(root.block)
    readonly property var box: root.block
        ? ControlsService.geometry(root.block)
        : ({ x: 0, y: 0, width: 0, height: 0 })

    readonly property bool editing: ControlsService.editing
    readonly property bool held: ControlsService.dragging === root.key
    readonly property bool selected: ControlsService.selected === root.key
    readonly property bool hovered: hover.hovered

    width: root.box.width
    height: root.box.height
    // Moved to the sliders drawer, except while arranging, so they can still
    // be placed.
    readonly property bool moved: SettingsService.slidersPlacement === "side" && !root.editing
        && (root.blockId === "volume" || root.blockId === "brightness")
    visible: root.block !== null && !root.moved

    // Dragging assigns x and y directly, which would break a plain binding, so
    // the grid position is a Binding disabled while held.
    Binding {
        target: root
        property: "x"
        value: root.box.x
        when: !drag.active
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: root
        property: "y"
        value: root.box.y
        when: !drag.active
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Animates the snap to the nearest cell after a drop or resize.
    Behavior on x {
        enabled: !drag.active
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Behavior on y {
        enabled: !drag.active
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Behavior on width {
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Behavior on height {
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    // The held block draws above the others, and the selected one above the
    // rest, so its outline isn't cut by a neighbour.
    z: root.held ? 2 : (root.selected ? 1 : 0)

    // Disabled while arranging so a drag can't also press a button. `enabled`
    // rather than an overlay, which would swallow the drag too.
    BlockFace {
        anchors.fill: parent
        active: root.block !== null
        blockId: root.blockId
        blockKey: root.key
        size: root.size
        enabled: !root.editing
        onPanelRequested: panel => root.panelRequested(panel)
        onSettingsRequested: root.settingsRequested()
        onDismissed: root.dismissed()
    }

    // ── ARRANGING ───────────────────────────────────────────────────────────
    //
    // Inactive outside editing mode.

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        visible: root.editing
        radius: Theme.radiusMedium + 3
        color: "transparent"
        border.color: root.held || root.selected ? Theme.accent : Theme.hairline
        border.width: root.held || root.selected ? 2 : 1
    }

    // Click to select and open the inspector. Declared before the drag so a
    // press that moves goes to the drag; exclusive so the ground's tap doesn't
    // close it.
    TapHandler {
        enabled: root.editing
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: ControlsService.selected = root.selected ? "" : root.key
    }

    DragHandler {
        id: drag

        enabled: root.editing && root.block !== null
        target: root
        xAxis.minimum: 0
        xAxis.maximum: Math.max(0, root.board.width - root.width)
        yAxis.minimum: 0
        yAxis.maximum: Math.max(0, root.board.height - root.height)

        onActiveChanged: {
            if (drag.active) {
                ControlsService.dragging = root.key
                ControlsService.selected = ""
                return
            }
            ControlsService.dragging = ""
            ControlsService.landing = null
            // Dropped on the tray, it is removed; otherwise `place` puts it in
            // the cell under the pointer, or the nearest free one, or back
            // where it was.
            const pointer = root.board.mapFromItem(
                null, drag.centroid.scenePosition.x, drag.centroid.scenePosition.y)
            if (ControlsService.overTray(pointer.x, pointer.y)) {
                ControlsService.remove(root.key)
                return
            }
            ControlsService.place(root.key,
                ControlsService.cellX(root.x), ControlsService.cellY(root.y))
        }
    }

    // Highlights the landing cell; none while over the tray.
    function aim(): void {
        if (!drag.active)
            return
        const pointer = root.board.mapFromItem(
            null, drag.centroid.scenePosition.x, drag.centroid.scenePosition.y)
        if (ControlsService.overTray(pointer.x, pointer.y)) {
            ControlsService.landing = null
            return
        }
        const spot = ControlsService.nearestFree(
            ControlsService.cellX(root.x), ControlsService.cellY(root.y),
            root.size, root.key)
        ControlsService.landing = spot
            ? { col: spot.col, row: spot.row, size: root.size } : null
    }

    onXChanged: root.aim()
    onYChanged: root.aim()

    // The wheel steps through the block's sizes, one step per notch and then a
    // pause; touchpads send an event per pixel.
    property real wheelSpent: 0

    WheelHandler {
        enabled: root.editing
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (wheelRest.running)
                return
            root.wheelSpent += event.angleDelta.y
            if (Math.abs(root.wheelSpent) < 120)
                return
            const step = root.wheelSpent < 0 ? 1 : -1
            root.wheelSpent = 0
            ControlsService.cycleSize(root.key, step)
            wheelRest.restart()
        }
    }

    Timer {
        id: wheelRest
        interval: 250
        onTriggered: root.wheelSpent = 0
    }

    HoverHandler {
        id: hover

        enabled: root.editing
        cursorShape: root.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    // ── BADGE AND HANDLE ────────────────────────────────────────────────────
    //
    // Shown on hover and on the selected block. The badge removes the block;
    // the handle resizes it, snapping between the sizes it offers.
    readonly property bool dressed: root.editing && !root.held && (root.hovered || root.selected)

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: -7
        anchors.topMargin: -7
        width: 20
        height: 20
        radius: 10
        color: Theme.island
        border.color: Theme.borderIn(QsWindow.window)
        border.width: 1
        visible: opacity > 0
        opacity: root.dressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 2
            radius: 1
            color: Theme.scrimText
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: ControlsService.remove(root.key)
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -7
        anchors.bottomMargin: -7
        width: 20
        height: 20
        radius: 10
        color: Theme.island
        border.color: resize.active ? Theme.accent : Theme.borderIn(QsWindow.window)
        border.width: resize.active ? 2 : 1
        visible: opacity > 0
        opacity: root.dressed || resize.active ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast }
        }

        Item {
            anchors.centerIn: parent
            width: 8
            height: 8

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 8
                height: 2
                radius: 1
                color: Theme.scrimText
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 2
                height: 8
                radius: 1
                color: Theme.scrimText
            }
        }

        HoverHandler { cursorShape: Qt.SizeFDiagCursor }

        // Claims the press before the drag: a drag whose passive grab is
        // overridden by an exclusive one loses the point.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        DragHandler {
            id: resize

            target: null

            onCentroidChanged: {
                if (!resize.active)
                    return
                const pointer = root.board.mapFromItem(null,
                    resize.centroid.scenePosition.x, resize.centroid.scenePosition.y)
                const cols = (pointer.x - root.box.x + Theme.centreGutter) / Theme.centreStrideX
                const rows = (pointer.y - root.box.y + Theme.centreGutter) / Theme.centreStrideY
                const next = ControlsService.sizeNearest(root.blockId, cols, rows)
                if (next !== root.size)
                    ControlsService.setSize(root.key, next)
            }
        }
    }
}
