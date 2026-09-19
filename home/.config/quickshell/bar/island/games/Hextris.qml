// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   H E X T R I S                                                          │
// │   six lanes · turn the hexagon under the falling slab, three clear       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Hextris: a central hexagon with six lanes running in to its sides. Slabs fall
// down a lane and stack on the side beneath; the arrows rotate the hexagon and
// its stacks. Three or more touching slabs of one colour, along a side or
// around a ring, clear, and the outer slabs settle in. A stack nine deep ends
// the round.
//
// Ten points per slab cleared, multiplied by the chain length; the fall speeds
// up with the score.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        root.stacks = [[], [], [], [], [], []]
        root.turn = 0
        root.spin = 0
        root.flash = []
        root.flashLeft = 0
        root.chain = 1
        root.score = 0
        root.over = false
        root.spawn()
        board.requestPaint()
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    readonly property int sides: 6
    readonly property int rings: 8
    readonly property int size: Math.max(1, Math.floor(Math.min(root.width, root.height)))

    // Hexagon radius and ring thickness, sized so eight rings plus a falling
    // slab fit in half the board.
    readonly property int core: Math.floor(root.size * 0.09)
    readonly property int ring: Math.floor(root.size * 0.035)

    // Positions are in rings from the hexagon, not pixels, so a round can start
    // before the board is sized.
    readonly property real spawnAt: 10.5
    readonly property real pace: Math.min(0.34, 0.1 + root.score / 5000)
    readonly property real dropPace: 0.8

    readonly property var colours: [root.tint, Theme.green, Theme.yellow, Theme.blue]

    // One array per side, innermost first; each entry is an index into
    // `colours`.
    property var stacks: []

    // Turns applied, and the drawn rotation that eases after it.
    property int turn: 0
    property real spin: 0

    // The falling slab: screen lane, colour, and distance out.
    property var falling: ({ lane: 0, colour: 0, at: 0 })
    property bool dropping: false

    // Matched slabs stay lit for a few frames so chains read one clear at a
    // time.
    property var flash: []
    property int flashLeft: 0
    readonly property int flashFrames: 7
    property int chain: 1

    focus: true

    Component.onCompleted: root.restart()

    // ── RULES ───────────────────────────────────────────────────────────────

    // The hexagon side under a lane, after the turns.
    function sideUnder(lane: int): int {
        return ((lane - root.turn) % root.sides + root.sides) % root.sides
    }

    function key(side: int, level: int): int {
        return side * 100 + level
    }

    function spawn(): void {
        root.falling = {
            lane: Math.floor(Math.random() * root.sides),
            colour: Math.floor(Math.random() * root.colours.length),
            at: root.spawnAt
        }
        root.dropping = false
    }

    function rotate(steps: int): void {
        if (!root.over)
            root.turn += steps
    }

    function drop(): void {
        if (!root.over)
            root.dropping = true
    }

    // Every slab touching two or more of its colour, flood-filled from each
    // unvisited one. Lit slabs act as walls so nothing is counted twice.
    function matches(): var {
        const seen = {}
        let found = []
        for (let side = 0; side < root.sides; side++) {
            for (let level = 0; level < root.stacks[side].length; level++) {
                const start = root.key(side, level)
                if (seen[start] || root.flash.indexOf(start) !== -1)
                    continue
                const colour = root.stacks[side][level]
                const group = []
                const queue = [{ side: side, level: level }]
                seen[start] = true
                while (queue.length > 0) {
                    const cell = queue.shift()
                    group.push(root.key(cell.side, cell.level))
                    const near = [
                        { side: cell.side, level: cell.level - 1 },
                        { side: cell.side, level: cell.level + 1 },
                        { side: (cell.side + 1) % root.sides, level: cell.level },
                        { side: (cell.side + root.sides - 1) % root.sides, level: cell.level }
                    ]
                    for (const next of near) {
                        if (next.level < 0 || next.level >= root.stacks[next.side].length)
                            continue
                        const id = root.key(next.side, next.level)
                        if (seen[id] || root.flash.indexOf(id) !== -1)
                            continue
                        if (root.stacks[next.side][next.level] !== colour)
                            continue
                        seen[id] = true
                        queue.push(next)
                    }
                }
                if (group.length >= 3)
                    found = found.concat(group)
            }
        }
        return found
    }

    // Lights and scores matches. Runs after each landing and each settle, so
    // the multiplier grows through a chain and resets when nothing matches.
    function resolve(): void {
        const lit = root.matches()
        if (lit.length === 0) {
            root.chain = 1
            return
        }
        root.score += lit.length * 10 * root.chain
        root.chain += 1
        root.flash = root.flash.concat(lit)
        root.flashLeft = root.flashFrames
    }

    // Lit slabs go and everything outside them slides in.
    function settle(): void {
        root.stacks = root.stacks.map((stack, side) =>
            stack.filter((colour, level) => root.flash.indexOf(root.key(side, level)) === -1))
        root.flash = []
        root.resolve()
    }

    function land(): void {
        const side = root.sideUnder(root.falling.lane)
        const next = root.stacks.map(stack => stack.slice())
        next[side].push(root.falling.colour)
        root.stacks = next
        if (next[side].length > root.rings) {
            root.spin = root.turn
            root.over = true
            root.finished(root.score)
            return
        }
        root.resolve()
        root.spawn()
    }

    function tick(): void {
        // Eases most of the way each frame, then snaps.
        const left = root.turn - root.spin
        root.spin = Math.abs(left) < 0.01 ? root.turn : root.spin + left * 0.35

        if (root.flashLeft > 0) {
            root.flashLeft -= 1
            if (root.flashLeft === 0)
                root.settle()
        }

        const step = root.dropping ? root.dropPace : root.pace
        const floor = root.stacks[root.sideUnder(root.falling.lane)].length
        if (root.falling.at - step <= floor)
            root.land()
        else
            root.falling = { lane: root.falling.lane, colour: root.falling.colour,
                             at: root.falling.at - step }
        board.requestPaint()
    }

    Timer {
        interval: 33
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.tick()
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:  case Qt.Key_A: root.rotate(-1); break
        case Qt.Key_Right: case Qt.Key_D: root.rotate(1);  break
        case Qt.Key_Down:  case Qt.Key_S: case Qt.Key_Space: root.drop(); break
        default: return
        }
        event.accepted = true
    }

    // ── DRAWING ─────────────────────────────────────────────────────────────

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.size
        height: root.size
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        // Pointer controls: outer thirds rotate, the middle drops.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: mouse => {
                const third = ground.width / 3
                if (mouse.x < third)
                    root.rotate(-1)
                else if (mouse.x > 2 * third)
                    root.rotate(1)
                else
                    root.drop()
            }
        }

        Canvas {
            id: board

            anchors.fill: parent

            // A slab is the part of one side between two concentric hexagons.
            function slab(ctx: var, angle: real, inner: real, outer: real): void {
                const cx = width / 2
                const cy = height / 2
                const far = angle + Math.PI / 3
                ctx.beginPath()
                ctx.moveTo(cx + inner * Math.cos(angle), cy + inner * Math.sin(angle))
                ctx.lineTo(cx + inner * Math.cos(far), cy + inner * Math.sin(far))
                ctx.lineTo(cx + outer * Math.cos(far), cy + outer * Math.sin(far))
                ctx.lineTo(cx + outer * Math.cos(angle), cy + outer * Math.sin(angle))
                ctx.closePath()
            }

            function hexagon(ctx: var, angle: real, radius: real): void {
                const cx = width / 2
                const cy = height / 2
                ctx.beginPath()
                for (let corner = 0; corner < root.sides; corner++) {
                    const at = angle + corner * Math.PI / 3
                    const x = cx + radius * Math.cos(at)
                    const y = cy + radius * Math.sin(at)
                    if (corner === 0)
                        ctx.moveTo(x, y)
                    else
                        ctx.lineTo(x, y)
                }
                ctx.closePath()
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                // Side 0 is the top side before any turns; its first corner is
                // at eight o'clock and lanes go clockwise from there.
                const base = -2 * Math.PI / 3
                const step = Math.PI / 3
                const spun = base + root.spin * step

                const tone = (colour, at) =>
                    `rgba(${Math.round(colour.r * 255)},${Math.round(colour.g * 255)},`
                    + `${Math.round(colour.b * 255)},${at})`

                // One slab, lit along its outer edge so the stack reads as
                // stacked rather than as a fan of flat colour.
                const laySlab = (angle, inner, outer, colour, lit) => {
                    const cx = width / 2
                    const cy = height / 2
                    const mid = angle + Math.PI / 6
                    const face = ctx.createLinearGradient(
                        cx + inner * Math.cos(mid), cy + inner * Math.sin(mid),
                        cx + outer * Math.cos(mid), cy + outer * Math.sin(mid))
                    face.addColorStop(0, tone(Qt.darker(colour, 1.35), 1))
                    face.addColorStop(0.65, tone(colour, 1))
                    face.addColorStop(1, tone(Qt.lighter(colour, 1.25), 1))
                    ctx.fillStyle = lit ? tone(Theme.indicator, 1) : face
                    board.slab(ctx, angle, inner, outer)
                    ctx.fill()
                    ctx.strokeStyle = tone(Theme.island, 0.55)
                    ctx.stroke()
                }

                // The stack limit: the line a stack must not cross, so it is
                // drawn in the colour that says so rather than as a hairline.
                ctx.lineWidth = 2
                ctx.strokeStyle = tone(Theme.red, 0.3)
                board.hexagon(ctx, spun, root.core + root.rings * root.ring)
                ctx.stroke()

                const core = ctx.createLinearGradient(0, height / 2 - root.core,
                                                      0, height / 2 + root.core)
                core.addColorStop(0, tone(Theme.islandSurfaceHover, 1))
                core.addColorStop(1, tone(Theme.island, 1))
                ctx.lineWidth = 2
                ctx.fillStyle = core
                ctx.strokeStyle = tone(root.tint, 0.5)
                board.hexagon(ctx, spun, root.core)
                ctx.fill()
                ctx.stroke()

                ctx.lineWidth = 1
                ctx.strokeStyle = Theme.hairline
                board.hexagon(ctx, spun, root.core * 0.55)
                ctx.stroke()

                // The stacks, rotated with the hexagon.
                ctx.lineWidth = 2
                for (let side = 0; side < root.sides; side++) {
                    const angle = spun + side * step
                    const stack = root.stacks[side] ?? []
                    for (let level = 0; level < stack.length; level++) {
                        const lit = root.flash.indexOf(root.key(side, level)) !== -1
                        laySlab(angle, root.core + level * root.ring,
                                root.core + (level + 1) * root.ring,
                                root.colours[stack[level]], lit)
                    }
                }

                // The falling slab, in a lane that doesn't rotate, with its
                // own light around it. After game over it is already part of
                // the stack.
                if (!root.over) {
                    const inner = root.core + root.falling.at * root.ring
                    const lane = base + root.falling.lane * step
                    const colour = root.colours[root.falling.colour]
                    ctx.strokeStyle = tone(colour, 0.35)
                    ctx.lineWidth = 5
                    board.slab(ctx, lane, inner, inner + root.ring)
                    ctx.stroke()
                    ctx.lineWidth = 2
                    laySlab(lane, inner, inner + root.ring, colour, false)
                }
            }
        }
    }
}
