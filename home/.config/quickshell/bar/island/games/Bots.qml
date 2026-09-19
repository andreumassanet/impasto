// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B O T S                                                                │
// │   five lanes · a click or the lane's digit, and the low ones pay double  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Bot Bash: robots march down five lanes, faster as the score climbs. A click
// in a lane, or its digit, bashes the lowest robot in it: one point, two if it
// had reached the bottom third. Three robots reaching the floor end the round.
//
// A bash on an empty lane also costs a life, so mashing the digits doesn't
// work. Further misses are ignored for a third of a second after one, so a
// double tap counts once.
//
// One Canvas repainted at 30 fps; the robots are a plain array rebuilt each
// tick, since QML doesn't notice in-place mutation.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    // Where a robot was bashed, so the lane can throw a burst at it.
    signal bashed(int lane, real at, int worth)

    function restart(): void {
        root.robots = []
        root.lives = 3
        root.score = 0
        root.ticks = 0
        root.missLane = -1
        root.missLeft = 0
        root.over = false
        board.requestPaint()
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    readonly property int lanes: 5
    readonly property int cell: Math.max(1, Math.floor(root.width / root.lanes))
    readonly property int drop: Math.max(1, Math.floor(root.height))
    readonly property int rate: 30

    // A robot's body size. Every `y` is a fraction of the drop: 0 at the top,
    // 1 at the floor.
    readonly property int body: Math.max(4, Math.round(root.cell * 0.5))
    readonly property real half: root.body / 2 / root.drop

    // Fractions of the drop per second, rising with the score and capped so a
    // crossing still takes nearly two seconds.
    readonly property real speed: Math.min(0.55, 0.16 + root.score * 0.006)

    // One object per robot: lane, body centre, and squash progress (0 while
    // standing).
    property var robots: []
    property int lives: 3
    property int ticks: 0

    // The lane last missed and the ticks left on its flash, which is also the
    // window in which further misses are ignored.
    property int missLane: -1
    property int missLeft: 0
    readonly property int stun: Math.round(root.rate * 0.3)

    focus: true

    Component.onCompleted: root.restart()

    // Only into a lane whose last robot has cleared the top; none if every lane
    // is taken.
    function spawn(): void {
        const clear = []
        for (let lane = 0; lane < root.lanes; lane++)
            if (!root.robots.some(robot => robot.lane === lane && robot.y < root.half * 3))
                clear.push(lane)
        if (clear.length === 0)
            return
        const lane = clear[Math.floor(Math.random() * clear.length)]
        root.robots = root.robots.concat([{ lane: lane, y: -root.half, squash: 0 }])
    }

    function miss(lane: int): void {
        if (root.over || root.missLeft > 0)
            return
        root.missLane = lane
        root.missLeft = root.stun
        root.lives -= 1
        if (root.lives === 0) {
            root.over = true
            root.finished(root.score)
        }
        board.requestPaint()
    }

    function bash(index: int): void {
        if (index < 0)
            return
        const struck = root.robots[index]
        const worth = struck.y > 2 / 3 ? 2 : 1
        root.score += worth
        root.robots = root.robots.map((robot, at) =>
            at === index ? { lane: robot.lane, y: robot.y, squash: 0.001 } : robot)
        root.bashed(struck.lane, struck.y, worth)
        board.requestPaint()
    }

    // Bashes the lowest standing robot in the lane.
    function bashLane(lane: int): void {
        let lowest = -1
        root.robots.forEach((robot, index) => {
            if (robot.lane === lane && robot.squash === 0
                    && (lowest < 0 || robot.y > root.robots[lowest].y))
                lowest = index
        })
        if (lowest < 0)
            root.miss(lane)
        else
            root.bash(lowest)
    }

    function bashAt(x: real): void {
        root.bashLane(Math.max(0, Math.min(root.lanes - 1, Math.floor(x / root.cell))))
    }

    function step(): void {
        const dt = 1 / root.rate
        const kept = []
        let lost = 0
        for (const robot of root.robots) {
            if (robot.squash > 0) {
                const squash = robot.squash + dt / 0.16
                if (squash < 1)
                    kept.push({ lane: robot.lane, y: robot.y, squash: squash })
                continue
            }
            const y = robot.y + root.speed * dt
            if (y + root.half >= 1)
                lost += 1
            else
                kept.push({ lane: robot.lane, y: y, squash: 0 })
        }
        root.robots = kept
        root.ticks += 1
        if (root.missLeft > 0)
            root.missLeft -= 1
        if (lost > 0) {
            root.lives = Math.max(0, root.lives - lost)
            if (root.lives === 0) {
                root.over = true
                root.finished(root.score)
            }
        }
        board.requestPaint()
    }

    Timer {
        interval: Math.round(1000 / root.rate)
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.step()
    }

    // Spawn interval shrinks in steps of five points: a Timer restarts when its
    // interval changes, so a smooth curve would keep delaying the next robot.
    Timer {
        interval: Math.max(380, 1100 - Math.floor(root.score / 5) * 50)
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.spawn()
    }

    Keys.onPressed: event => {
        if (event.key < Qt.Key_1 || event.key > Qt.Key_5)
            return
        root.bashLane(event.key - Qt.Key_1)
        event.accepted = true
    }

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.cell * root.lanes
        height: root.drop
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
                const cell = root.cell
                const body = root.body
                const corner = Math.max(2, Math.round(body * 0.22))
                const floor = Math.round(cell * 0.26)

                // Canvas parses a colour string; a Qt colour with alpha on it
                // does not survive `addColorStop`.
                const paintOf = (colour, alpha) =>
                    `rgba(${Math.round(colour.r * 255)},${Math.round(colour.g * 255)},`
                    + `${Math.round(colour.b * 255)},${alpha})`

                // Lanes: every other one lifted off the ground, a floor
                // they are marching at, and the digit that bashes each.
                for (let lane = 0; lane < root.lanes; lane++) {
                    if (lane % 2 === 1) {
                        ctx.fillStyle = paintOf(Theme.indicator, 0.02)
                        ctx.fillRect(lane * cell, 0, cell, height)
                    }
                    if (lane > 0) {
                        ctx.strokeStyle = Theme.hairline
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(lane * cell + 0.5, 0)
                        ctx.lineTo(lane * cell + 0.5, height - floor)
                        ctx.stroke()
                    }
                }

                ctx.fillStyle = paintOf(Theme.indicator, 0.05)
                ctx.fillRect(0, height - floor, width, floor)
                ctx.fillStyle = paintOf(Theme.red, root.lives < 3 ? 0.5 : 0.25)
                ctx.fillRect(0, height - floor, width, Math.max(1, cell * 0.012))

                ctx.fillStyle = paintOf(Theme.textMuted, 0.65)
                ctx.font = Theme.fontSizeSmall + "px '" + Theme.fontMono + "'"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                for (let lane = 0; lane < root.lanes; lane++)
                    ctx.fillText(String(lane + 1), lane * cell + cell / 2,
                                 height - floor / 2)

                // A miss flashes its lane red.
                if (root.missLeft > 0 && root.missLane >= 0) {
                    ctx.fillStyle = Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b,
                                            0.28 * root.missLeft / root.stun)
                    ctx.fillRect(root.missLane * cell, 0, cell, height)
                }

                // Lives, top right, dimming from the right.
                const dot = Math.max(2, Math.round(cell * 0.04))
                const inset = Theme.radiusMedium
                for (let life = 0; life < 3; life++) {
                    const gone = life >= root.lives
                    ctx.fillStyle = Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, gone ? 0.22 : 1)
                    ctx.beginPath()
                    ctx.arc(width - inset - dot - (2 - life) * dot * 3, inset + dot, dot, 0, Math.PI * 2)
                    ctx.fill()
                }

                // Robots: tracks, a lit body, a visor with two eyes and an
                // antenna, walking with a slight sway. A bashed one flattens
                // and fades.
                const lit = Qt.lighter(root.tint, 1.35)
                const shade = Qt.darker(root.tint, 1.5)
                for (const robot of root.robots) {
                    const alive = 1 - robot.squash
                    const cx = robot.lane * cell + cell / 2
                        + Math.sin(root.ticks / 4 + robot.lane * 1.3) * body * 0.05 * alive
                    const feet = (robot.y + root.half) * root.drop
                    const w = body * (1 + robot.squash * 0.6)
                    const h = body * (1 - robot.squash * 0.85)
                    const top = feet - h
                    const step = Math.sin(root.ticks / 3 + robot.lane) * body * 0.06 * alive

                    // Tracks, one lifted as it walks.
                    ctx.fillStyle = paintOf(shade, alive)
                    for (const side of [-1, 1]) {
                        ctx.beginPath()
                        ctx.roundedRect(cx + side * w * 0.3 - w * 0.19,
                                        feet - h * 0.1 + (side > 0 ? step : -step),
                                        w * 0.38, h * 0.2, h * 0.1, h * 0.1)
                        ctx.fill()
                    }

                    // Arms.
                    for (const side of [-1, 1]) {
                        ctx.beginPath()
                        ctx.roundedRect(cx + side * w * 0.49 - w * 0.07, top + h * 0.3,
                                        w * 0.14, h * 0.42, w * 0.07, w * 0.07)
                        ctx.fill()
                    }

                    if (robot.squash === 0) {
                        ctx.strokeStyle = paintOf(shade, 1)
                        ctx.lineWidth = Math.max(1, Math.round(body * 0.06))
                        ctx.beginPath()
                        ctx.moveTo(cx, top)
                        ctx.lineTo(cx, top - body * 0.2)
                        ctx.stroke()
                        ctx.fillStyle = paintOf(lit, 1)
                        ctx.beginPath()
                        ctx.arc(cx, top - body * 0.24, body * 0.08, 0, Math.PI * 2)
                        ctx.fill()
                    }

                    // The body, lit from above.
                    const skin = ctx.createLinearGradient(0, top, 0, feet)
                    skin.addColorStop(0, paintOf(lit, alive))
                    skin.addColorStop(0.55, paintOf(root.tint, alive))
                    skin.addColorStop(1, paintOf(shade, alive))
                    ctx.fillStyle = skin
                    ctx.beginPath()
                    ctx.roundedRect(cx - w / 2, top, w, h, corner, corner)
                    ctx.fill()

                    // The visor, with an eye at each end of it.
                    ctx.fillStyle = paintOf(Theme.island, alive * 0.9)
                    ctx.beginPath()
                    ctx.roundedRect(cx - w * 0.34, top + h * 0.22, w * 0.68, h * 0.34,
                                    h * 0.17, h * 0.17)
                    ctx.fill()
                    ctx.fillStyle = paintOf(lit, alive)
                    for (const side of [-1, 1]) {
                        ctx.beginPath()
                        ctx.arc(cx + side * w * 0.17, top + h * 0.39, body * 0.075,
                                0, Math.PI * 2)
                        ctx.fill()
                    }

                    // The light on the top edge.
                    ctx.fillStyle = paintOf(Theme.indicator, alive * 0.22)
                    ctx.beginPath()
                    ctx.roundedRect(cx - w * 0.28, top + h * 0.08, w * 0.4, h * 0.08,
                                    h * 0.04, h * 0.04)
                    ctx.fill()
                }
            }
        }

        // One burst and one figure per lane, thrown where the robot was.
        Repeater {
            model: root.lanes

            Item {
                id: lane

                required property int index

                anchors.fill: parent

                Connections {
                    target: root

                    function onBashed(at: int, y: real, worth: int): void {
                        if (at !== lane.index)
                            return
                        hit.y = (y + root.half) * root.drop - root.body / 2 - hit.height / 2
                        paid.y = hit.y - root.body * 0.4
                        hit.play()
                        paid.play(`+${worth}`)
                    }
                }

                Burst {
                    id: hit

                    x: lane.index * root.cell + root.cell / 2 - width / 2
                    tint: root.tint
                    spread: root.body * 0.7
                }

                Pop {
                    id: paid

                    x: lane.index * root.cell + root.cell / 2 - width / 2
                    tint: root.tint
                    rise: root.body * 0.6
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: mouse => root.bashAt(mouse.x)
        }
    }
}
