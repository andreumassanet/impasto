// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T   R   A   Y                                                          │
// │   widget tray · drag modules onto the grid                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"
import "../components"

// The card shown while arranging: every module as its real face at the
// smallest family it offers, which is the face it lands with. Drag one onto
// the grid, or click it to place it on the first free cell, and change its
// shape there; drop a widget on the card to remove it. Every module is offered
// regardless of its current state.
//
// The ghost (the face at full size while dragged) lives on the board rather
// than here, so it can leave the card.
EditTray {
    id: root

    required property Item board

    // The screen this card is on. It is wherever the pointer is: crossing to
    // another board brings the card there and takes it off this one, which is
    // `Desktop.qml`'s doing, not this file's.
    required property string screenName

    // The module being dragged out of the card, or empty.
    property string pulling: ""

    // Packed in squares: a 2×2 face is one unit, a 4×2 face two.
    entries: DesktopService.offerable.map(entry => {
        const shape = DesktopService.family(root.smallest(entry.id))
        return { id: entry.id, name: entry.name, cols: shape.cols / 2, rows: shape.rows / 2 }
    })
    unitWidth: DesktopService.sizeFor("2x2", root.screenName).width
    unitHeight: DesktopService.sizeFor("2x2", root.screenName).height
    unitGap: Theme.desktopGutter
    startColumns: 5
    startRows: 2
    factor: 0.75
    homeX: (root.width - root.card.width) / 2
    homeY: root.height - root.card.height - Theme.desktopGutter
    at: DesktopService.galleryAtOn(root.screenName)
    onMoved: (x, y) => DesktopService.setGalleryAt(root.screenName, x, y)
    size: DesktopService.gallerySize
    onResized: (columns, rows) => DesktopService.gallerySize = { columns: columns, rows: rows }
    receiving: DesktopService.dragging !== "" && DesktopService.landing === null

    function smallest(id: string): string {
        return DesktopService.familiesFor(id)[0] ?? "4x2"
    }

    // Anything held here keeps the card on this screen until it is let go.
    Binding {
        target: DesktopService
        property: "inHand"
        value: true
        when: root.holding || root.pulling !== ""
    }

    // The card's rect in board coordinates, so a drop can tell whether it
    // landed there. This item fills the board.
    Binding {
        target: DesktopService
        property: "trayBox"
        value: ({
            x: root.card.x, y: root.card.y,
            width: root.card.width, height: root.card.height
        })
    }

    // Dragged onto another screen, this card is destroyed and that board
    // builds one: the box is already that one's, so only a card going away
    // for good takes it with it.
    Component.onDestruction: {
        if (DesktopService.editing)
            return
        DesktopService.trayBox = null
        DesktopService.landing = null
    }

    // ── PIECE ───────────────────────────────────────────────────────────────

    delegate: Item {
        id: tile

        required property var modelData

        readonly property string moduleId: tile.modelData.id
        readonly property string familyId: root.smallest(tile.moduleId)
        readonly property var box: DesktopService.sizeFor(tile.familyId, root.screenName)
        readonly property real factor: tile.width / tile.box.width
        readonly property bool pulled: root.pulling === tile.moduleId

        x: tile.modelData.x
        y: tile.modelData.y
        width: tile.modelData.width
        height: tile.modelData.height

        // The real face, scaled to the mosaic, on the island's black.
        Item {
            width: tile.box.width
            height: tile.box.height
            scale: tile.factor
            transformOrigin: Item.TopLeft

            Rectangle {
                anchors.fill: parent
                radius: Theme.desktopRadius
                color: Theme.island
                border.color: tile.pulled ? Theme.accent : Theme.islandBorder
                border.width: (tile.pulled ? 2 : 1) / tile.factor
            }

            Face {
                anchors.fill: parent
                moduleId: tile.moduleId
                family: tile.familyId
                ink: DesktopService.inkFor(null)
                enabled: false
            }
        }

        HoverHandler {
            cursorShape: tile.pulled ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        // Exclusive from the press, so the background's tap handler does not
        // also fire.
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: DesktopService.add(tile.moduleId, root.screenName)
        }

        DragHandler {
            id: pull

            target: null

            onActiveChanged: {
                if (pull.active) {
                    root.pulling = tile.moduleId
                    DesktopService.selected = ""
                    root.aim(pull.centroid.scenePosition)
                    return
                }
                const spot = DesktopService.landing
                const edge = DeckService.receiving
                const onScreen = DeckService.receivingScreen
                const moduleId = root.pulling
                root.pulling = ""
                DesktopService.landing = null
                DeckService.receiving = ""
                if (edge !== "" && moduleId === "notes")
                    DesktopService.addDeck(onScreen, edge)
                else if (spot)
                    DesktopService.add(moduleId, spot.screen, spot.col, spot.row)
            }

            onCentroidChanged: {
                if (pull.active)
                    root.aim(pull.centroid.scenePosition)
            }
        }
    }

    // ── GHOST ───────────────────────────────────────────────────────────────
    //
    // The dragged face at its final size, following the pointer; the surface
    // draws the target cell under it. Parented to the board so it can leave the
    // card.
    function aim(scene: point): void {
        const pointer = root.board.mapFromItem(null, scene.x, scene.y)
        ghost.x = pointer.x - ghost.width / 2
        ghost.y = pointer.y - ghost.height / 2

        const name = root.screenName
        if (DesktopService.overTray(name, pointer.x, pointer.y)) {
            DesktopService.landing = null
            DeckService.receiving = ""
            return
        }
        // A notes piece against an edge is a deck there, not a square.
        const edge = root.pulling === "notes"
            ? DeckService.edgeAt(pointer.x, pointer.y, root.board.width, root.board.height) : ""
        DeckService.receivingScreen = name
        DeckService.receiving = edge
        if (edge !== "") {
            DesktopService.landing = null
            return
        }
        const spot = DesktopService.nearestFree(name,
            DesktopService.cellX(name, ghost.x),
            DesktopService.cellY(name, ghost.y), ghost.familyId, "")
        DesktopService.landing = spot
            ? { screen: name, col: spot.col, row: spot.row, family: ghost.familyId } : null
    }

    Item {
        id: ghost

        readonly property string familyId: root.smallest(root.pulling)
        readonly property var box: DesktopService.sizeFor(ghost.familyId, root.screenName)

        parent: root.board
        z: 10
        visible: root.pulling !== ""
        width: ghost.box.width
        height: ghost.box.height
        opacity: 0.9

        Rectangle {
            anchors.fill: parent
            radius: Theme.desktopRadius
            color: Theme.island
            border.color: Theme.accent
            border.width: 2
        }

        Face {
            anchors.fill: parent
            moduleId: root.pulling
            family: ghost.familyId
            ink: DesktopService.inkFor(null)
            enabled: false
        }
    }
}
