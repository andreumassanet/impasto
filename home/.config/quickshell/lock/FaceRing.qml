// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F A C E   R I N G                                                      │
// │   the lock's face unlock · the scan around the picture, and the tick     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

import "../theme"
import "../services"

// A ring of ticks around the account picture while the camera looks: a bright
// head circles it with a tail behind. A match lets the tail run all the way
// round in green and draws a tick over the picture; a miss turns it red and
// lets it go. Centred on the picture, and larger than it.
Item {
    id: root

    // The picture it goes around.
    property real diameter: 88

    // For the surface to take it away with everything else.
    property real fade: 1

    readonly property real inner: root.diameter / 2 + 9
    readonly property real tick: 8
    readonly property int count: 60

    // The share of a turn the tail covers behind the head.
    readonly property real tail: 0.42

    readonly property bool scanning: LockService.faceScanning
    readonly property bool matched: LockService.faceMatched
    property bool missed: false

    // Where the head is, in turns clockwise from the top.
    property real head: 0

    // How much of the ring behind the head is lit whole, 0 to 1.
    property real fill: 0

    // The tick over the picture, drawn from 0 to 1.
    property real mark: 0

    property real shown: root.scanning || root.matched || root.missed ? 1 : 0

    property color hue: root.matched ? Theme.indicatorGood
        : root.missed ? Theme.indicatorBad
        : Theme.text

    width: 2 * (root.inner + root.tick)
    height: width
    visible: root.shown > 0
    opacity: root.shown * root.fade
    scale: 0.9 + 0.1 * root.shown

    Behavior on shown {
        NumberAnimation { duration: Theme.durationMedium; easing.type: Easing.OutCubic }
    }
    Behavior on hue { ColorAnimation { duration: Theme.durationFast } }

    // One turn a second, which reads as looking rather than as waiting.
    NumberAnimation on head {
        from: 0
        to: 1
        duration: 1000
        loops: Animation.Infinite
        running: root.scanning && !root.matched
    }

    // The tail runs round to close the ring, and the tick is drawn as it
    // does.
    ParallelAnimation {
        id: close

        NumberAnimation {
            target: root
            property: "fill"
            from: 0
            to: 1
            duration: Theme.durationMorph
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: Theme.durationMedium }
            NumberAnimation {
                target: root
                property: "mark"
                from: 0
                to: 1
                duration: Theme.durationMorph
                easing.type: Easing.OutCubic
            }
        }
    }

    onMatchedChanged: {
        if (root.matched) {
            close.restart()
        } else {
            close.stop()
            root.fill = 0
            root.mark = 0
        }
    }

    // Red for as long as the picture shakes, then gone.
    Timer {
        id: missHold

        interval: Theme.durationMorph
        onTriggered: root.missed = false
    }

    Connections {
        target: LockService
        function onFaceMissed(): void {
            root.missed = true
            missHold.restart()
        }
    }

    // Shadowed like the type around it, so the ticks hold on a light desktop.
    layer.enabled: root.visible
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.9
        shadowOpacity: 0.65
        shadowVerticalOffset: 2
        shadowColor: Theme.island
    }

    // ── TICKS ───────────────────────────────────────────────────────────────

    Repeater {
        model: root.count

        Item {
            id: spoke

            required property int index

            // Turns behind the head, 0 at the head itself.
            readonly property real behind: (root.head - spoke.index / root.count + 1) % 1
            readonly property real glow: Math.max(
                0.18,
                1 - spoke.behind / root.tail,
                spoke.behind <= root.fill ? 1 : 0)

            anchors.fill: parent
            rotation: spoke.index * 360 / root.count

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.tick * (1 - root.shown)
                width: 2.5
                height: root.tick * root.shown
                radius: width / 2
                color: root.hue
                opacity: spoke.glow
            }
        }
    }

    // ── TICK ────────────────────────────────────────────────────────────────

    // The picture darkened just enough for a white tick to read over a face.
    Rectangle {
        anchors.centerIn: parent
        width: root.diameter
        height: root.diameter
        radius: width / 2
        color: Theme.island
        opacity: 0.5 * root.mark
    }

    Shape {
        id: check

        // A short stroke down to the corner, then a long one up, drawn in
        // that order.
        readonly property point a: Qt.point(0.30 * root.diameter, 0.52 * root.diameter)
        readonly property point b: Qt.point(0.44 * root.diameter, 0.66 * root.diameter)
        readonly property point c: Qt.point(0.71 * root.diameter, 0.38 * root.diameter)
        readonly property real first: Math.hypot(check.b.x - check.a.x, check.b.y - check.a.y)
        readonly property real second: Math.hypot(check.c.x - check.b.x, check.c.y - check.b.y)
        readonly property real drawn: root.mark * (check.first + check.second)
        readonly property real down: Math.min(1, check.drawn / check.first)
        readonly property real up: Math.max(0, (check.drawn - check.first) / check.second)
        readonly property point bend: Qt.point(
            check.a.x + (check.b.x - check.a.x) * check.down,
            check.a.y + (check.b.y - check.a.y) * check.down)
        // Until the first stroke reaches the corner the second has no length.
        readonly property point end: check.up > 0
            ? Qt.point(check.b.x + (check.c.x - check.b.x) * check.up,
                       check.b.y + (check.c.y - check.b.y) * check.up)
            : check.bend

        anchors.centerIn: parent
        width: root.diameter
        height: root.diameter
        visible: root.mark > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 4.5
            strokeColor: Theme.text
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: check.a.x
            startY: check.a.y

            PathLine { x: check.bend.x; y: check.bend.y }
            PathLine { x: check.end.x; y: check.end.y }
        }
    }
}
