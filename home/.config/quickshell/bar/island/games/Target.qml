// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T A R G E T                                                            │
// │   one target at a time · it shrinks, and the bullseye is worth three     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Target Smash: one target at a time, shrinking to nothing, faster as the
// score climbs. A hit scores three for the bullseye, two for the middle ring,
// one for the outer, judged by distance from the centre at the moment of the
// click. Clicks on empty ground do nothing.
//
// A target that shrinks away unclicked costs one of three lives. Mouse only.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        burst.stop()
        root.score = 0
        root.lives = 3
        root.over = false
        root.place()
    }

    // ── GROUND ──────────────────────────────────────────────────────────────

    // Full target size, and its centre's margin from the edge: the burst grows
    // it by half again and the ground doesn't clip.
    readonly property int size: 96
    readonly property int margin: Math.ceil(root.size * 0.75)

    // Target lifetime: 1.6 s at the start, falling to 700 ms by thirty points.
    readonly property int lifetime: Math.max(700, 1600 - root.score * 30)

    // Part of the game's pace, so it ignores the shell's motion scale.
    readonly property int burstDuration: 220

    property int lives: 3
    property int targetX: 0
    property int targetY: 0
    property bool smashed: false

    focus: true

    Component.onCompleted: root.restart()

    function place(): void {
        const spanX = Math.max(0, ground.width - 2 * root.margin)
        const spanY = Math.max(0, ground.height - 2 * root.margin)
        root.targetX = root.margin + Math.round(Math.random() * spanX)
        root.targetY = root.margin + Math.round(Math.random() * spanY)
        root.smashed = false
        rings.scale = 1
        rings.opacity = 1
        shrink.restart()
    }

    function smash(x: real, y: real): void {
        if (root.over || root.smashed)
            return
        // The rings are thirds of the current on-screen radius.
        const radius = target.scale * root.size / 2
        const distance = Math.hypot(x - root.targetX, y - root.targetY)
        if (distance > radius)
            return
        const worth = distance <= radius / 3 ? 3 : distance <= radius * 2 / 3 ? 2 : 1
        root.score += worth
        root.smashed = true
        shrink.stop()
        burst.restart()
        hit.play()
        paid.play(`+${worth}`)
    }

    function miss(): void {
        if (root.over)
            return
        root.lives -= 1
        if (root.lives === 0) {
            root.over = true
            root.finished(root.score)
            return
        }
        root.place()
    }

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: Math.floor(root.width)
        height: Math.floor(root.height)
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        // The range: a field of dots, painted once, so the board is a place
        // rather than an empty rectangle.
        Canvas {
            id: field

            anchors.fill: parent
            onWidthChanged: field.requestPaint()
            onHeightChanged: field.requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const gap = 34
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.045)
                for (let y = gap / 2; y < height; y += gap) {
                    for (let x = gap / 2; x < width; x += gap) {
                        ctx.beginPath()
                        ctx.arc(x, y, 1.6, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.CrossCursor
            onPressed: event => root.smash(event.x, event.y)
        }

        // The target; its scale is the clock. Reaching zero is a miss; a hit
        // stops it, and the rings flash and burst before the next one.
        Item {
            id: target

            x: root.targetX - width / 2
            y: root.targetY - height / 2
            width: root.size
            height: root.size

            NumberAnimation on scale {
                id: shrink

                from: 1
                to: 0
                duration: root.lifetime
                running: !root.over && root.visible
                onFinished: root.miss()
            }

            Item {
                id: rings

                anchors.fill: parent

                // Five rings, the tint and white by turns, with the bullseye
                // in the colour a bullseye is. All of it whitens on a hit.
                Repeater {
                    model: [
                        { at: 1.0,  paint: "tint" },
                        { at: 0.78, paint: "pale" },
                        { at: 0.56, paint: "tint" },
                        { at: 0.34, paint: "pale" },
                        { at: 0.16, paint: "eye" }
                    ]

                    Rectangle {
                        required property var modelData

                        anchors.centerIn: parent
                        width: root.size * modelData.at
                        height: width
                        radius: width / 2
                        color: root.smashed ? Theme.indicator
                            : modelData.paint === "tint" ? root.tint
                            : modelData.paint === "pale" ? Theme.indicator : Theme.red
                        border.color: Qt.rgba(Theme.island.r, Theme.island.g,
                                              Theme.island.b, 0.35)
                        border.width: modelData.at === 1 ? Math.max(1, root.size * 0.02) : 0
                    }
                }

                // The light on it, so it reads as a disc rather than a print.
                Rectangle {
                    x: parent.width * 0.2
                    y: parent.height * 0.16
                    width: parent.width * 0.3
                    height: parent.height * 0.16
                    radius: height / 2
                    rotation: -28
                    opacity: root.smashed ? 0 : 0.22
                    color: Theme.indicator
                }
            }

            ParallelAnimation {
                id: burst

                NumberAnimation {
                    target: rings
                    property: "scale"
                    from: 1
                    to: 1.5
                    duration: root.burstDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: rings
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: root.burstDuration
                }
                onFinished: root.place()
            }
        }

        Burst {
            id: hit

            x: root.targetX - width / 2
            y: root.targetY - height / 2
            tint: root.tint
            spread: root.size * 0.7
            sparks: 9
        }

        Pop {
            id: paid

            x: root.targetX - width / 2
            y: root.targetY - root.size * 0.5
            tint: Theme.indicator
            rise: root.size * 0.4
        }

        // Three lives, top right; a lost one dims.
        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 6

            Repeater {
                model: 3

                Rectangle {
                    required property int index

                    width: 8
                    height: 8
                    radius: Theme.radiusPill
                    color: Theme.red
                    opacity: index < root.lives ? 1 : 0.25

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.durationFast }
                    }
                }
            }
        }
    }
}
