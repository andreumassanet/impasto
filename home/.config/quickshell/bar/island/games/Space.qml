// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S P A C E                                                              │
// │   five by four · left and right, space to fire, three lives              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Space Blaster: a ship at the bottom and a formation of twenty invaders that
// sweeps sideways and steps down at each edge, speeding up as it thins. One
// Canvas repainted at 30 fps from state rebuilt each tick. At most three shots
// in flight, three lives, and a second of invulnerability after a hit.
//
// Ten points per invader, twenty for the front row; each wave is faster. The
// round ends when the lives run out or the formation reaches the ship's row.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        root.score = 0
        root.lives = 3
        root.wave = 0
        root.shield = 0
        root.shipAt = 0.5
        root.leftHeld = false
        root.rightHeld = false
        root.stars = root.scatter()
        root.blasts = []
        root.ticks = 0
        root.over = false
        root.spawnWave()
        board.requestPaint()
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    // Designed at 520×600 and scaled from the actual size: a column is a tenth
    // of the width, and everything else derives from it.
    readonly property int boardWidth: Math.floor(root.width)
    readonly property int boardHeight: Math.floor(root.height)
    readonly property int margin: 16

    readonly property int columns: 5
    readonly property int rows: 4
    readonly property int columnStride: Math.max(1, Math.floor(root.boardWidth / 10))
    readonly property int rowStride: Math.floor(root.columnStride * 0.85)
    readonly property int invaderSize: Math.floor(root.columnStride * 0.58)
    readonly property int formationTop: 64
    readonly property int dropStep: 18

    readonly property int shipWidth: Math.floor(root.columnStride * 0.7)
    readonly property int shipHeight: Math.floor(root.shipWidth * 0.6)
    readonly property int shipTop: root.boardHeight - 40 - root.shipHeight
    readonly property int shipSpeed: 7
    readonly property int shotLength: 10
    readonly property int shotSpeed: 11
    readonly property int bombSpeed: 5
    readonly property int shotsInFlight: 3
    readonly property int bombsInFlight: 3

    // ── STATE ───────────────────────────────────────────────────────────────

    // Surviving invaders as column and row within the formation; the
    // formation's position is one pair of numbers.
    property var invaders: []
    property real formX: 0
    property real formY: 0
    property int formDir: 1

    // Ours go up, theirs come down.
    property var shots: []
    property var bombs: []

    // Ship position as 0–1 rather than pixels, so it is centred before the
    // board has a size.
    property real shipAt: 0.5
    property int lives: 3
    property int wave: 0
    // Invulnerability ticks left after a hit; the ship blinks meanwhile.
    property int shield: 0

    property var stars: []
    property bool leftHeld: false
    property bool rightHeld: false

    // Ticks, for the two frames every invader walks in and the flicker in the
    // ship's engine, and the blasts left behind by the ones that are gone.
    property int ticks: 0
    property var blasts: []

    readonly property int lane: Math.max(1, root.boardWidth - 2 * root.margin - root.shipWidth)
    readonly property real shipX: root.margin + root.shipWidth / 2 + root.shipAt * root.lane

    // Formation speed per tick: a base that rises with the wave, multiplied as
    // the formation thins.
    readonly property real pace: {
        const thinned = 1 - root.invaders.length / (root.columns * root.rows)
        return Math.min(10, (1.8 + 0.5 * root.wave) * (1 + 2 * thinned))
    }
    readonly property real bombChance: 0.02 + 0.006 * root.wave

    focus: true

    Component.onCompleted: root.restart()

    // Release held keys when focus leaves, or they would stay down.
    onActiveFocusChanged: {
        if (!root.activeFocus) {
            root.leftHeld = false
            root.rightHeld = false
        }
    }

    // Eleven cells across and eight down, two frames each: the row decides
    // which creature and what it is worth.
    readonly property var shapes: ({
        squid: [[
            "....###....",
            "...#####...",
            "..#######..",
            "..##.#.##..",
            "..#######..",
            "...#.#.#...",
            "..#.#.#.#..",
            "...#...#..."
        ], [
            "....###....",
            "...#####...",
            "..#######..",
            "..##.#.##..",
            "..#######..",
            "...#.#.#...",
            "..#.....#..",
            "...#...#..."
        ]],
        crab: [[
            "..#.....#..",
            "...#...#...",
            "..#######..",
            ".##.###.##.",
            "###########",
            "#.#######.#",
            "#.#.....#.#",
            "...##.##..."
        ], [
            "..#.....#..",
            "#..#...#..#",
            "#.#######.#",
            "###.###.###",
            "###########",
            ".#########.",
            "..#.....#..",
            ".#.......#."
        ]],
        octopus: [[
            "...#####...",
            "..#######..",
            ".#########.",
            "###..#..###",
            "###########",
            "..###.###..",
            ".##.....##.",
            "...##.##..."
        ], [
            "...#####...",
            "..#######..",
            ".#########.",
            "###..#..###",
            "###########",
            "...#.#.#...",
            "..#.#.#.#..",
            ".##.....##."
        ]]
    })

    // The front row is worth double and wears the colour that says so.
    function breedOf(row: int): string {
        if (row === root.rows - 1)
            return "octopus"
        return row === 0 ? "squid" : "crab"
    }

    function colourOf(row: int): color {
        if (row === root.rows - 1)
            return Theme.yellow
        return row === 0 ? Theme.green : Theme.red
    }

    function scatter(): var {
        const sky = []
        for (let index = 0; index < 60; index++)
            sky.push({
                x: Math.random(),
                y: Math.random(),
                r: 0.7 + Math.random() * 1.4,
                lit: 0.12 + Math.random() * 0.4,
                blink: index % 7 === 0
            })
        return sky
    }

    function spawnWave(): void {
        const formation = []
        for (let r = 0; r < root.rows; r++)
            for (let c = 0; c < root.columns; c++)
                formation.push({ c: c, r: r })
        root.invaders = formation
        root.formX = root.margin
        root.formY = root.formationTop
        root.formDir = 1
        root.shots = []
        root.bombs = []
    }

    function invaderX(invader: var): real {
        return root.formX + invader.c * root.columnStride
    }

    function invaderY(invader: var): real {
        return root.formY + invader.r * root.rowStride
    }

    function fire(): void {
        if (root.over || root.shots.length >= root.shotsInFlight)
            return
        root.shots = root.shots.concat([{ x: root.shipX, y: root.shipTop - root.shotLength }])
    }

    // Bombs drop from the lowest invader of a random column, so none fires
    // through its own front row.
    function dropBomb(): void {
        const pick = root.invaders[Math.floor(Math.random() * root.invaders.length)]
        const lowest = root.invaders
            .filter(invader => invader.c === pick.c)
            .reduce((a, b) => b.r > a.r ? b : a)
        root.bombs = root.bombs.concat([{
            x: root.invaderX(lowest) + root.invaderSize / 2,
            y: root.invaderY(lowest) + root.invaderSize
        }])
    }

    function end(): void {
        root.over = true
        root.finished(root.score)
        board.requestPaint()
    }

    readonly property int blastLife: 9

    function step(): void {
        root.ticks += 1
        root.blasts = root.blasts
            .map(blast => ({ x: blast.x, y: blast.y, life: blast.life - 1, tint: blast.tint }))
            .filter(blast => blast.life > 0)

        // Ship.
        const heading = (root.rightHeld ? 1 : 0) - (root.leftHeld ? 1 : 0)
        root.shipAt = Math.max(0, Math.min(1, root.shipAt + heading * root.shipSpeed / root.lane))
        if (root.shield > 0)
            root.shield -= 1

        // Our shots, and hits.
        const size = root.invaderSize
        let standing = root.invaders
        const flying = []
        for (const shot of root.shots) {
            const y = shot.y - root.shotSpeed
            if (y + root.shotLength < 0)
                continue
            const hit = standing.findIndex(invader =>
                shot.x >= root.invaderX(invader) && shot.x <= root.invaderX(invader) + size
                && y <= root.invaderY(invader) + size && y + root.shotLength >= root.invaderY(invader))
            if (hit === -1) {
                flying.push({ x: shot.x, y: y })
                continue
            }
            const struck = standing[hit]
            root.score += struck.r === root.rows - 1 ? 20 : 10
            root.blasts = root.blasts.concat([{
                x: root.invaderX(struck) + size / 2,
                y: root.invaderY(struck) + size / 2,
                life: root.blastLife,
                tint: root.colourOf(struck.r)
            }])
            standing = standing.filter((invader, index) => index !== hit)
        }
        root.shots = flying
        root.invaders = standing
        if (standing.length === 0) {
            root.wave += 1
            root.spawnWave()
            board.requestPaint()
            return
        }

        // Formation: sideways, stepping down when its own edge (not the grid's)
        // reaches a side.
        const cs = standing.map(invader => invader.c)
        const minC = Math.min(...cs)
        const maxC = Math.max(...cs)
        let x = root.formX + root.formDir * root.pace
        let y = root.formY
        const leftEdge = x + minC * root.columnStride
        const rightEdge = x + maxC * root.columnStride + size
        if (leftEdge < root.margin || rightEdge > root.boardWidth - root.margin) {
            x = leftEdge < root.margin
                ? root.margin - minC * root.columnStride
                : root.boardWidth - root.margin - size - maxC * root.columnStride
            y += root.dropStep
            root.formDir = -root.formDir
        }
        root.formX = x
        root.formY = y
        const maxR = Math.max(...standing.map(invader => invader.r))
        if (y + maxR * root.rowStride + size >= root.shipTop) {
            root.end()
            return
        }

        // Bombs, and hits. The shield makes the ship unhittable.
        const falling = []
        let struck = false
        for (const bomb of root.bombs) {
            const by = bomb.y + root.bombSpeed
            if (by > root.boardHeight)
                continue
            const onShip = root.shield === 0 && !struck
                && Math.abs(bomb.x - root.shipX) <= root.shipWidth / 2
                && by + root.shotLength >= root.shipTop && by <= root.shipTop + root.shipHeight
            if (onShip) {
                struck = true
                continue
            }
            falling.push({ x: bomb.x, y: by })
        }
        root.bombs = falling
        if (struck) {
            root.lives -= 1
            root.shield = 30
            if (root.lives === 0) {
                root.end()
                return
            }
        }
        if (root.bombs.length < root.bombsInFlight && Math.random() < root.bombChance)
            root.dropBomb()
        board.requestPaint()
    }

    Timer {
        interval: 33
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.step()
    }

    // Left and right are held, not tapped: the tick reads them. Auto-repeat is
    // ignored; only a real release clears them.
    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:  case Qt.Key_A: root.leftHeld = true; break
        case Qt.Key_Right: case Qt.Key_D: root.rightHeld = true; break
        case Qt.Key_Space: if (!event.isAutoRepeat) root.fire(); break
        default: return
        }
        event.accepted = true
    }

    Keys.onReleased: event => {
        switch (event.key) {
        case Qt.Key_Left:  case Qt.Key_A: if (!event.isAutoRepeat) root.leftHeld = false; break
        case Qt.Key_Right: case Qt.Key_D: if (!event.isAutoRepeat) root.rightHeld = false; break
        case Qt.Key_Space: break
        default: return
        }
        event.accepted = true
    }

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.boardWidth
        height: root.boardHeight
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        Canvas {
            id: board

            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const size = root.invaderSize

                const paintOf = (colour, alpha) =>
                    `rgba(${Math.round(colour.r * 255)},${Math.round(colour.g * 255)},`
                    + `${Math.round(colour.b * 255)},${alpha})`

                // Stars, each at its own strength and one in seven
                // breathing.
                for (const star of root.stars) {
                    const twinkle = star.lit
                        + (star.blink ? 0.18 * Math.sin(root.ticks / 9 + star.x * 30) : 0)
                    ctx.fillStyle = paintOf(Theme.indicator, Math.max(0.05, twinkle))
                    ctx.beginPath()
                    ctx.arc(star.x * width, star.y * height, star.r, 0, Math.PI * 2)
                    ctx.fill()
                }

                // The formation, drawn cell by cell from its row's shape. Both
                // frames march on the same clock, so the wall steps together.
                const frame = Math.floor(root.ticks / 9) % 2
                for (const invader of root.invaders) {
                    const shape = root.shapes[root.breedOf(invader.r)][frame]
                    const unit = size / shape[0].length
                    const x = root.invaderX(invader)
                    const y = root.invaderY(invader) + (size - unit * shape.length) / 2
                    ctx.fillStyle = root.colourOf(invader.r)
                    for (let row = 0; row < shape.length; row++) {
                        const cells = shape[row]
                        let at = 0
                        while (at < cells.length) {
                            if (cells[at] !== "#") {
                                at += 1
                                continue
                            }
                            let run = 1
                            while (at + run < cells.length && cells[at + run] === "#")
                                run += 1
                            ctx.fillRect(x + at * unit, y + row * unit,
                                         unit * run + 0.5, unit + 0.5)
                            at += run
                        }
                    }
                }

                // What is left of the ones that are gone: a ring and its
                // pieces, thrown out of where they stood.
                for (const blast of root.blasts) {
                    const at = 1 - blast.life / root.blastLife
                    ctx.strokeStyle = paintOf(blast.tint, 1 - at)
                    ctx.lineWidth = Math.max(1, size * 0.1 * (1 - at))
                    ctx.beginPath()
                    ctx.arc(blast.x, blast.y, size * (0.25 + at * 0.6), 0, Math.PI * 2)
                    ctx.stroke()
                    ctx.fillStyle = paintOf(blast.tint, 1 - at)
                    for (let spark = 0; spark < 6; spark++) {
                        const angle = spark * Math.PI / 3
                        ctx.beginPath()
                        ctx.arc(blast.x + Math.cos(angle) * size * (0.2 + at * 0.8),
                                blast.y + Math.sin(angle) * size * (0.2 + at * 0.8),
                                size * 0.09 * (1 - at), 0, Math.PI * 2)
                        ctx.fill()
                    }
                }

                // Shots up, bombs down, each in its own light.
                const bolt = (x, y, colour) => {
                    ctx.fillStyle = paintOf(colour, 0.25)
                    ctx.fillRect(x - 2.5, y - 2, 5, root.shotLength + 4)
                    ctx.fillStyle = paintOf(colour, 1)
                    ctx.fillRect(x - 1, y, 2, root.shotLength)
                }
                for (const shot of root.shots)
                    bolt(shot.x, shot.y, root.tint)
                for (const bomb of root.bombs)
                    bolt(bomb.x, bomb.y, Theme.red)

                // The ship: a hull, a cockpit and an engine that flickers. It
                // skips frames while invulnerable.
                if (Math.floor(root.shield / 3) % 2 === 0) {
                    const sx = root.shipX
                    const st = root.shipTop
                    const sw = root.shipWidth
                    const sh = root.shipHeight

                    ctx.fillStyle = paintOf(Theme.yellow, 0.75)
                    const flame = sh * (0.3 + 0.22 * Math.abs(Math.sin(root.ticks / 2)))
                    ctx.beginPath()
                    ctx.moveTo(sx - sw * 0.12, st + sh)
                    ctx.lineTo(sx, st + sh + flame)
                    ctx.lineTo(sx + sw * 0.12, st + sh)
                    ctx.closePath()
                    ctx.fill()

                    const hull = ctx.createLinearGradient(0, st, 0, st + sh)
                    hull.addColorStop(0, paintOf(Qt.lighter(root.tint, 1.4), 1))
                    hull.addColorStop(1, paintOf(Qt.darker(root.tint, 1.35), 1))
                    ctx.fillStyle = hull
                    ctx.beginPath()
                    ctx.moveTo(sx, st)
                    ctx.lineTo(sx + sw * 0.22, st + sh * 0.62)
                    ctx.lineTo(sx + sw * 0.5, st + sh * 0.72)
                    ctx.lineTo(sx + sw * 0.5, st + sh)
                    ctx.lineTo(sx - sw * 0.5, st + sh)
                    ctx.lineTo(sx - sw * 0.5, st + sh * 0.72)
                    ctx.lineTo(sx - sw * 0.22, st + sh * 0.62)
                    ctx.closePath()
                    ctx.fill()

                    ctx.fillStyle = paintOf(Theme.indicator, 0.85)
                    ctx.beginPath()
                    ctx.arc(sx, st + sh * 0.6, sw * 0.09, 0, Math.PI * 2)
                    ctx.fill()
                }

                // Lives, top right, dimming as they go.
                const dot = 5
                for (let index = 0; index < 3; index++) {
                    const kept = index < root.lives
                    ctx.fillStyle = Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, kept ? 1 : 0.25)
                    ctx.beginPath()
                    ctx.arc(width - root.margin - dot - index * (dot * 2 + 6),
                            root.margin + dot, dot, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }
}
