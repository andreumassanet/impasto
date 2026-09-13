// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   E D I T   T R A Y                                                      │
// │   edit tray · every piece on a card that moves                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// The card shown while arranging, shared by the desktop and the control
// centre: every piece at its smallest size, packed as a mosaic at one scale so
// each keeps its proportions, to be dragged out or clicked in and resized once
// placed. Anywhere on the card that is not a piece moves it, and so does the
// handle in its top left corner; the handle in the opposite corner resizes it
// in whole columns and rows, the pieces flowing into the new width and the
// rest scrolled by the wheel or the bar in the right margin. It opens at its
// home every time; its size lasts for the session. Arranging ends with Escape
// or the right button.
//
// Fills its parent; only the card takes the pointer. The caller hands in the
// entries, the packing unit and a `delegate`, which gets `modelData` with the
// piece's `id`, `name` and its box in the mosaic (`x`, `y`, `width`, `height`).
Item {
    id: root

    // [{ id, name, cols, rows }]: the smallest footprint, in packing units.
    property var entries: []
    property Component delegate: null

    // One packing unit in real pixels, the street between two, and the scale
    // the mosaic is drawn at.
    property real unitWidth: 100
    property real unitHeight: 100
    property real unitGap: 0
    property real factor: 0.5

    // The size it opens at until it is resized, in columns and rows.
    property int startColumns: 4
    property int startRows: 2

    // Where the card sits until it is moved, and where it was left (null when
    // it never was).
    property real homeX: 0
    property real homeY: 0
    property var at: null

    signal moved(real x, real y)

    // Its size once resized, as { columns, rows } (null when it never was).
    property var size: null

    signal resized(int columns, int rows)

    // Highlighted while a dragged item is over it: dropping removes it.
    property bool receiving: false

    readonly property alias card: card

    // Wide enough to take hold of the card by its edge.
    readonly property int pad: 24

    // How far the mosaic is scrolled, when the card is shorter than it.
    property real scrolled: 0

    readonly property real street: root.unitGap * root.factor
    readonly property real strideX: (root.unitWidth + root.unitGap) * root.factor
    readonly property real strideY: (root.unitHeight + root.unitGap) * root.factor

    // Length of `count` units and the streets between them.
    function span(count: int, stride: real): real {
        return Math.max(0, count * stride - root.street)
    }

    // ── PACKING ─────────────────────────────────────────────────────────────
    //
    // Tallest first, then widest, then by name, each at the first free place
    // from the top, so the smaller pieces fill the holes the taller ones leave.

    readonly property var order: root.entries.slice().sort((left, right) =>
        right.rows - left.rows || right.cols - left.cols
            || Tr.t(left.name).localeCompare(Tr.t(right.name)))

    readonly property int widest: root.order.reduce((most, entry) => Math.max(most, entry.cols), 1)
    readonly property int tallest: root.order.reduce((most, entry) => Math.max(most, entry.rows), 1)

    // While the corner is pulled, the size under the pointer.
    property int pullColumns: 0
    property int pullRows: 0

    readonly property int columns: root.pullColumns > 0 ? root.pullColumns
        : Math.max(root.widest, root.size ? root.size.columns : root.startColumns)

    readonly property var layout: root.pack(root.columns)

    // As many rows as it was sized to, never fewer than the tallest piece
    // takes nor more than there are.
    readonly property int shownRows: {
        const wanted = root.pullRows > 0 ? root.pullRows
            : root.size ? root.size.rows : root.startRows
        return Math.min(root.layout.rows, Math.max(Math.min(root.tallest, root.layout.rows), wanted))
    }

    readonly property var packed: root.layout.pieces.map(piece => ({
        id: piece.id,
        name: piece.name,
        x: piece.col * root.strideX,
        y: piece.row * root.strideY,
        width: root.span(piece.cols, root.strideX),
        height: root.span(piece.rows, root.strideY)
    }))

    function pack(columns: int): var {
        const taken = []
        const pieces = root.order.map(entry => {
            const cols = Math.min(entry.cols, columns)
            const spot = root.spotFor(taken, columns, cols, entry.rows)
            for (let row = spot.row; row < spot.row + entry.rows; row++) {
                taken[row] = taken[row] ?? []
                for (let col = spot.col; col < spot.col + cols; col++)
                    taken[row][col] = true
            }
            return { id: entry.id, name: entry.name, col: spot.col, row: spot.row, cols: cols, rows: entry.rows }
        })
        return {
            pieces: pieces,
            rows: pieces.reduce((most, piece) => Math.max(most, piece.row + piece.rows), 0)
        }
    }

    function spotFor(taken: var, columns: int, cols: int, rows: int): var {
        for (let row = 0; ; row++) {
            for (let col = 0; col + cols <= columns; col++) {
                let free = true
                for (let r = row; r < row + rows && free; r++)
                    for (let c = col; c < col + cols && free; c++)
                        free = !(taken[r] !== undefined && taken[r][c] === true)
                if (free)
                    return { col: col, row: row }
            }
        }
    }

    function clampX(x: real): real {
        return Math.max(Theme.desktopGutter,
            Math.min(root.width - card.width - Theme.desktopGutter, x))
    }

    function clampY(y: real): real {
        return Math.max(Theme.desktopGutter,
            Math.min(root.height - card.height - Theme.desktopGutter, y))
    }

    // ── CARD ────────────────────────────────────────────────────────────────

    Rectangle {
        id: card

        x: root.clampX(root.at ? root.at.x : root.homeX)
        y: root.clampY(root.at ? root.at.y : root.homeY)

        // No taller than the room; the mosaic scrolls inside when it is.
        width: mosaic.width + 2 * root.pad
        height: Math.min(root.span(root.shownRows, root.strideY) + 2 * root.pad,
            Math.max(2 * root.pad, root.height - 2 * Theme.desktopGutter))
        radius: Theme.radiusLarge
        color: Theme.island
        border.color: root.receiving ? Theme.accent : Theme.islandBorder
        border.width: root.receiving ? 2 : 1

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

        // Anywhere but a piece moves the card. The tap is exclusive from the
        // press, so neither the surface below nor a widget behind ever sees
        // it, and the drag on the same item takes the point over. A piece is
        // delivered first and keeps its own.
        HoverHandler {
            cursorShape: mover.active ? Qt.ClosedHandCursor : Qt.SizeAllCursor
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        // Off while the pointer is on a handle or the bar: a press inside both
        // would otherwise go to this drag and move the card instead.
        DragHandler {
            id: mover

            enabled: !cornerHover.hovered && !stretch.active
                && !gripHover.hovered && !carry.active
                && !railHover.hovered && !scrub.active
            target: card
            xAxis.minimum: Theme.desktopGutter
            xAxis.maximum: root.width - card.width - Theme.desktopGutter
            yAxis.minimum: Theme.desktopGutter
            yAxis.maximum: root.height - card.height - Theme.desktopGutter

            onActiveChanged: {
                if (!mover.active)
                    root.moved(card.x, card.y)
            }
        }

        // ── MOSAIC ──────────────────────────────────────────────────────────
        //
        // Scrolled by the wheel or the bar rather than a Flickable, which
        // would take the drag that pulls a piece out. A fade at an edge says
        // there is more.

        Item {
            id: viewport

            readonly property real overflow: Math.max(0, mosaic.height - viewport.height)

            x: root.pad
            y: root.pad
            width: mosaic.width
            height: card.height - 2 * root.pad
            clip: viewport.overflow > 0

            Item {
                id: mosaic

                y: -Math.min(root.scrolled, viewport.overflow)
                width: root.span(root.columns, root.strideX)
                height: root.span(root.layout.rows, root.strideY)

                Repeater {
                    model: root.packed
                    delegate: root.delegate
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.pad
                visible: mosaic.y < 0
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.island }
                    GradientStop { position: 1; color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0) }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.pad
                visible: -mosaic.y < viewport.overflow
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0) }
                    GradientStop { position: 1; color: Theme.island }
                }
            }

            WheelHandler {
                enabled: viewport.overflow > 0
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                    root.scrolled = Math.max(0, Math.min(viewport.overflow, root.scrolled - delta))
                }
            }
        }

        // ── BAR ─────────────────────────────────────────────────────────────
        //
        // In the right margin while the mosaic is taller than the card: the
        // thumb is the part in view. Dragged, it scrolls; pressed on the
        // track, the thumb's middle goes there first.

        Item {
            id: rail

            readonly property real thumbLength: Math.max(root.pad,
                rail.height * viewport.height / Math.max(1, mosaic.height))
            readonly property real reach: rail.height - rail.thumbLength

            x: card.width - root.pad + (root.pad - rail.width) / 2
            y: viewport.y
            width: 12
            height: viewport.height
            visible: viewport.overflow > 0

            function scrollTo(top: real): void {
                root.scrolled = rail.reach > 0
                    ? Math.max(0, Math.min(1, top / rail.reach)) * viewport.overflow : 0
            }

            HoverHandler {
                id: railHover
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: eventPoint => rail.scrollTo(eventPoint.position.y - rail.thumbLength / 2)
            }

            DragHandler {
                id: scrub

                property real from: 0

                target: null
                xAxis.enabled: false
                grabPermissions: PointerHandler.CanTakeOverFromAnything

                onActiveChanged: {
                    if (!scrub.active)
                        return
                    const pressed = scrub.centroid.pressPosition.y
                    scrub.from = pressed >= thumb.y && pressed <= thumb.y + thumb.height
                        ? thumb.y : pressed - rail.thumbLength / 2
                }

                onTranslationChanged: {
                    if (scrub.active)
                        rail.scrollTo(scrub.from + scrub.translation.y)
                }
            }

            Rectangle {
                id: thumb

                readonly property real lit: scrub.active ? 1 : railHover.hovered ? 0.45 : 0.25

                anchors.horizontalCenter: parent.horizontalCenter
                y: rail.reach * Math.min(root.scrolled, viewport.overflow) / Math.max(1, viewport.overflow)
                width: railHover.hovered || scrub.active ? 6 : 4
                height: rail.thumbLength
                radius: width / 2
                color: scrub.active ? Theme.accent
                    : Qt.rgba(Theme.scrimText.r, Theme.scrimText.g, Theme.scrimText.b, thumb.lit)

                Behavior on width { NumberAnimation { duration: Theme.durationFast } }
            }
        }

        // ── HANDLES ─────────────────────────────────────────────────────────
        //
        // The widget's badge and handle, on the card: the top left moves it,
        // the bottom right resizes it.

        Rectangle {
            id: grip

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: -8
            anchors.topMargin: -8
            width: 24
            height: 24
            radius: 12
            color: Theme.island
            border.color: carry.active ? Theme.accent : Theme.islandBorder
            border.width: carry.active ? 2 : 1

            Text {
                anchors.centerIn: parent
                text: "󰆾"
                color: Theme.scrimText
                font.family: Theme.fontMono
                font.pixelSize: 14
            }

            HoverHandler {
                id: gripHover

                cursorShape: carry.active ? Qt.ClosedHandCursor : Qt.SizeAllCursor
            }

            // Exclusive on press, as on the corner, so the card's own tap does
            // not take the point.
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
            }

            DragHandler {
                id: carry

                target: card
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                xAxis.minimum: Theme.desktopGutter
                xAxis.maximum: root.width - card.width - Theme.desktopGutter
                yAxis.minimum: Theme.desktopGutter
                yAxis.maximum: root.height - card.height - Theme.desktopGutter

                onActiveChanged: {
                    if (!carry.active)
                        root.moved(card.x, card.y)
                }
            }
        }

        // Pulled, it measures the box from the card's top left in whole
        // columns and rows, never past the room, never narrower than the
        // widest piece.
        Rectangle {
            id: corner

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -8
            anchors.bottomMargin: -8
            width: 24
            height: 24
            radius: 12
            color: Theme.island
            border.color: stretch.active ? Theme.accent : Theme.islandBorder
            border.width: stretch.active ? 2 : 1

            // A corner bracket, as on a widget.
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

            HoverHandler {
                id: cornerHover

                cursorShape: Qt.SizeFDiagCursor
            }

            // Exclusive on press, before the drag below, so the card's own tap
            // does not take the point and turn the pull into a move.
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
            }

            // Once pulling, nothing takes the point from it.
            DragHandler {
                id: stretch

                property real fromWidth: 0
                property real fromHeight: 0

                target: null
                grabPermissions: PointerHandler.CanTakeOverFromAnything

                onActiveChanged: {
                    if (stretch.active) {
                        // Pinned where it is, so it grows from its top left.
                        card.x = card.x
                        card.y = card.y
                        root.moved(card.x, card.y)
                        stretch.fromWidth = mosaic.width
                        stretch.fromHeight = viewport.height
                        root.pullColumns = root.columns
                        root.pullRows = root.shownRows
                        return
                    }
                    root.resized(root.pullColumns, root.pullRows)
                    root.pullColumns = 0
                    root.pullRows = 0
                }

                onCentroidChanged: {
                    if (!stretch.active)
                        return
                    const dx = stretch.centroid.scenePosition.x - stretch.centroid.scenePressPosition.x
                    const dy = stretch.centroid.scenePosition.y - stretch.centroid.scenePressPosition.y
                    const roomX = root.width - Theme.desktopGutter - card.x - 2 * root.pad
                    const roomY = root.height - Theme.desktopGutter - card.y - 2 * root.pad
                    const most = Math.max(root.widest, Math.floor((roomX + root.street) / root.strideX))
                    const deepest = Math.max(1, Math.floor((roomY + root.street) / root.strideY))
                    const across = Math.round((stretch.fromWidth + dx + root.street) / root.strideX)
                    const down = Math.round((stretch.fromHeight + dy + root.street) / root.strideY)
                    root.pullColumns = Math.max(root.widest, Math.min(most, across))
                    root.pullRows = Math.max(1, Math.min(deepest, down))
                }
            }
        }
    }
}
