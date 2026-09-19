// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F L O O D                                                              │
// │   fourteen by fourteen · six colours, and the corner eats the board      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Flood-It. The top-left region takes each chosen colour and absorbs the
// neighbouring cells of that colour, until the board is one colour. The score
// is the move count, and `finished` fires only on a solved board; there is no
// losing, and the frame's button restarts.
//
// Picking the corner's current colour is not a move. The grid is a Repeater
// over an array rebuilt each move.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        const next = []
        for (let index = 0; index < root.columns * root.rows; index++)
            next.push(Math.floor(Math.random() * root.colours.length))
        root.grid = next
        root.score = 0
        root.over = false
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    readonly property int columns: 14
    readonly property int rows: 14

    // Cells hold a colour index, so a palette switch repaints without affecting
    // play. Palettes can map two tokens to the same hex (the accent is the blue
    // in three of them), so the six colours are picked from a longer token
    // list, skipping any too close to one already taken.
    readonly property var candidates: [
        Theme.accent, Theme.green, Theme.red, Theme.yellow, Theme.blue,
        Theme.textMuted, Theme.accentHover, Theme.indicatorTimer,
        Theme.indicatorWarn, Theme.text
    ]

    function apart(left: color, right: color): bool {
        const dr = left.r - right.r
        const dg = left.g - right.g
        const db = left.b - right.b
        // Threshold: the accent and its hover count as one colour, cyan and
        // blue as two.
        return dr * dr + dg * dg + db * db > 0.09
    }

    readonly property var colours: {
        const picked = []
        for (const candidate of root.candidates) {
            if (picked.length === 6)
                break
            if (picked.every(taken => root.apart(taken, candidate)))
                picked.push(candidate)
        }
        return picked
    }

    // Swatches sit under the grid as one more row of cells, with padding all
    // round.
    readonly property int pad: Theme.radiusMedium
    readonly property int cell: Math.max(2, Math.floor(Math.min(
        (root.width - 2 * root.pad) / root.columns,
        (root.height - 3 * root.pad) / (root.rows + 1))))

    // Row-major, one colour index per cell.
    property var grid: []

    // The corner's colour is the region's colour.
    readonly property int current: root.grid[0] ?? 0

    focus: true

    Component.onCompleted: root.restart()

    function flood(colour: int): void {
        if (root.over || colour === root.current)
            return
        const from = root.current
        const next = root.grid.slice()
        const around = [[1, 0], [-1, 0], [0, 1], [0, -1]]
        // Flood fill from the corner. Painting before pushing ensures each cell
        // is visited once.
        const stack = [0]
        next[0] = colour
        while (stack.length > 0) {
            const index = stack.pop()
            const x = index % root.columns
            const y = Math.floor(index / root.columns)
            for (const step of around) {
                const nx = x + step[0]
                const ny = y + step[1]
                if (nx < 0 || ny < 0 || nx >= root.columns || ny >= root.rows)
                    continue
                const at = ny * root.columns + nx
                if (next[at] === from) {
                    next[at] = colour
                    stack.push(at)
                }
            }
        }
        root.grid = next
        root.score += 1
        if (next.every(each => each === colour)) {
            root.over = true
            root.finished(root.score)
        }
    }

    Keys.onPressed: event => {
        if (event.key < Qt.Key_1 || event.key > Qt.Key_6)
            return
        root.flood(event.key - Qt.Key_1)
        event.accepted = true
    }

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.cell * root.columns + 2 * root.pad
        height: root.cell * (root.rows + 1) + 3 * root.pad
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        Item {
            id: board

            x: root.pad
            y: root.pad
            width: root.cell * root.columns - 1
            height: root.cell * root.rows - 1

            Repeater {
                model: root.columns * root.rows

                // One pixel of background between cells.
                Rectangle {
                    id: square

                    required property int index

                    // Distance from the corner the flood starts at, in cells:
                    // every square waits that long before it turns, so a move
                    // spreads out of the corner instead of landing at once.
                    readonly property int reach:
                        (square.index % root.columns) + Math.floor(square.index / root.columns)

                    x: (square.index % root.columns) * root.cell
                    y: Math.floor(square.index / root.columns) * root.cell
                    width: root.cell - 1
                    height: root.cell - 1
                    radius: Math.max(1, root.cell * 0.18)
                    color: root.colours[root.grid[square.index] ?? 0]

                    Behavior on color {
                        SequentialAnimation {
                            PauseAnimation { duration: square.reach * 16 }
                            ColorAnimation { duration: 110 }
                        }
                    }

                    // The light on the cell, so the board reads as tiles.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.13) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.02) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.13) }
                        }
                    }
                }
            }
        }

        // Round swatches; the corner's current colour is outlined, and pressing
        // it does nothing.
        Row {
            id: swatches

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.pad
            spacing: root.pad

            Repeater {
                model: root.colours.length

                Rectangle {
                    id: swatch

                    required property int index

                    width: root.cell
                    height: root.cell
                    radius: Theme.radiusPill
                    color: root.colours[index]
                    border.color: Theme.text
                    border.width: index === root.current ? 2 : 0
                    scale: press.containsMouse ? 1.12 : 1

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.18) }
                            GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.0) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.16) }
                        }
                    }

                    Behavior on scale { NumberAnimation { duration: Theme.durationFast } }

                    MouseArea {
                        id: press

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.flood(swatch.index)
                    }
                }
            }
        }
    }
}
