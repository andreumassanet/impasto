// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P O P                                                                  │
// │   what a hit was worth · a figure that rises off it and fades            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// The points a hit just paid, rising off the place it was paid. Replayed like
// `Burst`, and placed by whoever owns it.
Text {
    id: root

    property color tint: Theme.accent
    property int span: 640
    property real rise: 26

    // 1 when there is nothing to show.
    property real phase: 1

    function play(figure: string): void {
        root.text = figure
        lift.restart()
    }

    visible: root.phase < 1
    opacity: Math.min(1, (1 - root.phase) * 2.4)
    font.family: Theme.fontMono
    font.pixelSize: Theme.fontSizeSmall
    font.weight: Font.DemiBold
    color: root.tint
    scale: 1 + 0.35 * Math.max(0, 1 - root.phase * 5)

    transform: Translate {
        y: -root.rise * root.phase
    }

    NumberAnimation {
        id: lift

        target: root
        property: "phase"
        from: 0
        to: 1
        duration: root.span
        easing.type: Easing.OutCubic
    }
}
