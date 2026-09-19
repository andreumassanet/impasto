// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M I N I   2 0 4 8                                                      │
// │   four by four · arrows or WASD, and a full board is the end             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// 2048 on a 4×4 board. Tiles slide as far as they can; equal neighbours merge
// once per move (2 2 2 2 becomes 4 4, not 8), and a move that changes nothing
// doesn't count. Each real move adds a 2, or a 4 one time in ten. The round
// ends when the board is full with no merges left; reaching 2048 doesn't end
// it. The score is the sum of all merges.
//
// A Repeater over sixteen values rather than a Canvas: nothing moves between
// key presses.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        const cells = []
        for (let index = 0; index < root.side * root.side; index++)
            cells.push(0)
        root.grid = root.spawn(root.spawn(cells))
        root.score = 0
        root.over = false
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    readonly property int side: 4
    readonly property int gap: 10
    // The largest cell that fits, minus the five gaps around four tiles.
    readonly property int cell: Math.max(1, Math.floor(
        (Math.min(root.width, root.height) - (root.side + 1) * root.gap) / root.side))

    // Sixteen values, row-major; zero is empty.
    property var grid: []

    focus: true

    Component.onCompleted: root.restart()

    // ── RULES ───────────────────────────────────────────────────────────────

    // Adds a 2 (or a 4, one time in ten) on a random free cell. Returns the
    // board unchanged if it is full.
    function spawn(cells: var): var {
        const free = []
        cells.forEach((value, index) => { if (value === 0) free.push(index) })
        if (free.length === 0)
            return cells
        const next = cells.slice()
        next[free[Math.floor(Math.random() * free.length)]] = Math.random() < 0.1 ? 4 : 2
        return next
    }

    // One line, read from the wall the tiles move towards: packed, merged once
    // outward from the wall, then padded with empties.
    function slide(line: var): var {
        const packed = line.filter(value => value !== 0)
        const out = []
        let gained = 0
        for (let index = 0; index < packed.length; index++) {
            if (index + 1 < packed.length && packed[index] === packed[index + 1]) {
                out.push(packed[index] * 2)
                gained += packed[index] * 2
                index++
            } else {
                out.push(packed[index])
            }
        }
        while (out.length < root.side)
            out.push(0)
        return { line: out, gained: gained }
    }

    // No free cell and no equal neighbours in either direction.
    function stuck(cells: var): bool {
        const side = root.side
        for (let y = 0; y < side; y++)
            for (let x = 0; x < side; x++) {
                const value = cells[y * side + x]
                if (value === 0)
                    return false
                if (x + 1 < side && cells[y * side + x + 1] === value)
                    return false
                if (y + 1 < side && cells[(y + 1) * side + x] === value)
                    return false
            }
        return true
    }

    function move(dx: int, dy: int): void {
        if (root.over)
            return
        const side = root.side
        const next = root.grid.slice()
        let gained = 0
        let changed = false
        for (let lane = 0; lane < side; lane++) {
            // This line's cells, nearest the wall first.
            const indices = []
            for (let step = 0; step < side; step++) {
                const near = step
                const far = side - 1 - step
                const x = dx !== 0 ? (dx > 0 ? far : near) : lane
                const y = dy !== 0 ? (dy > 0 ? far : near) : lane
                indices.push(y * side + x)
            }
            const slid = root.slide(indices.map(index => next[index]))
            gained += slid.gained
            indices.forEach((index, step) => {
                if (next[index] !== slid.line[step]) {
                    next[index] = slid.line[step]
                    changed = true
                }
            })
        }
        if (!changed)
            return
        root.score += gained
        root.grid = root.spawn(next)
        if (root.stuck(root.grid)) {
            root.over = true
            root.finished(root.score)
        }
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Up:    case Qt.Key_W: root.move(0, -1); break
        case Qt.Key_Down:  case Qt.Key_S: root.move(0, 1);  break
        case Qt.Key_Left:  case Qt.Key_A: root.move(-1, 0); break
        case Qt.Key_Right: case Qt.Key_D: root.move(1, 0);  break
        default: return
        }
        event.accepted = true
    }

    // ── TILES ───────────────────────────────────────────────────────────────

    // Tint up to 32, accent for 64, yellow for 128–512, red for 1024 and 2048
    // and beyond.
    function fill(value: int): color {
        const t = root.tint
        const y = Theme.yellow
        const r = Theme.red
        switch (value) {
        case 0:    return Theme.islandSurfaceHover
        case 2:    return Qt.rgba(t.r, t.g, t.b, 0.25)
        case 4:    return Qt.rgba(t.r, t.g, t.b, 0.4)
        case 8:    return Qt.rgba(t.r, t.g, t.b, 0.6)
        case 16:   return Qt.rgba(t.r, t.g, t.b, 0.8)
        case 32:   return t
        case 64:   return Theme.accent
        case 128:  return Qt.rgba(y.r, y.g, y.b, 0.7)
        case 256:  return Qt.rgba(y.r, y.g, y.b, 0.85)
        case 512:  return y
        case 1024: return Qt.rgba(r.r, r.g, r.b, 0.85)
        default:   return r
        }
    }

    // White text on dark tiles, black on bright ones, judged by the tile's
    // luminance over the background rather than its value.
    function ink(value: int): color {
        const c = root.fill(value)
        const luma = (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * c.a
        return luma > 0.5 ? Theme.island : Theme.text
    }

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.side * root.cell + (root.side + 1) * root.gap
        height: width
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        Repeater {
            model: root.side * root.side

            Rectangle {
                id: tile

                required property int index
                readonly property int value: root.grid[tile.index] ?? 0

                x: root.gap + (tile.index % root.side) * (root.cell + root.gap)
                y: root.gap + Math.floor(tile.index / root.side) * (root.cell + root.gap)
                width: root.cell
                height: root.cell
                radius: Theme.radiusSmall
                color: root.fill(tile.value)
                border.color: tile.value === 0
                    ? "transparent" : Qt.rgba(0, 0, 0, 0.25)
                border.width: 1

                // Animate the colour so a merge reads as the same tile
                // changing.
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                // A tile that has just taken a value swells and settles: the
                // grid has no identity to slide, so the beat is what says
                // something happened here.
                onValueChanged: {
                    if (tile.value !== 0)
                        swell.restart()
                }

                NumberAnimation {
                    id: swell

                    target: tile
                    property: "scale"
                    from: 1.16
                    to: 1
                    duration: 170
                    easing.type: Easing.OutBack
                }

                // The light on the face, so a tile is a tile and not a patch
                // of colour. A gradient over the colour rather than in it,
                // since the colour is animated on a merge.
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: tile.value !== 0

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                        GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.03) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.14) }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: tile.value !== 0
                    text: String(tile.value)
                    color: root.ink(tile.value)
                    font.family: Theme.fontMono
                    font.weight: Font.DemiBold
                    // Three digits fit at full size; four shrink.
                    font.pixelSize: Math.round(root.cell
                        * (tile.value < 100 ? 0.4 : tile.value < 1000 ? 0.32 : 0.26))
                }
            }
        }
    }
}
