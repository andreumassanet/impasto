// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D E C K                                                                │
// │   notes on the screen edges · tabs that peek and drag                    │
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

// Notes docked on the screen edges. At rest each is a thin strip of colour;
// hovering slides the tabs out with their titles, the tab under the pointer
// peeks the full note beside it, and a click opens the note in the island.
//
// While the desktop is being arranged the tabs stay out: drag a tab along its
// edge to reorder, to another edge to move it, onto the grid to make it a
// widget, or onto the tray to remove it. Clicking a tab opens the deck's
// inspector.
//
// A full-screen surface with a computed input mask (DeckService), like the
// dock, so it shares the desktop's origin and grid cells line up. It moves to
// the overlay layer while arranging: the desktop is raised to `top` then, and
// its full-screen mask would otherwise take every press meant for a tab. Never
// takes the keyboard.
PanelWindow {
    id: root

    readonly property bool editing: DesktopService.editing

    // Published for the desktop's focus grab, so a press on a tab while
    // arranging does not end the mode.
    Component.onCompleted: DeckService.surface = root
    Component.onDestruction: {
        if (DeckService.surface === root)
            DeckService.surface = null
    }

    // Reset any press in progress when the mode changes; a region left expanded
    // would swallow every click.
    onEditingChanged: {
        DeckService.held = ""
        DeckService.dragging = ""
        DeckService.sliding = ""
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.namespace: "impasto-deck"
    WlrLayershell.layer: root.editing ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Full screen and inset to the same board as the desktop, so grid cells
    // match.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    // Hidden with no decks, under a fullscreen window, or under any window when
    // decks only show on an empty workspace. Always shown while arranging.
    visible: (root.editing || !DeckService.away)
        && (DeckService.count > 0 || DeckService.receiving !== "" || root.editing)

    // ── REVEAL ──────────────────────────────────────────────────────────────
    //
    // How far the tabs are out, from 0 (strips) to 1 (tabs). Fully out while
    // arranging.
    readonly property bool out: root.editing || DeckService.revealed
        || DeckService.peeked !== "" || DeckService.receiving !== ""

    property real reveal: root.out ? 1 : 0

    Behavior on reveal {
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    readonly property real depth: DeckService.sliver
        + (DeckService.tabDepth - DeckService.sliver) * root.reveal

    // The peeking note, if any.
    readonly property var peekedNote: DeckService.dragging === "" && !root.menu
        ? NotesService.entry(DeckService.peeked) : null

    // Where a note's tab peeks from, or null for a note on no edge.
    function boxFor(key: string): var {
        for (const deck of DeckService.decks) {
            const index = deck.notes.findIndex(note => note.key === key)
            if (index >= 0)
                return DeckService.peekBox(deck.edge, index,
                    root.startOf(deck.edge, deck.notes.length, deck.along), board.width, board.height)
        }
        return null
    }

    readonly property var peekAt: root.boxFor(DeckService.peeked)

    // Where a deck starts along its edge, from the fraction on its row.
    function startOf(edge: string, count: int, along: real): real {
        return DeckService.startOf(edge, count, along, board.width, board.height)
    }

    // Retract after a delay, so moving from a tab to its peek is not leaving.
    readonly property Timer retract: Timer {
        interval: 320
        onTriggered: {
            DeckService.revealed = false
            DeckService.peeked = ""
        }
    }

    // ── CONTEXT MENU ────────────────────────────────────────────────────────
    //
    // Right-click menu on a tab at rest: open the note, or arrange the deck.
    // While it is open the mask covers the screen, so a click elsewhere closes
    // it.
    property var menu: null

    // ── INPUT MASK ──────────────────────────────────────────────────────────
    //
    // Only the tabs and the peek take input. The mask grows to the whole
    // surface as soon as a tab or grip is pressed, not when the drag starts:
    // the compositor re-checks the region on every motion, and the drag
    // threshold is enough to leave a 26 px tab and lose the press. Also the
    // whole surface while a menu is open.
    readonly property bool whole: DeckService.held !== "" || DeckService.dragging !== ""
        || DeckService.sliding !== "" || root.menu !== null

    // Empty while the desktop is dragging a widget, so a note dragged over a
    // tab does not hand the pointer to this surface. The desktop resolves the
    // drop edge itself.
    readonly property bool deaf: DesktopService.dragging !== ""

    mask: Region {
        x: 0
        y: 0
        width: root.whole && !root.deaf ? root.width : 0
        height: root.whole && !root.deaf ? root.height : 0
        regions: root.whole || root.deaf ? [] : root.cutouts.concat(root.peekAt ? [peekRegion] : [])
    }

    readonly property var cutouts: {
        const list = []
        for (let index = 0; index < strips.count; index++) {
            const part = strips.objectAt(index)
            if (part)
                list.push(part)
        }
        return list
    }

    Instantiator {
        id: strips

        model: DeckService.decks

        delegate: Region {
            required property var modelData

            readonly property real start: root.startOf(modelData.edge, modelData.notes.length, modelData.along)
            readonly property var box: DeckService.stripBox(
                modelData.edge, modelData.notes.length, start, board.width, board.height)

            // While arranging, the strip also covers the grip before the first
            // tab.
            readonly property real reach: root.editing ? DeckService.grip + 8 : 0

            x: board.x + (modelData.edge === "right" ? board.width - root.depth
                : (modelData.edge === "bottom" ? box.x - reach : 0))
            y: board.y + (modelData.edge === "bottom" ? board.height - root.depth : box.y - reach)
            width: modelData.edge === "bottom" ? box.width + reach : root.depth
            height: modelData.edge === "bottom" ? root.depth : box.height + reach
        }
    }

    Region {
        id: peekRegion

        x: root.peekAt ? board.x + root.peekAt.x - 6 : 0
        y: root.peekAt ? board.y + root.peekAt.y - 6 : 0
        width: root.peekAt ? root.peekAt.width + 12 : 0
        height: root.peekAt ? root.peekAt.height + 12 : 0
    }

    // Input only arrives inside the mask, so one handler over the surface
    // covers exactly the decks.
    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hover.hovered) {
                root.retract.stop()
                DeckService.revealed = true
                return
            }
            root.retract.restart()
        }
    }

    // Closes an open menu on any click outside it. A MouseArea, because the
    // click must be consumed.
    MouseArea {
        anchors.fill: parent
        enabled: root.menu !== null
        acceptedButtons: Qt.AllButtons
        onPressed: root.menu = null
    }

    // ── TABS ────────────────────────────────────────────────────────────────

    Item {
        id: board

        anchors.fill: parent
        anchors.topMargin: DesktopService.insets.top
        anchors.leftMargin: DesktopService.insets.left
        anchors.rightMargin: DesktopService.insets.right
        anchors.bottomMargin: DesktopService.insets.bottom

        // Where the dragged tab would land: an edge and a position along it, or
        // empty over the grid or the tray.
        property string dropEdge: ""
        property int dropIndex: -1

        // Keyed by deck (and the tabs by note key) rather than by row: a
        // Repeater given a new array rebuilds every delegate, and the rows are
        // a new array on every write, which would destroy the grip mid-drag.
        Repeater {
            model: DesktopService.deckKeys

            Item {
                id: deck

                required property string modelData

                readonly property string deckKey: deck.modelData
                readonly property var row: DesktopService.entryOf(deck.deckKey)
                readonly property string edge: deck.row && deck.row.edge ? deck.row.edge : "right"
                readonly property real along: DesktopService.alongOf(deck.row)

                // Reassigned only when the set changes, so delegates are not
                // rebuilt.
                readonly property var wanted: DesktopService.deckNotes(deck.row)
                property var noteKeys: []

                function syncNotes(): void {
                    const next = deck.wanted
                    if (next.length === deck.noteKeys.length
                            && next.every((key, index) => key === deck.noteKeys[index]))
                        return
                    deck.noteKeys = next
                }

                onWantedChanged: deck.syncNotes()
                Component.onCompleted: deck.syncNotes()

                readonly property int count: deck.noteKeys.length
                readonly property real start: root.startOf(deck.edge, deck.count, deck.along)
                readonly property bool selected: DesktopService.selected === deck.deckKey
                readonly property bool receiving: board.dropEdge === deck.edge
                    || DeckService.receiving === deck.edge

                anchors.fill: parent

                // ── GRIP ────────────────────────────────────────────────
                //
                // While arranging, the grip before the first tab slides the
                // whole deck along its edge; tabs are dragged one by one. The
                // inspector closes when the drag starts.
                Rectangle {
                    id: grip

                    readonly property var box: DeckService.gripBox(
                        deck.edge, deck.start, board.width, board.height)

                    x: grip.box.x
                    y: grip.box.y
                    width: DeckService.grip
                    height: DeckService.grip
                    radius: width / 2
                    color: Theme.island
                    border.color: slide.active ? Theme.accent : Theme.islandBorder
                    border.width: slide.active ? 2 : 1
                    visible: opacity > 0
                    opacity: root.editing ? 1 : 0
                    z: 2

                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                    Text {
                        anchors.centerIn: parent
                        text: deck.edge === "bottom" ? "󰡏" : "󰡎"
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: Theme.scrimText
                    }

                    HoverHandler {
                        cursorShape: deck.edge === "bottom" ? Qt.SizeHorCursor : Qt.SizeVerCursor
                    }

                    // Exclusive from the press, so the tab's handlers
                    // underneath never see the drag.
                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                    }

                    // Grows the region on press, before any drag. Also released
                    // on destruction: a grip destroyed under the pointer never
                    // reports its release, and a region left grown swallows
                    // every click.
                    PointHandler {
                        id: gripHold

                        acceptedButtons: Qt.LeftButton
                        onActiveChanged: {
                            if (gripHold.active)
                                DeckService.held = deck.deckKey
                            else if (DeckService.held === deck.deckKey)
                                DeckService.held = ""
                        }
                    }

                    Component.onDestruction: {
                        if (DeckService.held === deck.deckKey)
                            DeckService.held = ""
                        if (DeckService.sliding === deck.deckKey)
                            DeckService.sliding = ""
                    }

                    DragHandler {
                        id: slide

                        enabled: root.editing
                        target: null

                        onActiveChanged: {
                            if (slide.active) {
                                DesktopService.selected = ""
                                DeckService.sliding = deck.deckKey
                                return
                            }
                            if (DeckService.sliding === deck.deckKey)
                                DeckService.sliding = ""
                        }

                        onCentroidChanged: {
                            if (!slide.active)
                                return
                            const point = board.mapFromItem(null,
                                slide.centroid.scenePosition.x, slide.centroid.scenePosition.y)
                            const start = (deck.edge === "bottom" ? point.x : point.y)
                                + DeckService.grip / 2 + 4
                            DesktopService.setDeckAlong(deck.deckKey, DeckService.alongAt(
                                deck.edge, deck.count, start, board.width, board.height))
                        }
                    }
                }

                Repeater {
                    model: deck.noteKeys

                    Item {
                        id: tab

                        required property string modelData
                        required property int index

                        readonly property string noteKey: tab.modelData
                        readonly property var note: NotesService.entry(tab.noteKey)
                        readonly property color paper: NotesService.paperOf(tab.note ? tab.note.tint : "yellow")
                        readonly property bool held: DeckService.dragging === tab.noteKey
                        readonly property bool peeking: DeckService.peeked === tab.noteKey

                        // Its own slot, or one along while the dragged tab is
                        // dropped before it on this edge.
                        readonly property int shown: {
                            if (DeckService.dragging === "" || tab.held || board.dropEdge !== deck.edge)
                                return tab.index
                            const from = deck.noteKeys.indexOf(DeckService.dragging)
                            let at = tab.index
                            if (from >= 0 && from < tab.index)
                                at -= 1
                            if (board.dropIndex <= at)
                                at += 1
                            return at
                        }

                        readonly property var box: DeckService.tabBox(
                            deck.edge, tab.shown, deck.start, root.depth, board.width, board.height)

                        x: tab.box.x
                        y: tab.box.y
                        width: tab.box.width
                        height: tab.box.height
                        opacity: tab.held ? 0.3 : 1
                        z: tab.peeking ? 1 : 0

                        Behavior on x {
                            enabled: DeckService.dragging !== ""
                            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                        }
                        Behavior on y {
                            enabled: DeckService.dragging !== ""
                            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                        }

                        // Rounded on the screen side, square against the edge.
                        Rectangle {
                            anchors.fill: parent
                            color: tab.paper
                            topLeftRadius: deck.edge === "left" ? 0 : Theme.radiusSmall
                            bottomLeftRadius: deck.edge === "left" || deck.edge === "bottom" ? 0 : Theme.radiusSmall
                            topRightRadius: deck.edge === "right" ? 0 : Theme.radiusSmall
                            bottomRightRadius: deck.edge === "right" || deck.edge === "bottom" ? 0 : Theme.radiusSmall
                            border.color: Theme.accent
                            border.width: root.editing && deck.selected ? 2 : 0
                        }

                        // The title along the tab, once there is room to read
                        // it.
                        Text {
                            anchors.centerIn: parent
                            width: DeckService.tabLength - 16
                            rotation: deck.edge === "right" ? 90 : (deck.edge === "left" ? -90 : 0)
                            text: tab.note ? NotesService.titleOf(tab.note).toUpperCase() : ""
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                            color: Theme.paperInk
                            opacity: root.reveal
                        }

                        HoverHandler {
                            cursorShape: root.editing
                                ? (tab.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                                : Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered && !root.editing) {
                                    root.retract.stop()
                                    DeckService.peeked = tab.noteKey
                                }
                            }
                        }

                        // At rest a press opens the note; while arranging it
                        // selects the deck. Exclusive from the press; the drag
                        // can still take over.
                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                if (root.editing)
                                    DesktopService.selected = deck.selected ? "" : deck.deckKey
                                else
                                    root.openNote(tab.noteKey)
                            }
                        }

                        TapHandler {
                            enabled: !root.editing
                            acceptedButtons: Qt.RightButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: eventPoint => {
                                const point = board.mapFromItem(null,
                                    eventPoint.scenePosition.x, eventPoint.scenePosition.y)
                                root.menu = { note: tab.noteKey, deck: deck.deckKey, x: point.x, y: point.y }
                            }
                        }

                        // Grows the region on press. Must be declared after the
                        // tap handlers, or it never becomes active. Released on
                        // destruction, as for the grip.
                        PointHandler {
                            id: tabHold

                            acceptedButtons: Qt.LeftButton
                            onActiveChanged: {
                                if (tabHold.active)
                                    DeckService.held = tab.noteKey
                                else if (DeckService.held === tab.noteKey)
                                    DeckService.held = ""
                            }
                        }

                        Component.onDestruction: {
                            if (DeckService.held === tab.noteKey)
                                DeckService.held = ""
                            if (DeckService.dragging === tab.noteKey)
                                DeckService.dragging = ""
                        }

                        DragHandler {
                            id: pull

                            enabled: root.editing
                            target: null

                            onActiveChanged: {
                                if (pull.active) {
                                    DeckService.dragging = tab.noteKey
                                    DeckService.peeked = ""
                                    DesktopService.selected = ""
                                    root.aim(pull.centroid.scenePosition)
                                    return
                                }
                                root.drop(tab.noteKey, pull.centroid.scenePosition)
                            }

                            onCentroidChanged: {
                                if (pull.active)
                                    root.aim(pull.centroid.scenePosition)
                            }
                        }
                    }
                }

                // Highlights the edge while something is dragged over it.
                Rectangle {
                    x: deck.edge === "right" ? board.width - 3 : 0
                    y: deck.edge === "bottom" ? board.height - 3 : 0
                    width: deck.edge === "bottom" ? board.width : 3
                    height: deck.edge === "bottom" ? 3 : board.height
                    color: Theme.accent
                    opacity: deck.receiving ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                }
            }
        }

        // Edges with no deck yet, lit while something is held against them.
        Repeater {
            model: ["left", "right", "bottom"].filter(
                edge => !DeckService.decks.some(deck => deck.edge === edge))

            Rectangle {
                required property string modelData

                x: modelData === "right" ? board.width - 3 : 0
                y: modelData === "bottom" ? board.height - 3 : 0
                width: modelData === "bottom" ? board.width : 3
                height: modelData === "bottom" ? 3 : board.height
                color: Theme.accent
                opacity: DeckService.receiving === modelData || board.dropEdge === modelData ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }
        }
    }

    // ── PEEK ────────────────────────────────────────────────────────────────
    //
    // The hovered note, slid out beside its tab. Shadowed rather than boxed.
    Item {
        id: peek

        parent: board

        readonly property bool showing: root.peekedNote !== null && !root.editing

        // Which note is shown and where, held through the fade-out: bound
        // directly to the hovered tab, they would reset as the pointer leaves
        // and the paper would fade out from the board's corner. Only taken when
        // there is a tab, and by key rather than as an object, since an object
        // goes stale when the note is edited and `peekedNote` is null while a
        // menu is open or a tab is held. The box is computed for the key rather
        // than read off a sibling binding that may lag.
        property string key: ""
        property var box: null

        readonly property string live: DeckService.peeked

        onLiveChanged: {
            if (peek.live !== "") {
                peek.key = peek.live
                peek.box = root.boxFor(peek.live)
            }
        }

        x: peek.box ? peek.box.x : 0
        y: peek.box ? peek.box.y : 0
        width: DeckService.peekWidth
        height: DeckService.peekHeight
        visible: opacity > 0
        opacity: peek.showing ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowOpacity: 0.5
            shadowVerticalOffset: 3
            shadowColor: Theme.island
        }

        Sticky {
            anchors.fill: parent
            note: NotesService.entry(peek.key)
            padding: 14
            titleSize: Theme.fontSizeRegular
            bodySize: 17
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (hovered)
                    root.retract.stop()
            }
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.openNote(DeckService.peeked)
        }
    }

    // ── DRAGGED TAB ─────────────────────────────────────────────────────────
    //
    // The dragged tab, drawn as a small square of its paper under the pointer.
    Item {
        id: ghost

        parent: board

        readonly property var note: NotesService.entry(DeckService.dragging)

        z: 10
        visible: DeckService.dragging !== ""
        width: 72
        height: 72
        opacity: 0.94

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowOpacity: 0.5
            shadowVerticalOffset: 3
            shadowColor: Theme.island
        }

        Sticky {
            anchors.fill: parent
            note: ghost.note
            padding: 8
            titleSize: Theme.fontSizeLabel
            bodySize: 11
            showAge: false
        }
    }

    // ── MENU ────────────────────────────────────────────────────────────────

    Loader {
        id: menuLoader

        parent: board
        active: root.menu !== null
        x: root.menu ? Math.max(Theme.desktopGutter, Math.min(board.width - Theme.desktopGutter - width, root.menu.x)) : 0
        y: root.menu ? Math.max(Theme.desktopGutter, Math.min(board.height - Theme.desktopGutter - height, root.menu.y)) : 0
        z: 20

        sourceComponent: PopMenu {
            rows: [
                { id: "open", label: "Open", icon: "󰏫", warn: false },
                { id: "edit", label: "Edit", icon: "󰆾", warn: false }
            ]
            onChosen: id => {
                const menu = root.menu
                root.menu = null
                if (!menu)
                    return
                if (id === "open")
                    root.openNote(menu.note)
                else if (id === "edit") {
                    DesktopService.edit(true)
                    DesktopService.selected = menu.deck
                }
            }
        }
    }

    // While dragging: the edge and position under the pointer, or the grid
    // cell, lit by the desktop's landing mark.
    function aim(scene: point): void {
        const point = board.mapFromItem(null, scene.x, scene.y)
        ghost.x = point.x - ghost.width / 2
        ghost.y = point.y - ghost.height / 2
        if (DesktopService.overTray(point.x, point.y)) {
            board.dropEdge = ""
            board.dropIndex = -1
            DesktopService.landing = null
            return
        }
        const edge = DeckService.edgeAt(point.x, point.y, board.width, board.height)
        if (edge !== "") {
            const deck = DeckService.decks.find(deck => deck.edge === edge)
            board.dropEdge = edge
            board.dropIndex = deck
                ? DeckService.indexAt(edge, point.x, point.y, deck.notes.length,
                    root.startOf(deck.edge, deck.notes.length, deck.along))
                : 0
            DesktopService.landing = null
            return
        }
        board.dropEdge = ""
        board.dropIndex = -1
        const size = DesktopService.sizeFor("2x2")
        const spot = DesktopService.nearestFree(
            DesktopService.cellX(point.x - size.width / 2),
            DesktopService.cellY(point.y - size.height / 2), "2x2", "")
        DesktopService.landing = spot ? { col: spot.col, row: spot.row, family: "2x2" } : null
    }

    // Dropped on an edge, it takes its place there; on the desktop, the nearest
    // free grid cell; on the tray, it is removed. With no free cell it stays
    // where it was.
    function drop(key: string, scene: point): void {
        const point = board.mapFromItem(null, scene.x, scene.y)
        const edge = board.dropEdge
        const index = board.dropIndex
        DeckService.dragging = ""
        DeckService.held = ""
        board.dropEdge = ""
        board.dropIndex = -1
        DesktopService.landing = null
        if (DesktopService.overTray(point.x, point.y)) {
            DesktopService.removeNote(key)
            return
        }
        if (edge !== "") {
            DesktopService.placeNote(key, edge, index)
            return
        }
        const size = DesktopService.sizeFor("2x2")
        DesktopService.noteToGrid(key,
            DesktopService.cellX(point.x - size.width / 2),
            DesktopService.cellY(point.y - size.height / 2))
    }

    function openNote(key: string): void {
        DeckService.peeked = ""
        DeckService.revealed = false
        NotesService.open(key)
        ModuleService.requestPanel("notes")
    }
}
