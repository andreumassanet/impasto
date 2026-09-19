// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   P I X E L                                                      │
// │   the pet as a sprite · sixteen cells across, lit from the left          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"

// A 16×16 sprite: one map per species for the body, and the face painted over
// it a cell at a time, so a mood is a handful of blocks rather than a map of
// its own.
//
// The cell is a whole number of pixels and the grid is centred, so the sprite
// never lands on half a pixel. Each row is drawn as runs of one colour rather
// than as cells, which is a dozen rectangles instead of two hundred.
Item {
    id: root

    property var kind: ({ id: "dot", ears: "round" })
    property color coat: Theme.accent
    property real size: 40
    property string mood: "content"
    property bool egg: false
    property real blink: 1

    readonly property real cell: Math.max(1, Math.round(root.size / 16))
    readonly property bool asleep: root.mood === "asleep"

    // `#` coat · `l` lit · `o` shaded · `a` the crown · `.` nothing
    readonly property var bodies: ({
        dot: [
            "................",
            "...##......##...",
            "..####....####..",
            "..############..",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".o############o.",
            "..oooooooooooo..",
            "...oo......oo...",
            "................"
        ],
        sprout: [
            "....aa....aa....",
            ".....aa..aa.....",
            "......a##a......",
            "..############..",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".o############o.",
            "..oooooooooooo..",
            "...oo......oo...",
            "................"
        ],
        ember: [
            ".......aa.......",
            "......aaaa......",
            ".....aa##aa.....",
            "..############..",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            ".o############o.",
            "..oooooooooooo..",
            "...oo......oo...",
            "................"
        ],
        sol: [
            "...a..a..a..a...",
            "................",
            "..############..",
            ".l############o.",
            ".l############o.",
            "al############oa",
            ".l############o.",
            ".l############o.",
            ".l############o.",
            "al############oa",
            ".l############o.",
            ".l############o.",
            ".o############o.",
            "..oooooooooooo..",
            "...oo......oo...",
            "...a..a..a..a..."
        ],
        drift: [
            "................",
            "..############..",
            ".l############o.",
            "ol############oo",
            "ol############oo",
            "ol############oo",
            "ol############oo",
            "ol############oo",
            "ol############oo",
            "ol############oo",
            "ol############oo",
            ".l############o.",
            ".o############o.",
            "..oooooooooooo..",
            "...oo......oo...",
            "................"
        ]
    })

    // The shell, speckled in the coat the species inside will wear.
    readonly property var shell: [
        "................",
        "......l##o......",
        ".....l####o.....",
        "....l######o....",
        "...l#a######o...",
        "..l##########o..",
        "..l#######a##o..",
        ".l############o.",
        ".l############o.",
        ".l##a#########o.",
        ".l############o.",
        "..l##########o..",
        "..l####a#####o..",
        "...l########o...",
        ".....l####o.....",
        "................"
    ]

    readonly property var map: root.egg
        ? root.shell : (root.bodies[root.kind.id] ?? root.bodies.dot)

    // Rows as runs of one colour: `{ x, y, w, c }`.
    function runsOf(map: var): var {
        const out = []
        for (let y = 0; y < map.length; y++) {
            const row = map[y]
            let x = 0
            while (x < row.length) {
                const c = row[x]
                let n = 1
                while (x + n < row.length && row[x + n] === c)
                    n += 1
                if (c !== ".")
                    out.push({ x: x, y: y, w: n, c: c })
                x += n
            }
        }
        return out
    }

    function inkOf(c: string): color {
        const ground = root.egg ? Theme.indicator : root.coat
        switch (c) {
        case "l": return Qt.lighter(ground, 1.3)
        case "o": return Qt.darker(ground, root.egg ? 1.22 : 1.5)
        case "a": return root.egg ? root.coat : Qt.lighter(ground, 1.45)
        }
        return ground
    }

    // The mouth, a cell at a time: `{ x, y, w }`.
    readonly property var mouth: ({
        beaming: [{ x: 5, y: 9, w: 6 }, { x: 6, y: 10, w: 4 }],
        content: [{ x: 5, y: 9, w: 1 }, { x: 10, y: 9, w: 1 }, { x: 6, y: 10, w: 4 }],
        peckish: [{ x: 6, y: 10, w: 4 }],
        lonely:  [{ x: 6, y: 9, w: 4 }, { x: 5, y: 10, w: 1 }, { x: 10, y: 10, w: 1 }],
        asleep:  [{ x: 7, y: 10, w: 2 }]
    })

    Item {
        anchors.centerIn: parent
        width: root.cell * 16
        height: root.cell * 16

        Repeater {
            model: root.runsOf(root.map)

            Rectangle {
                required property var modelData

                x: modelData.x * root.cell
                y: modelData.y * root.cell
                width: modelData.w * root.cell
                height: root.cell
                color: root.inkOf(modelData.c)
            }
        }

        // ── THE FACE ────────────────────────────────────────────────────────

        Repeater {
            model: (root.egg || root.asleep) ? [] : [-1, 1]

            Item {
                id: eye

                required property int modelData

                x: root.cell * (eye.modelData < 0 ? 4 : 10)
                y: root.cell * 6
                width: root.cell * 2
                height: root.cell * 3

                transform: Scale {
                    origin.y: eye.height / 2
                    yScale: root.blink
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.island
                }

                Rectangle {
                    width: root.cell
                    height: root.cell
                    color: Theme.indicator
                }
            }
        }

        Repeater {
            model: (!root.egg && root.asleep) ? [-1, 1] : []

            Rectangle {
                required property int modelData

                x: root.cell * (modelData < 0 ? 3 : 10)
                y: root.cell * 7
                width: root.cell * 3
                height: root.cell
                color: Theme.island
            }
        }

        Repeater {
            model: root.egg ? [] : (root.mouth[root.mood] ?? root.mouth.content)

            Rectangle {
                required property var modelData

                x: modelData.x * root.cell
                y: modelData.y * root.cell
                width: modelData.w * root.cell
                height: root.cell
                color: Theme.island
            }
        }
    }
}
