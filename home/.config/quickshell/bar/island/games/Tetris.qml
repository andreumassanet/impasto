// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T E T R I S                                                            │
// │   ten by twenty · arrows or WASD, space drops                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Tetris: a 10×20 well and seven-bag randomisation. Left and right move, up
// rotates clockwise with a wall kick, down soft-drops, space hard-drops.
// Gravity speeds up each level of ten lines.
//
// Standard scoring: one point per soft-dropped row, two per hard-dropped row,
// and 100, 300, 500 or 800 for one to four lines times the level. The round
// ends when a piece can't spawn.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    // Rows gone and what they paid, for the flash over the well.
    signal swept(int rows, int paid)

    function restart(): void {
        root.board = new Array(root.columns * root.rows).fill(0)
        root.bag = []
        root.lines = 0
        root.score = 0
        root.over = false
        root.next = root.deal()
        root.spawn()
    }

    // ── WELL ────────────────────────────────────────────────────────────────

    readonly property int columns: 10
    readonly property int rows: 20

    // Side column width, the gap to it, and the vertical margin. A cell is
    // whatever fits all three; the preview draws at three quarters.
    readonly property int panel: 120
    readonly property int gap: 20
    readonly property int air: 40
    readonly property int cell: Math.max(1, Math.floor(Math.min(
        (root.width - root.panel - root.gap) / root.columns,
        (root.height - 2 * root.air) / root.rows)))
    readonly property int mini: Math.max(1, Math.floor(root.cell * 0.75))

    // Two hundred cells, row-major from the top, each a piece index or 0;
    // rebuilt when a piece locks.
    property var board: []

    // ── PIECES ──────────────────────────────────────────────────────────────

    // Indexed from one so 0 means empty: I, O, T, S, Z, J and L, each in its
    // rotation box.
    readonly property var shapes: [
        null,
        [[0, 0, 0, 0], [1, 1, 1, 1], [0, 0, 0, 0], [0, 0, 0, 0]],
        [[1, 1], [1, 1]],
        [[0, 1, 0], [1, 1, 1], [0, 0, 0]],
        [[0, 1, 1], [1, 1, 0], [0, 0, 0]],
        [[1, 1, 0], [0, 1, 1], [0, 0, 0]],
        [[1, 0, 0], [1, 1, 1], [0, 0, 0]],
        [[0, 0, 1], [1, 1, 1], [0, 0, 0]]
    ]

    // One colour token per piece, in the same order: the T uses the frame's
    // tint, the rest palette hues, so a palette switch repaints the stack.
    readonly property var paints: [
        null, Theme.blue, Theme.yellow, root.tint, Theme.green, Theme.red,
        Theme.accentHover, Theme.textMuted
    ]

    // The active piece: kind, rotated cells and box position. Replaced whole on
    // every move.
    property var piece: null
    property int next: 0
    property var bag: []
    property int lines: 0
    readonly property int level: 1 + Math.floor(root.lines / 10)

    focus: true

    Component.onCompleted: root.restart()

    // Both canvases repaint whenever their data is reassigned.
    onBoardChanged: well.requestPaint()
    onPieceChanged: well.requestPaint()
    onNextChanged: preview.requestPaint()
    onPaintsChanged: { well.requestPaint(); preview.requestPaint() }

    // Seven-bag: all seven shuffled and dealt until empty, so a shape never
    // goes missing for more than twelve pieces.
    function deal(): int {
        let bag = root.bag
        if (bag.length === 0) {
            bag = [1, 2, 3, 4, 5, 6, 7]
            for (let index = bag.length - 1; index > 0; index--) {
                const other = Math.floor(Math.random() * (index + 1));
                [bag[index], bag[other]] = [bag[other], bag[index]]
            }
        }
        root.bag = bag.slice(1)
        return bag[0]
    }

    // A clockwise quarter turn within the piece's box.
    function rotated(cells: var): var {
        const size = cells.length
        return cells.map((line, row) => line.map((_, column) => cells[size - 1 - column][row]))
    }

    // The well cells a piece covers with its box at (x, y).
    function covered(cells: var, x: int, y: int): var {
        const out = []
        for (let row = 0; row < cells.length; row++)
            for (let column = 0; column < cells.length; column++)
                if (cells[row][column])
                    out.push({ x: x + column, y: y + row })
        return out
    }

    // Whether a piece fits there. Rows above the well are allowed (pieces spawn
    // there); everything else outside is a wall.
    function fits(cells: var, x: int, y: int): bool {
        return root.covered(cells, x, y).every(at =>
            at.x >= 0 && at.x < root.columns && at.y < root.rows
            && (at.y < 0 || !root.board[at.y * root.columns + at.x]))
    }

    // Spawns the next piece centred at the top and deals the one after. No room
    // ends the round.
    function spawn(): void {
        const kind = root.next
        root.next = root.deal()
        const cells = root.shapes[kind]
        const top = cells.findIndex(row => row.some(filled => filled))
        const x = Math.floor((root.columns - cells.length) / 2)
        root.piece = { kind: kind, cells: cells, x: x, y: -top }
        if (!root.fits(cells, x, -top)) {
            root.over = true
            root.finished(root.score)
        }
    }

    function move(dx: int): void {
        const piece = root.piece
        if (root.fits(piece.cells, piece.x + dx, piece.y))
            root.piece = Object.assign({}, piece, { x: piece.x + dx })
    }

    // Clockwise, trying in place and then one step off either wall.
    function rotate(): void {
        const piece = root.piece
        const cells = root.rotated(piece.cells)
        for (const kick of [0, -1, 1]) {
            if (root.fits(cells, piece.x + kick, piece.y)) {
                root.piece = Object.assign({}, piece, { cells: cells, x: piece.x + kick })
                return
            }
        }
    }

    // Moves down one row if possible, otherwise locks. Returns which, since a
    // soft drop only scores rows actually fallen.
    function fall(): bool {
        const piece = root.piece
        if (!root.fits(piece.cells, piece.x, piece.y + 1)) {
            root.lock()
            return false
        }
        root.piece = Object.assign({}, piece, { y: piece.y + 1 })
        return true
    }

    function softDrop(): void {
        if (root.fall())
            root.score += 1
    }

    // Resting row, for the ghost and the hard drop.
    function landing(): int {
        const piece = root.piece
        let y = piece.y
        while (root.fits(piece.cells, piece.x, y + 1))
            y++
        return y
    }

    function hardDrop(): void {
        const piece = root.piece
        const y = root.landing()
        root.score += 2 * (y - piece.y)
        root.piece = Object.assign({}, piece, { y: y })
        root.lock()
    }

    // Locks the piece, clears full rows and settles the rest. A piece locking
    // partly above the well ends the round.
    function lock(): void {
        const piece = root.piece
        const board = root.board.slice()
        const cells = root.covered(piece.cells, piece.x, piece.y)
        for (const at of cells)
            if (at.y >= 0)
                board[at.y * root.columns + at.x] = piece.kind
        const kept = []
        for (let y = 0; y < root.rows; y++) {
            const line = board.slice(y * root.columns, (y + 1) * root.columns)
            if (!line.every(kind => kind))
                kept.push(line)
        }
        const cleared = root.rows - kept.length
        while (kept.length < root.rows)
            kept.unshift(new Array(root.columns).fill(0))
        root.board = kept.reduce((all, line) => all.concat(line), [])
        if (cleared > 0) {
            const paid = [0, 100, 300, 500, 800][cleared] * root.level
            root.score += paid
            root.lines += cleared
            root.swept(cleared, paid)
        }
        if (cells.some(at => at.y < 0)) {
            root.over = true
            root.finished(root.score)
            return
        }
        root.spawn()
    }

    // One block, shared by the well and the preview: inset and rounded so
    // pieces read as pieces.
    function block(ctx: var, x: real, y: real, size: int, paint: color, faint: bool): void {
        const inset = Math.max(1, Math.round(size * 0.1))
        const side = size - 2 * inset
        const corner = size * 0.2
        const left = x + inset
        const top = y + inset
        const alpha = faint ? 0.22 : 1
        const tone = (colour, at) =>
            `rgba(${Math.round(colour.r * 255)},${Math.round(colour.g * 255)},`
            + `${Math.round(colour.b * 255)},${at})`

        // Lit from above, with the light on the top edge and the shade under
        // it: a slab rather than a square of colour.
        const face = ctx.createLinearGradient(0, top, 0, top + side)
        face.addColorStop(0, tone(Qt.lighter(paint, 1.25), alpha))
        face.addColorStop(0.5, tone(paint, alpha))
        face.addColorStop(1, tone(Qt.darker(paint, 1.3), alpha))
        ctx.fillStyle = face
        ctx.beginPath()
        ctx.roundedRect(left, top, side, side, corner, corner)
        ctx.fill()

        if (faint)
            return

        ctx.fillStyle = tone(Theme.indicator, 0.22)
        ctx.beginPath()
        ctx.roundedRect(left + side * 0.16, top + side * 0.12, side * 0.5, side * 0.14,
                        side * 0.07, side * 0.07)
        ctx.fill()

        ctx.strokeStyle = tone(Qt.darker(paint, 1.5), 0.8)
        ctx.lineWidth = Math.max(1, size * 0.04)
        ctx.beginPath()
        ctx.roundedRect(left, top, side, side, corner, corner)
        ctx.stroke()
    }

    // Gravity: 800 ms per row, 70 ms less each level, never under 90.
    Timer {
        interval: Math.max(90, 800 - 70 * (root.level - 1))
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.fall()
    }

    Keys.onPressed: event => {
        // After game over nothing moves and keys aren't consumed.
        if (root.over)
            return
        switch (event.key) {
        case Qt.Key_Left:  case Qt.Key_A: root.move(-1);   break
        case Qt.Key_Right: case Qt.Key_D: root.move(1);    break
        case Qt.Key_Up:    case Qt.Key_W: root.rotate();   break
        case Qt.Key_Down:  case Qt.Key_S: root.softDrop(); break
        case Qt.Key_Space:                root.hardDrop(); break
        default: return
        }
        event.accepted = true
    }

    // ── LAYOUT ──────────────────────────────────────────────────────────────

    // A muted mono caption over a plain number.
    component Reading: Column {
        id: reading

        property string caption
        property string value

        spacing: 2

        Text {
            text: reading.caption
            color: Theme.textMuted
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeLabel
        }
        Text {
            text: reading.value
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeLarge
        }
    }

    // Well on the left, side column on the right, centred together.
    Item {
        anchors.centerIn: parent
        width: root.cell * root.columns + root.gap + root.panel
        height: root.cell * root.rows

        Rectangle {
            id: ground

            width: root.cell * root.columns
            height: root.cell * root.rows
            radius: Theme.radiusMedium
            color: Theme.islandSurface
            border.color: Theme.islandBorder
            border.width: 1

            // A sweep flashes the well and says what it paid.
            Connections {
                target: root

                function onSwept(rows: int, paid: int): void {
                    sweep.restart()
                    paidFor.play(`+${paid}`)
                }
            }

            Rectangle {
                id: flash

                anchors.fill: parent
                radius: parent.radius
                color: Theme.indicator
                opacity: 0

                NumberAnimation {
                    id: sweep

                    target: flash
                    property: "opacity"
                    from: 0.35
                    to: 0
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            Pop {
                id: paidFor

                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.4
                tint: Theme.indicator
                rise: root.cell * 1.6
            }

            Canvas {
                id: well

                anchors.fill: parent

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const size = root.cell

                    // The well's own rows and columns, so the empty part of it
                    // is a grid and not a hole.
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.035)
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    for (let column = 1; column < root.columns; column++) {
                        ctx.moveTo(column * size + 0.5, 0)
                        ctx.lineTo(column * size + 0.5, root.rows * size)
                    }
                    for (let row = 1; row < root.rows; row++) {
                        ctx.moveTo(0, row * size + 0.5)
                        ctx.lineTo(root.columns * size, row * size + 0.5)
                    }
                    ctx.stroke()

                    // The stack.
                    root.board.forEach((kind, index) => {
                        if (kind)
                            root.block(ctx, (index % root.columns) * size,
                                       Math.floor(index / root.columns) * size,
                                       size, root.paints[kind], false)
                    })

                    const piece = root.piece
                    if (!piece)
                        return
                    // The ghost, faint, then the piece, both clipped to the
                    // well's rows.
                    const paint = root.paints[piece.kind]
                    const rest = root.landing()
                    if (rest > piece.y)
                        for (const at of root.covered(piece.cells, piece.x, rest))
                            if (at.y >= 0)
                                root.block(ctx, at.x * size, at.y * size, size, paint, true)
                    for (const at of root.covered(piece.cells, piece.x, piece.y))
                        if (at.y >= 0)
                            root.block(ctx, at.x * size, at.y * size, size, paint, false)
                }
            }
        }

        Column {
            anchors.top: parent.top
            anchors.right: parent.right
            width: root.panel
            spacing: root.gap

            Rectangle {
                width: root.panel
                height: root.panel
                radius: Theme.radiusMedium
                color: Theme.islandSurface
                border.color: Theme.islandBorder
                border.width: 1

                Canvas {
                    id: preview

                    anchors.fill: parent

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        const cells = root.shapes[root.next]
                        if (!cells)
                            return
                        // Centred on its occupied cells rather than its box, so
                        // I and O sit as squarely as T.
                        const size = root.mini
                        const covered = root.covered(cells, 0, 0)
                        const xs = covered.map(at => at.x)
                        const ys = covered.map(at => at.y)
                        const left = Math.min(...xs)
                        const top = Math.min(...ys)
                        const ox = Math.round((width - (Math.max(...xs) + 1 - left) * size) / 2)
                        const oy = Math.round((height - (Math.max(...ys) + 1 - top) * size) / 2)
                        for (const at of covered)
                            root.block(ctx, ox + (at.x - left) * size, oy + (at.y - top) * size,
                                       size, root.paints[root.next], false)
                    }
                }
            }

            Reading { caption: "level"; value: String(root.level) }
            Reading { caption: "lines"; value: String(root.lines) }
        }
    }
}
