// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W   I   D   G   E   T                                                  │
// │   one module on the wallpaper · one square of the grid                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Effects

import "../theme"
import "../services"
import "../components"

// One module on the desktop grid, in one of the four families.
//
// Knows nothing about modules: Face picks the content, the family sets the size
// and the grid the position, all known up front, so the widget has the right
// size on its first frame. Built once per key and reads its row from the
// service, so moves and resizes do not recreate it and a playing track survives
// a drag.
Item {
    id: root

    // The row key, from the surface's Repeater over `DesktopService.keysOn`.
    required property string modelData

    // The surface the grid is measured against, passed in rather than found
    // through parents. The container's id is `surface` because a property
    // shadows an id of the same name.
    required property Item board

    // The screen this board is on, which a drag never leaves.
    required property string screenName

    readonly property string key: root.modelData

    // Briefly null between the row's removal and the delegate's destruction.
    readonly property var row: DesktopService.entryOf(root.key)

    readonly property string moduleId: root.row ? root.row.id : ""

    // A reading that polls keeps polling while a widget shows it, as a piece
    // on the bar does. Held by the id watched, since the row goes before the
    // delegate does.
    property string watching: ""

    function rewatch(): void {
        if (root.moduleId === "" || root.moduleId === root.watching)
            return
        if (root.watching !== "")
            ModuleService.watch(root.watching, false)
        root.watching = root.moduleId
        ModuleService.watch(root.watching, true)
    }

    onModuleIdChanged: root.rewatch()
    Component.onCompleted: root.rewatch()
    Component.onDestruction: {
        if (root.watching !== "")
            ModuleService.watch(root.watching, false)
    }
    readonly property string family: DesktopService.familyOf(root.row)
    readonly property var ink: DesktopService.inkFor(root.row)
    readonly property real solidity: DesktopService.opacityOf(root.row) / 100
    // The outline fades out over the last fifth, so at zero nothing of the
    // capsule is left but what it holds.
    readonly property color rim: Qt.rgba(root.ink.border.r, root.ink.border.g, root.ink.border.b,
                                         root.ink.border.a * Math.min(1, root.solidity * 5))

    // Notes, photos and the spectrum have no capsule and draw on the
    // wallpaper with a shadow.
    readonly property bool onPicture: DesktopService.bare(root.row)

    readonly property var box: DesktopService.geometry(
        root.row ?? ({}), root.board.width, root.board.height)

    readonly property bool editing: DesktopService.editing
    readonly property bool held: DesktopService.dragging === root.key
    readonly property bool selected: DesktopService.selected === root.key
    readonly property bool hovered: hover.hovered

    width: root.box.width
    height: root.box.height

    // The grid position, until a drag moves it. Dragging assigns x and y
    // directly, which would break a plain binding, so the binding is declared
    // separately and disabled while held.
    Binding {
        target: root
        property: "x"
        value: root.box.x + DesktopService.insets.left
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

    // ── SHADOW ──────────────────────────────────────────────────────────────
    //
    // At the windows' numbers, since a widget sits on the desk as a window
    // does; on its own setting (`widgetShadow`). Under a capsule that lets
    // the wallpaper through — glass, or solid below full opacity — the
    // capsule's own shape is cut out of it, so it falls outside and does not
    // show through.
    Item {
        id: cast

        readonly property int reach: Theme.shadowRange + 4
        readonly property bool cut: !Theme.deskSolid || root.solidity < 1

        visible: SettingsService.widgetShadow && !root.onPicture
            && (!Theme.deskSolid || root.solidity > 0)
        x: -cast.reach
        y: -cast.reach
        width: root.width + 2 * cast.reach
        height: root.height + 2 * cast.reach

        layer.enabled: cast.visible && cast.cut
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: cutout
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Item {
            anchors.fill: parent
            opacity: Theme.shadowOpacity

            layer.enabled: cast.visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: Theme.shadowRange - Theme.shadowSpread
            }

            Rectangle {
                x: cast.reach - Theme.shadowSpread
                y: cast.reach - Theme.shadowSpread
                width: root.width + 2 * Theme.shadowSpread
                height: root.height + 2 * Theme.shadowSpread
                radius: Theme.desktopRadius + Theme.shadowSpread
                color: Theme.shadowColor
            }
        }

        Item {
            id: cutout

            anchors.fill: parent
            visible: false
            layer.enabled: cast.cut

            Rectangle {
                x: cast.reach
                y: cast.reach
                width: root.width
                height: root.height
                radius: Theme.desktopRadius
            }
        }
    }

    // ── CAPSULE ─────────────────────────────────────────────────────────────

    // Without a capsule the contents get a drop shadow to stay readable on the
    // wallpaper. A sticker brings its own ground, so its shadow is the
    // widgets' shadow setting instead: the die-cut shape lifted off the
    // desk, at the windows' numbers. `layer.enabled` rather than a
    // MultiEffect `source`: a Repeater's delegate never renders into another
    // item's source. Not the spectrum, which is drawn as it is on an edge,
    // and whose layer would be drawn again on every one of cava's frames.
    readonly property bool sticker: DesktopService.themeOf(root.row) === "sticker"
        && root.moduleId !== "notes" && root.moduleId !== "spectrum"

    // The layer holds the ground and the face and nothing else, grown by
    // `reach` on every side: a layer is clipped to its item, and the arranging
    // outline, badge and handle sit outside the widget, as do the corners of
    // a tilted sticker.
    Item {
        id: body

        readonly property int reach: Theme.shadowRange

        anchors.fill: parent
        anchors.margins: -reach
        layer.enabled: root.sticker ? SettingsService.widgetShadow
            : root.onPicture && root.moduleId !== "spectrum"
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            blurMax: root.sticker ? Theme.shadowRange : 32
            shadowOpacity: root.sticker ? Theme.shadowOpacity : 0.6
            shadowVerticalOffset: root.sticker ? Theme.shadowSpread : 2
            shadowColor: Theme.island
        }

        Item {
            x: body.reach
            y: body.reach
            width: root.width
            height: root.height

            // The desk's ground (`Theme.deskStyle`, the bar's unless set apart):
            // solid black at the widget's opacity, or glass with its rim and edge. The border
            // keeps its own alpha, so a translucent capsule still has an edge.
            Rectangle {
                id: capsule

                anchors.fill: parent
                visible: !root.onPicture
                radius: Theme.desktopRadius
                color: Theme.deskSolid
                    ? Qt.rgba(root.ink.ground.r, root.ink.ground.g, root.ink.ground.b, root.solidity)
                    : Theme.groundOf(Theme.deskStyle)
                border.color: Theme.deskSolid ? root.rim : Theme.rimOf(Theme.deskStyle)
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
            }

            GlassSheen {
                shape: capsule
                visible: Theme.deskGlass && !root.onPicture
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
        }
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
            DesktopService.openMenu(root.key, root.screenName, point.x, point.y)
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

        // This board and no further. A widget belongs to the screen it was put
        // on, and the way to move one to another screen is to take it off here
        // and put it back there, where the card already is.
        xAxis.minimum: 0
        xAxis.maximum: Math.max(0, root.parent.width - root.width)
        yAxis.minimum: 0
        yAxis.maximum: Math.max(0, root.parent.height - root.height)

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
            // edge joins that edge's deck, and a spectrum becomes the bars
            // along it; otherwise it goes to the cell under the pointer. `place` falls back to the nearest free cell or the
            // original one, and the binding above moves it there.
            const pointer = root.board.mapFromItem(
                null, drag.centroid.scenePosition.x, drag.centroid.scenePosition.y)
            if (DesktopService.overTray(root.screenName, pointer.x, pointer.y)) {
                DesktopService.remove(root.key)
                return
            }
            const edge = root.edgeUnder(pointer.x, pointer.y)
            if (edge !== "" && root.moduleId === "spectrum") {
                DesktopService.spectrumToEdge(root.key, root.screenName, edge)
                return
            }
            if (edge !== "") {
                DesktopService.noteToEdge(root.key, root.screenName, edge)
                return
            }
            DesktopService.place(root.key, root.screenName,
                DesktopService.cellX(root.screenName, root.x - DesktopService.insets.left),
                DesktopService.cellY(root.screenName, root.y))
        }
    }

    // A note held against a screen edge is headed for that edge's deck, and
    // a spectrum for the bars along it when it has none; the deck's surface
    // highlights it.
    function edgeUnder(x: real, y: real): string {
        if (root.moduleId !== "notes" && root.moduleId !== "spectrum")
            return ""
        const edge = DesktopService.edgeAt(x, y, root.board.width, root.board.height)
        if (root.moduleId === "spectrum" && !DesktopService.spectrumTakes(root.screenName, edge))
            return ""
        return edge
    }

    // Shows the landing cell while dragging. None over the tray (removal) or
    // over an edge (leaves the grid).
    function aim(): void {
        if (!drag.active)
            return
        const pointer = root.board.mapFromItem(
            null, drag.centroid.scenePosition.x, drag.centroid.scenePosition.y)
        if (DesktopService.overTray(root.screenName, pointer.x, pointer.y)) {
            DesktopService.landing = null
            DeckService.receiving = ""
            return
        }
        const edge = root.edgeUnder(pointer.x, pointer.y)
        if (edge !== "") {
            DesktopService.landing = null
            DeckService.receivingScreen = root.screenName
            DeckService.receiving = edge
            return
        }
        DeckService.receiving = ""
        const spot = DesktopService.nearestFree(root.screenName,
            DesktopService.cellX(root.screenName, root.x - DesktopService.insets.left),
            DesktopService.cellY(root.screenName, root.y), root.family, root.key)
        DesktopService.landing = spot
            ? { screen: root.screenName, col: spot.col, row: spot.row, family: root.family } : null
    }

    onXChanged: root.aim()
    onYChanged: root.aim()

    // Dragged or resized, it keeps the card on this screen until it is let go.
    Binding {
        target: DesktopService
        property: "inHand"
        value: true
        when: drag.active || resize.active
    }

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
        border.color: Theme.borderIn(QsWindow.window)
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
        border.color: resize.active ? Theme.accent : Theme.borderIn(QsWindow.window)
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
                const stride = DesktopService.strideOn(root.screenName)
                const cols = (pointer.x - root.box.x + Theme.desktopGutter) / stride
                const rows = (pointer.y - root.box.y + Theme.desktopGutter) / stride
                const next = DesktopService.familyNearest(
                    root.moduleId, cols, rows, DesktopService.themeOf(root.row))
                if (next !== root.family)
                    DesktopService.setFamily(root.key, next)
            }
        }
    }
}
