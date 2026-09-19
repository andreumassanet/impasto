// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B U R S T                                                              │
// │   a hit, drawn · a ring that opens and sparks thrown out of it           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// What a hit looks like, for the games that land one: a ring opening out of
// the point and a handful of sparks with it, both fading as they go.
//
// One instance per place a hit can happen, replayed rather than created, so a
// round builds nothing. Idle it is invisible and costs nothing.
Item {
    id: root

    property color tint: Theme.accent
    property int sparks: 7
    property real spread: 26
    property int span: 320

    // 1 when there is nothing to show; `play` takes it from 0 back to 1.
    property real phase: 1

    function play(): void {
        flash.restart()
    }

    implicitWidth: root.spread * 2
    implicitHeight: root.spread * 2
    visible: root.phase < 1

    NumberAnimation {
        id: flash

        target: root
        property: "phase"
        from: 0
        to: 1
        duration: root.span
        easing.type: Easing.OutCubic
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.spread * 2 * root.phase
        height: width
        radius: width / 2
        color: "transparent"
        border.color: root.tint
        border.width: Math.max(1, root.spread * 0.14 * (1 - root.phase))
        opacity: 1 - root.phase
    }

    Repeater {
        model: root.sparks

        Rectangle {
            required property int index

            readonly property real angle: index * (Math.PI * 2 / root.sparks)

            x: root.width / 2 + Math.cos(angle) * root.spread * (0.3 + root.phase) - width / 2
            y: root.height / 2 + Math.sin(angle) * root.spread * (0.3 + root.phase) - height / 2
            width: root.spread * 0.18 * (1 - root.phase * 0.5)
            height: width
            radius: width / 2
            color: root.tint
            opacity: 1 - root.phase
        }
    }
}
