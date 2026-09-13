// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W   I   D   G   E   T                                                  │
// │   one module on the wallpaper · one square of the grid                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects

import "../theme"
import "../services"

// One module on the desktop grid, in one of the four families.
//
// Knows nothing about modules: Face picks the content, the family sets the size
// and the grid the position, all known up front, so the widget has the right
// size on its first frame. Built once per key and reads its row from the
// service, so moves and resizes do not recreate it and a playing track survives
// a drag.
Item {
    id: root

    // The row key, from the surface's Repeater over `DesktopService.keys`.
    required property string modelData

    // The surface the grid is measured against, passed in rather than found
    // through parents. The container's id is `surface` because a property
    // shadows an id of the same name.
    required property Item board

    readonly property string key: root.modelData

    // Briefly null between the row's removal and the delegate's destruction.
    readonly property var row: DesktopService.entryOf(root.key)

    readonly property string moduleId: root.row ? root.row.id : ""
    readonly property string family: DesktopService.familyOf(root.row)
    readonly property string style: DesktopService.styleOf(root.row)
    readonly property var ink: DesktopService.inkFor(root.row)
    readonly property real solidity: DesktopService.opacityOf(root.row) / 100

    readonly property var box: DesktopService.geometry(
        root.row ?? ({}), root.board.width, root.board.height)

    readonly property bool editing: DesktopService.editing
    readonly property bool held: DesktopService.dragging === root.key
    readonly property bool selected: DesktopService.selected === root.key
    readonly property bool hovered: hover.hovered

    // Two of the four styles draw a capsule; the other two draw on the
    // wallpaper with a shadow.
    readonly property bool onPicture: root.style === "bare" || root.style === "outline"

    width: root.box.width
    height: root.box.height

    // The grid position, until a drag moves it. Dragging assigns x and y
    // directly, which would break a plain binding, so the binding is declared
    // separately and disabled while held.
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

    // Snaps to the nearest cell on release. Disabled while held so it does not
    // chase the pointer. Family changes animate the same way.
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

    // The held widget above all, then the selected one, so the inspector's
    // badge is not hidden by a neighbour.
    z: root.held ? 2 : (root.selected ? 1 : 0)

    // ── CAPSULE ─────────────────────────────────────────────────────────────
    //
    // The island's black unless the desktop or the row sets another ink; the
    // accent style paints it in the accent. The border keeps its own alpha, so
    // a translucent capsule still has an edge.
    Rectangle {
        anchors.fill: parent
        visible: !root.onPicture
        radius: Theme.desktopRadius
        color: Qt.rgba(root.ink.ground.r, root.ink.ground.g, root.ink.ground.b,
                       root.solidity)
        border.color: root.ink.border
        border.width: root.style === "accent" ? 0 : 1

        Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
    }

    // Outline style: the edge only, in the text colour so it reads on the
    // wallpaper.
    Rectangle {
        anchors.fill: parent
        visible: root.style === "outline"
        radius: Theme.desktopRadius
        color: "transparent"
        border.color: Qt.rgba(root.ink.text.r, root.ink.text.g, root.ink.text.b, 0.55)
        border.width: 1.5
    }

    // Disabled while arranging so dragging does not press buttons. `enabled`
    // rather than an overlay item, which would take the drag as well.
    Face {
        anchors.fill: parent
        moduleId: root.moduleId
        family: root.family
        theme: DesktopService.themeOf(root.row)
        ink: root.ink
        row: root.row
        enabled: !root.editing
    }

    // Without a capsule the contents get a drop shadow to stay readable on the
    // wallpaper. `layer.enabled` rather than a MultiEffect `source`: a
    // Repeater's delegate never renders into another item's source.
    layer.enabled: root.onPicture
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 1
        shadowOpacity: 0.6
        shadowVerticalOffset: 2
        shadowColor: Theme.island
    }

    // ── ARRANGING ───────────────────────────────────────────────────────────
    //
    // All inactive outside arranging except the right button, which enters it;
    // otherwise pressing a widget's pause button could move it.

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        visible: root.editing
        radius: Theme.desktopRadius + 3
        color: "transparent"
        border.color: root.held || root.selected ? Theme.accent : Theme.hairline
        border.width: root.held || root.selected ? 2 : 1
    }

    // At rest the right button opens the widget menu (Edit, Remove, and Open
    // for a note) at the pointer; the background draws it.
    TapHandler {
        enabled: !root.editing
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: eventPoint => {
            const point = root.board.mapFromItem(null,
                eventPoint.scenePosition.x, eventPoint.scenePosition.y)
            DesktopService.openMenu(root.key, point.x, point.y)
        }
    }

    // A click while arranging selects the widget and opens its inspector.
    // Declared before the drag, so a press that moves becomes the drag's.
    // Exclusive from the press, or the background's tap also fires and closes
    // the inspector; the drag can still take over.
    TapHandler {
        enabled: root.editing
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: DesktopService.selected = root.selected ? "" : root.key
    }

    DragHandler {
        id: drag

        enabled: root.editing
        target: root
        xAxis.minimum: 0
        xAxis.maximum: Math.max(0, root.board.width - root.width)
        yAxis.minimum: 0
        yAxis.maximum: Math.max(0, root.board.height - root.height)

        onActiveChanged: {
            if (drag.active) {
                DesktopService.dragging = root.key
                DesktopService.selected = ""
                return
            }
            DesktopService.dragging = ""
            DesktopService.landing = null
            DeckService.receiving = ""
            // Dropped on the tray, it is removed; a note dropped on a screen
            // edge joins that edge's deck; otherwise it goes to the cell under
            // the pointer. `place` falls back to the nearest free cell or the
            // original one, and the binding above moves it there.
            const pointer = root.board.mapFromItem(
                null, drag.centroid.scenePosition.x, drag.centroid.scenePosition.y)
            if (DesktopService.overTray(pointer.x, pointer.y)) {
                DesktopService.remove(root.key)
                return
            }
            const edge = root.edgeUnder(pointer.x, pointer.y)
            if (edge !== "") {
                DesktopService.noteToEdge(root.key, edge)
                return
            }
            DesktopService.place(root.key,
                DesktopService.cellX(root.x), DesktopService.cellY(root.y))
        }
    }

    // A note held against a screen edge is headed for that edge's deck; the
    // deck's surface highlights it.
    function edgeUnder(x: real, y: real): string {
        if (root.moduleId !== "notes")
            return ""
        return DeckService.edgeAt(x, y, root.board.width, root.board.height)
    }

    // Shows the landing cell while dragging. None over the tray (removal) or
    // over an edge (leaves the grid).
    function aim(): void {
        if (!drag.active)
            return
        const pointer = root.board.mapFromItem(
            null, drag.centroid.scenePosition.x, drag.centroid.scenePosition.y)
        if (DesktopService.overTray(pointer.x, pointer.y)) {
            DesktopService.landing = null
            DeckService.receiving = ""
            return
        }
        const edge = root.edgeUnder(pointer.x, pointer.y)
        if (edge !== "") {
            DesktopService.landing = null
            DeckService.receiving = edge
            return
        }
        DeckService.receiving = ""
        const spot = DesktopService.nearestFree(
            DesktopService.cellX(root.x), DesktopService.cellY(root.y),
            root.family, root.key)
        DesktopService.landing = spot
            ? { col: spot.col, row: spot.row, family: root.family } : null
    }

    onXChanged: root.aim()
    onYChanged: root.aim()

    // The wheel cycles through the module's families, as in the control centre.
    // One step per notch with a cooldown: touchpads send an event per pixel.
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
            DesktopService.cycleFamily(root.key, step)
            wheelRest.restart()
        }
    }

    Timer {
        id: wheelRest
        interval: 250
        onTriggered: root.wheelSpent = 0
    }

    // A grab cursor while it can be moved.
    HoverHandler {
        id: hover

        enabled: root.editing
        cursorShape: root.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    // ── BADGE AND HANDLE ────────────────────────────────────────────────────
    //
    // Shown only on the hovered or selected widget. The badge removes it; the
    // handle in the opposite corner resizes it.
    readonly property bool dressed: root.editing && !root.held && (root.hovered || root.selected)

    Rectangle {
        id: badge

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: -8
        anchors.topMargin: -8
        width: 24
        height: 24
        radius: 12
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1
        visible: opacity > 0
        opacity: root.dressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 2
            radius: 1
            color: Theme.scrimText
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: DesktopService.remove(root.key)
        }
    }

    // Dragging the handle picks the family whose box, in cells from the
    // widget's top left, is closest to the pointer. The face only changes at
    // those steps; a widget never stretches.
    Rectangle {
        id: handle

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -8
        anchors.bottomMargin: -8
        width: 24
        height: 24
        radius: 12
        color: Theme.island
        border.color: resize.active ? Theme.accent : Theme.islandBorder
        border.width: resize.active ? 2 : 1
        visible: opacity > 0
        opacity: root.dressed || resize.active ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast }
        }

        // A corner bracket, the mark iOS puts on a resizable widget.
        Item {
            anchors.centerIn: parent
            width: 10
            height: 10

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 10
                height: 2
                radius: 1
                color: Theme.scrimText
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 2
                height: 10
                radius: 1
                color: Theme.scrimText
            }
        }

        HoverHandler { cursorShape: Qt.SizeFDiagCursor }

        // Takes an exclusive grab on press, before the drag below, so the
        // widget's own tap handler does not. A drag whose passive grab came
        // before another handler's exclusive one is overridden, which would
        // turn a pull on the handle into a move. Declared first, so the drag
        // takes over this grab when the pointer moves.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        // Resizing does not select the widget.
        DragHandler {
            id: resize

            target: null

            onCentroidChanged: {
                if (!resize.active)
                    return
                const pointer = root.board.mapFromItem(null,
                    resize.centroid.scenePosition.x, resize.centroid.scenePosition.y)
                const cols = (pointer.x - root.box.x + Theme.desktopGutter) / DesktopService.stride
                const rows = (pointer.y - root.box.y + Theme.desktopGutter) / DesktopService.stride
                const next = DesktopService.familyNearest(
                    root.moduleId, cols, rows, DesktopService.themeOf(root.row))
                if (next !== root.family)
                    DesktopService.setFamily(root.key, next)
            }
        }
    }
}
