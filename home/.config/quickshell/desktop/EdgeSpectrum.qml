// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   E D G E   S P E C T R U M                                              │
// │   sound bars along a whole screen edge · under the windows               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"

// One spectrum row, along the whole of its edge (`DesktopService.geometry`):
// the bottom from corner to corner, a side from under the bar to the bottom.
// It is part of the desk, so it is under the windows: an empty workspace
// shows all of it, and beside a window only its foot shows, in the margin the
// window leaves.
//
// At rest it takes no input. While arranging the whole strip is its handle:
// a click opens its inspector, and dragging it onto another edge moves it
// there, onto the grid makes it a widget, and onto the card takes it off.
Item {
    id: root

    required property string modelData
    required property Item board
    required property string screenName

    readonly property string key: root.modelData
    readonly property var row: DesktopService.entryOf(root.key)
    readonly property string edge: root.row ? root.row.edge : "bottom"
    readonly property var looks: DesktopService.spectrumOf(root.row)
    readonly property var box: DesktopService.geometry(root.row ?? ({}), root.board.width, root.board.height)
    readonly property bool editing: DesktopService.editing
    readonly property bool selected: DesktopService.selected === root.key
    readonly property bool held: carry.active

    x: root.box.x
    y: root.box.y
    width: root.box.width
    height: root.box.height

    // While arranging, the strip's ground, so it can be found in silence.
    Rectangle {
        anchors.fill: parent
        visible: root.editing
        radius: Theme.radiusSmall
        color: Qt.alpha(Theme.accent, root.selected ? 0.16 : 0.08)
        border.color: root.selected ? Theme.accent : Theme.hairline
        border.width: root.selected ? 2 : 1
        opacity: root.held ? 0.4 : 1
    }

    // Gone while it is away (`spectrumAwayOn`), and deaf with it.
    SpectrumBars {
        anchors.fill: parent
        edge: root.edge
        style: root.looks.look
        fillStyle: root.looks.fill
        color: root.looks.color
        color2: root.looks.color2
        barWidth: root.looks.bar
        gap: root.looks.gap
        lowsAt: root.looks.lows
        peaks: root.looks.peaks
        listening: root.editing || !DesktopService.spectrumAwayOn(root.screenName)
        visible: listening
        opacity: root.looks.opacity / 100 * (root.held ? 0.4 : 1)
    }

    // ── ARRANGING ───────────────────────────────────────────────────────────
    //
    // A click selects it; a press that moves carries it. The strip stays where
    // it is while its card follows the pointer; the edge under the pointer
    // lights (`DeckService.receiving`) unless it already has a spectrum, and
    // over the grid the square it would take is marked.

    TapHandler {
        enabled: root.editing
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: DesktopService.selected = root.selected ? "" : root.key
    }

    DragHandler {
        id: carry

        enabled: root.editing
        target: null

        onActiveChanged: {
            if (carry.active) {
                DesktopService.dragging = root.key
                DesktopService.selected = ""
                root.aim()
                return
            }
            const pointer = root.pointer()
            const edge = DeckService.receiving
            const spot = DesktopService.landing
            DesktopService.dragging = ""
            DesktopService.landing = null
            DeckService.receiving = ""
            if (DesktopService.overTray(root.screenName, pointer.x, pointer.y))
                DesktopService.remove(root.key)
            else if (edge !== "")
                DesktopService.setSpectrumEdge(root.key, root.screenName, edge)
            else if (spot)
                DesktopService.spectrumToGrid(root.key, spot.screen, spot.col, spot.row)
        }

        onCentroidChanged: root.aim()
    }

    Binding {
        target: DesktopService
        property: "inHand"
        value: true
        when: carry.active
    }

    function pointer(): point {
        return root.board.mapFromItem(null,
            carry.centroid.scenePosition.x, carry.centroid.scenePosition.y)
    }

    function aim(): void {
        if (!carry.active)
            return
        const pointer = root.pointer()
        hand.x = pointer.x - hand.width / 2
        hand.y = pointer.y - hand.height / 2
        const name = root.screenName
        const over = DesktopService.overTray(name, pointer.x, pointer.y)
        const edge = over ? "" : DeckService.edgeAt(pointer.x, pointer.y, root.board.width, root.board.height)
        DeckService.receivingScreen = name
        DeckService.receiving = DesktopService.spectrumTakes(name, edge) ? edge : ""
        if (over || edge !== "") {
            DesktopService.landing = null
            return
        }
        const familyId = DesktopService.familiesFor("spectrum")[0] ?? "4x2"
        const spot = DesktopService.nearestFree(name,
            DesktopService.cellX(name, hand.x), DesktopService.cellY(name, hand.y), familyId, "")
        DesktopService.landing = spot
            ? { screen: name, col: spot.col, row: spot.row, family: familyId } : null
    }

    // The card in the hand, as the tray draws it. Built only while it is
    // carried: hidden bars still listen and still move.
    Loader {
        id: hand

        readonly property var size: DesktopService.sizeFor("4x2", root.screenName)

        parent: root.board
        z: 10
        active: root.held
        width: hand.size.width
        height: hand.size.height
        opacity: 0.9

        sourceComponent: Rectangle {
            radius: Theme.desktopRadius
            color: Theme.island
            border.color: Theme.accent
            border.width: 2

            Face {
                anchors.fill: parent
                moduleId: "spectrum"
                family: "4x2"
                row: root.row
                ink: DesktopService.inkFor(null)
                enabled: false
            }
        }
    }
}
