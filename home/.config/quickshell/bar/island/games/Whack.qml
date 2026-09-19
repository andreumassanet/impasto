// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W H A C K                                                              │
// │   nine holes · a digit or a click, and the mole drops                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "../../../theme"

// Whack-a-Mole: nine holes numbered like a phone keypad (1 top left, 9 bottom
// right). Up to two moles at a time pop up, wait and duck; a click or the
// hole's digit drops one for a point. Moles stay up for less as the score
// climbs. Rounds last 45 seconds, shown by the bar at the top.
//
// A miss (an empty hole's digit or a click on one) costs two seconds, so
// mashing the digits doesn't pay. Further misses are ignored for a third of a
// second after one.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        root.up = Array(root.holes).fill(false)
        root.until = Array(root.holes).fill(0)
        root.elapsed = 0
        root.spawnGap = 600
        root.score = 0
        root.missHole = -1
        root.missLeft = 0
        root.over = false
    }

    // ── FIELD ───────────────────────────────────────────────────────────────

    readonly property int columns: 3
    readonly property int rows: 3
    readonly property int holes: root.columns * root.rows
    readonly property int cell: Math.max(1, Math.floor(
        Math.min(root.width / root.columns, root.height / root.rows)))

    // Counted in ticks rather than wall time, so hiding the island pauses the
    // round.
    readonly property int roundLength: 45000
    readonly property int tick: 50
    property int elapsed: 0

    // How long a mole stays up (shrinking with the score), how long a hole
    // rests afterwards, and how many can be up at once.
    readonly property int stay: Math.max(450, 1100 - root.score * 20)
    readonly property int rest: 300
    readonly property int maxUp: 2
    property int spawnGap: 600

    // Per hole: whether the mole is up and the tick it drops at, or while down,
    // the tick the hole becomes available again.
    property var up: []
    property var until: []

    // The hole last missed and the ticks left on its flash, which is also the
    // window in which further misses are ignored.
    property int missHole: -1
    property int missLeft: 0
    readonly property int stun: 300
    readonly property int penalty: 2000

    focus: true

    Component.onCompleted: root.restart()

    function put(hole: int, raised: bool, when: int): void {
        const up = root.up.slice()
        const until = root.until.slice()
        up[hole] = raised
        until[hole] = when
        root.up = up
        root.until = until
    }

    function spawn(): void {
        if (root.up.filter(raised => raised).length < root.maxUp) {
            const free = []
            for (let hole = 0; hole < root.holes; hole++)
                if (!root.up[hole] && root.until[hole] <= root.elapsed)
                    free.push(hole)
            if (free.length > 0)
                root.put(free[Math.floor(Math.random() * free.length)], true,
                         root.elapsed + root.stay)
        }
        // Randomised gap before the next mole.
        root.spawnGap = Math.round(root.stay * (0.4 + Math.random() * 0.5))
    }

    // Takes two seconds off the clock without shortening the moles: every
    // hole's timing shifts with it.
    function miss(hole: int): void {
        if (root.over || root.missLeft > 0)
            return
        root.missHole = hole
        root.missLeft = root.stun
        root.elapsed = Math.min(root.roundLength, root.elapsed + root.penalty)
        root.until = root.until.map(when => when + root.penalty)
    }

    signal struck(int hole)

    function whack(hole: int): void {
        if (root.over)
            return
        if (!root.up[hole]) {
            root.miss(hole)
            return
        }
        root.score += 1
        root.put(hole, false, root.elapsed + root.rest)
        root.struck(hole)
    }

    function step(): void {
        root.elapsed += root.tick
        if (root.missLeft > 0)
            root.missLeft = Math.max(0, root.missLeft - root.tick)
        const dropped = root.up.map((raised, hole) => raised && root.until[hole] <= root.elapsed)
        if (dropped.some(fell => fell)) {
            root.up = root.up.map((raised, hole) => raised && !dropped[hole])
            root.until = root.until.map((when, hole) => dropped[hole] ? root.elapsed + root.rest : when)
        }
        if (root.elapsed >= root.roundLength) {
            root.up = Array(root.holes).fill(false)
            root.over = true
            root.finished(root.score)
        }
    }

    Timer {
        interval: root.spawnGap
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.spawn()
    }

    Timer {
        interval: root.tick
        repeat: true
        running: !root.over && root.visible
        onTriggered: root.step()
    }

    Keys.onPressed: event => {
        if (event.key < Qt.Key_1 || event.key > Qt.Key_9)
            return
        root.whack(event.key - Qt.Key_1)
        event.accepted = true
    }

    // ── GROUND ──────────────────────────────────────────────────────────────

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.cell * root.columns
        height: root.cell * root.rows
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        // Time left, draining from the right.
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.radiusMedium
            }
            height: Math.max(2, Math.round(root.cell * 0.03))
            radius: height / 2
            color: Theme.islandBorder

            // Animated, so a miss's two seconds visibly drain rather than jump.
            Rectangle {
                width: parent.width * Math.max(0, 1 - root.elapsed / root.roundLength)
                height: parent.height
                radius: height / 2
                color: root.tint

                Behavior on width {
                    NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                }
            }
        }

        Repeater {
            model: root.holes

            Item {
                id: hole

                required property int index

                readonly property bool raised: root.up[hole.index] === true
                // Red while a miss on it is flashing.
                readonly property bool missed:
                    hole.index === root.missHole && root.missLeft > 0
                readonly property color earth: hole.missed
                    ? Theme.red : Theme.islandSurfaceHover

                x: (hole.index % root.columns) * root.cell
                y: Math.floor(hole.index / root.columns) * root.cell
                width: root.cell
                height: root.cell

                Connections {
                    target: root

                    function onStruck(at: int): void {
                        if (at !== hole.index)
                            return
                        hit.play()
                        paid.play("+1")
                    }
                }

                // The earth heaped behind the pit.
                Rectangle {
                    x: root.cell * 0.10
                    y: root.cell * 0.58
                    width: root.cell * 0.80
                    height: root.cell * 0.30
                    radius: height / 2
                    color: hole.earth

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                // The pit, dark and the same shape.
                Rectangle {
                    x: root.cell * 0.16
                    y: root.cell * 0.61
                    width: root.cell * 0.68
                    height: root.cell * 0.22
                    radius: height / 2
                    color: Theme.island
                }

                // The creature, clipped at the lip so it climbs out of the
                // pit rather than appearing over it.
                Item {
                    id: well

                    width: root.cell
                    height: root.cell * 0.72
                    clip: true

                    Item {
                        id: mole

                        readonly property color dark: Qt.darker(root.tint, 1.7)
                        readonly property color mid: Qt.darker(root.tint, 1.25)
                        readonly property color light: Qt.lighter(root.tint, 1.3)

                        x: (root.cell - width) / 2
                        y: hole.raised ? root.cell * 0.19 : root.cell * 0.74
                        width: root.cell * 0.46
                        height: root.cell * 0.56

                        // Out of the pit on a spring, back into it flat: the
                        // overshoot is what makes it look alive, and a mole
                        // dropping with one would bounce off the ground.
                        Behavior on y {
                            NumberAnimation {
                                duration: hole.raised ? 190 : 110
                                easing.type: hole.raised ? Easing.OutBack : Easing.InQuad
                            }
                        }

                        // Ears, behind the head.
                        Repeater {
                            model: [-1, 1]

                            Rectangle {
                                required property int modelData

                                x: mole.width * 0.5 + modelData * mole.width * 0.34 - width / 2
                                y: mole.height * 0.02
                                width: mole.width * 0.30
                                height: width
                                radius: width / 2
                                color: mole.mid
                            }
                        }

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeWidth: 0
                                fillGradient: LinearGradient {
                                    x1: 0; y1: 0
                                    x2: 0; y2: mole.height

                                    GradientStop { position: 0.0; color: mole.light }
                                    GradientStop { position: 0.5; color: root.tint }
                                    GradientStop { position: 1.0; color: mole.mid }
                                }

                                startX: mole.width * 0.5
                                startY: 0

                                PathCubic {
                                    control1X: mole.width * 0.96; control1Y: 0
                                    control2X: mole.width;        control2Y: mole.height * 0.5
                                    x: mole.width;                y: mole.height
                                }
                                PathLine { x: 0; y: mole.height }
                                PathCubic {
                                    control1X: 0;                 control1Y: mole.height * 0.5
                                    control2X: mole.width * 0.04; control2Y: 0
                                    x: mole.width * 0.5;          y: 0
                                }
                            }
                        }

                        // Snout and nose.
                        Rectangle {
                            x: mole.width * 0.26
                            y: mole.height * 0.46
                            width: mole.width * 0.48
                            height: mole.height * 0.34
                            radius: width / 2
                            opacity: 0.55
                            color: mole.light
                        }

                        Rectangle {
                            x: mole.width * 0.5 - width / 2
                            y: mole.height * 0.56
                            width: mole.width * 0.16
                            height: width * 0.8
                            radius: width / 2
                            color: mole.dark
                        }

                        Repeater {
                            model: [-1, 1]

                            Item {
                                required property int modelData

                                x: mole.width * 0.5 + modelData * mole.width * 0.19 - width / 2
                                y: mole.height * 0.24
                                width: mole.width * 0.18
                                height: mole.width * 0.22

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: Theme.island
                                }

                                Rectangle {
                                    x: parent.width * 0.16
                                    y: parent.height * 0.14
                                    width: parent.width * 0.4
                                    height: width
                                    radius: width / 2
                                    color: Theme.indicator
                                }
                            }
                        }

                        // Paws over the lip.
                        Repeater {
                            model: [-1, 1]

                            Rectangle {
                                required property int modelData

                                x: mole.width * 0.5 + modelData * mole.width * 0.42 - width / 2
                                y: mole.height * 0.82
                                width: mole.width * 0.26
                                height: mole.height * 0.16
                                radius: height / 2
                                color: mole.mid
                            }
                        }
                    }
                }

                // The lip of the pit, in front of the creature.
                Rectangle {
                    x: root.cell * 0.10
                    y: root.cell * 0.70
                    width: root.cell * 0.80
                    height: root.cell * 0.20
                    radius: height / 2
                    color: hole.earth

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: parent.height * 0.3
                        radius: height / 2
                        opacity: 0.4
                        color: Theme.islandBorder
                    }
                }

                Burst {
                    id: hit

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.cell * 0.42 - height / 2
                    tint: root.tint
                    spread: root.cell * 0.26
                }

                Pop {
                    id: paid

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.cell * 0.28
                    tint: root.tint
                    rise: root.cell * 0.2
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: hole.raised ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: root.whack(hole.index)
                }
            }
        }
    }
}
