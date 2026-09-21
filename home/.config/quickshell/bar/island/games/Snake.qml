// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S N A K E                                                              │
// │   twenty by twenty · arrows or WASD, and the tail is the enemy           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Snake, and the template for the other games: the contract first, state as
// plain properties, one timer that runs only during a round, and a Canvas for
// the board.
//
// The snake thinks in cells and moves in pixels: the tick decides where it
// goes, `progress` carries it there over the tick's own length, and the board
// repaints on every frame of it.
//
// Ten points per apple; each apple shortens the tick a little.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    // The cell an apple was taken from, for the burst over it.
    signal ate(int column, int row)

    function restart(): void {
        root.body = [{ x: 10, y: 10 }, { x: 9, y: 10 }, { x: 8, y: 10 }]
        root.dx = 1
        root.dy = 0
        root.queued = []
        root.score = 0
        root.eaten = 0
        root.over = false
        root.ghost = null
        root.progress = 1
        root.placeApple()
        board.requestPaint()
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    readonly property int columns: 20
    readonly property int rows: 20
    readonly property int cell: Math.max(1, Math.floor(
        Math.min(root.width / root.columns, root.height / root.rows)))

    // Head first.
    property var body: []
    property var apple: ({ x: 5, y: 5 })
    property int dx: 1
    property int dy: 0

    // Turns queued between ticks, so two quick presses both count and a
    // reversal is checked against the pending turn, not the current direction.
    property var queued: []
    property int eaten: 0

    focus: true

    Component.onCompleted: root.restart()

    // ── THE SLIDE ───────────────────────────────────────────────────────────

    readonly property int tick: Math.max(55, 130 - root.eaten * 3)

    // 0 the moment a step lands, 1 when the next one is due. The head is drawn
    // this far into the cell it is entering and the tail this far out of the
    // one it is leaving, so a round is continuous and the logic is not.
    property real progress: 1

    // The cell the tail left on this step, and null while the snake is
    // growing: the tail has to be drawn retreating out of a cell the body has
    // already forgotten.
    property var ghost: null

    NumberAnimation {
        id: slide

        target: root
        property: "progress"
        from: 0
        to: 1
        // The tick's own length, not a motion token: the Motion setting scales
        // those, and a snake sliding at half speed would arrive after its next
        // step.
        duration: root.tick
    }

    onProgressChanged: board.requestPaint()

    function occupied(x: int, y: int): bool {
        return root.body.some(segment => segment.x === x && segment.y === y)
    }

    function placeApple(): void {
        const free = []
        for (let y = 0; y < root.rows; y++)
            for (let x = 0; x < root.columns; x++)
                if (!root.occupied(x, y))
                    free.push({ x: x, y: y })
        if (free.length === 0)
            return
        root.apple = free[Math.floor(Math.random() * free.length)]
    }

    function turn(nx: int, ny: int): void {
        const last = root.queued.length > 0
            ? root.queued[root.queued.length - 1] : { x: root.dx, y: root.dy }
        if ((nx === -last.x && ny === -last.y) || (nx === last.x && ny === last.y))
            return
        root.queued = root.queued.concat([{ x: nx, y: ny }])
    }

    function step(): void {
        if (root.queued.length > 0) {
            const next = root.queued[0]
            root.queued = root.queued.slice(1)
            root.dx = next.x
            root.dy = next.y
        }
        const head = root.body[0]
        const next = { x: head.x + root.dx, y: head.y + root.dy }
        const ate = next.x === root.apple.x && next.y === root.apple.y
        // The tail moves out of the way in the same tick unless the snake is
        // growing.
        const kept = ate ? root.body : root.body.slice(0, -1)
        const hitWall = next.x < 0 || next.y < 0
            || next.x >= root.columns || next.y >= root.rows
        if (hitWall || kept.some(segment => segment.x === next.x && segment.y === next.y)) {
            root.over = true
            root.ghost = null
            root.progress = 1
            root.finished(root.score)
            board.requestPaint()
            return
        }
        root.ghost = ate ? null : root.body[root.body.length - 1]
        root.body = [next].concat(kept)
        if (ate) {
            root.eaten += 1
            root.score += 10
            root.ate(next.x, next.y)
            root.placeApple()
        }
        slide.restart()
    }

    Timer {
        interval: root.tick
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.step()
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Up:    case Qt.Key_W: root.turn(0, -1); break
        case Qt.Key_Down:  case Qt.Key_S: root.turn(0, 1);  break
        case Qt.Key_Left:  case Qt.Key_A: root.turn(-1, 0); break
        case Qt.Key_Right: case Qt.Key_D: root.turn(1, 0);  break
        default: return
        }
        event.accepted = true
    }

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.cell * root.columns
        height: root.cell * root.rows
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        // The cells, painted once: a board the snake can be read against, and
        // nothing that repaints with it.
        Canvas {
            id: grid

            anchors.fill: parent
            onWidthChanged: grid.requestPaint()
            onHeightChanged: grid.requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const size = root.cell
                const dot = Math.max(1, Math.round(size * 0.07))
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.05)
                for (let y = 0; y < root.rows; y++) {
                    for (let x = 0; x < root.columns; x++) {
                        ctx.beginPath()
                        ctx.arc(x * size + size / 2, y * size + size / 2,
                                dot, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
        }

        Canvas {
            id: board

            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const size = root.cell
                const count = root.body.length
                if (count === 0)
                    return

                const centre = point => ({
                    x: point.x * size + size / 2,
                    y: point.y * size + size / 2
                })
                const between = (from, to, at) => ({
                    x: from.x + (to.x - from.x) * at,
                    y: from.y + (to.y - from.y) * at
                })

                // ── THE APPLE ───────────────────────────────────────────────

                const apple = centre(root.apple)
                const beat = 1 + 0.05 * Math.sin(Date.now() / 260)
                const radius = size * 0.34 * beat

                ctx.fillStyle = Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.18)
                ctx.beginPath()
                ctx.arc(apple.x, apple.y, radius * 1.7, 0, Math.PI * 2)
                ctx.fill()

                ctx.fillStyle = Theme.red
                ctx.beginPath()
                ctx.arc(apple.x, apple.y, radius, 0, Math.PI * 2)
                ctx.fill()

                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.55)
                ctx.beginPath()
                ctx.arc(apple.x - radius * 0.34, apple.y - radius * 0.36,
                        radius * 0.26, 0, Math.PI * 2)
                ctx.fill()

                ctx.strokeStyle = Theme.green
                ctx.lineWidth = Math.max(1, size * 0.07)
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(apple.x, apple.y - radius * 0.9)
                ctx.lineTo(apple.x + radius * 0.34, apple.y - radius * 1.5)
                ctx.stroke()

                // ── THE SNAKE ───────────────────────────────────────────────

                // Head first: the head slid into the cell it is entering, then
                // every cell it is already in, then the tail slid out of the
                // one it is leaving.
                const points = []
                points.push(count > 1
                    ? between(centre(root.body[1]), centre(root.body[0]), root.progress)
                    : centre(root.body[0]))
                for (let index = 1; index < count; index++)
                    points.push(centre(root.body[index]))
                if (root.ghost)
                    points.push(between(centre(root.ghost),
                                        centre(root.body[count - 1]), root.progress))

                const last = points.length - 1
                const girth = at => size * (0.78 - 0.34 * at)
                const paint = (at, lift) => {
                    const ground = Theme.islandSurface
                    const mix = at * 0.45
                    const shade = {
                        r: root.tint.r + (ground.r - root.tint.r) * mix,
                        g: root.tint.g + (ground.g - root.tint.g) * mix,
                        b: root.tint.b + (ground.b - root.tint.b) * mix
                    }
                    return Qt.rgba(shade.r + (1 - shade.r) * lift,
                                   shade.g + (1 - shade.g) * lift,
                                   shade.b + (1 - shade.b) * lift, 1)
                }

                // Drawn tail first so the head sits on top. One stroke per
                // segment, because the body thins and darkens along its
                // length; round caps and joins hide the seams.
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                for (let index = last - 1; index >= 0; index--) {
                    const at = index / Math.max(1, last)
                    ctx.strokeStyle = paint(at, 0)
                    ctx.lineWidth = girth(at)
                    ctx.beginPath()
                    ctx.moveTo(points[index + 1].x, points[index + 1].y)
                    ctx.lineTo(points[index].x, points[index].y)
                    ctx.stroke()
                }

                // ── THE HEAD ────────────────────────────────────────────────

                const head = points[0]
                ctx.fillStyle = paint(0, 0)
                ctx.beginPath()
                ctx.arc(head.x, head.y, size * 0.45, 0, Math.PI * 2)
                ctx.fill()

                // The light on a round back: one path over the whole snake,
                // head included, offset towards the top left. One stroke,
                // since strokes per segment band where they overlap.
                ctx.strokeStyle = paint(0, 0.34)
                ctx.lineWidth = size * 0.2
                ctx.beginPath()
                ctx.moveTo(head.x - size * 0.13, head.y - size * 0.14)
                for (let index = 1; index <= last; index++)
                    ctx.lineTo(points[index].x - size * 0.1,
                               points[index].y - size * 0.1)
                ctx.stroke()

                // Eyes on the sides of the direction of travel, each with a
                // pupil looking the way the snake is going.
                for (const side of [-1, 1]) {
                    const ex = head.x + root.dx * size * 0.15 - root.dy * side * size * 0.19
                    const ey = head.y + root.dy * size * 0.15 + root.dx * side * size * 0.19
                    ctx.fillStyle = Theme.indicator
                    ctx.beginPath()
                    ctx.arc(ex, ey, size * 0.13, 0, Math.PI * 2)
                    ctx.fill()
                    ctx.fillStyle = Theme.island
                    ctx.beginPath()
                    ctx.arc(ex + root.dx * size * 0.05, ey + root.dy * size * 0.05,
                            size * 0.07, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }

        Connections {
            target: root

            function onAte(column: int, row: int): void {
                eaten.x = column * root.cell + root.cell / 2 - eaten.width / 2
                eaten.y = row * root.cell + root.cell / 2 - eaten.height / 2
                paid.x = column * root.cell + root.cell / 2 - paid.width / 2
                paid.y = row * root.cell - root.cell * 0.4
                eaten.play()
                paid.play("+10")
            }
        }

        Burst {
            id: eaten

            tint: Theme.red
            spread: root.cell * 1.1
            sparks: 6
        }

        Pop {
            id: paid

            tint: Theme.red
            rise: root.cell
        }
    }
}
