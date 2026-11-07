// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S   T   A   T   S       F   A   C   E                                  │
// │   processor, memory and heat as three badges · sticker                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"

// Three badges, each a ring on a lobed sticker: the processor, the memory,
// and the temperature (the load where there is no sensor). Clustered on a
// square, side by side and staggered on a 4×2.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)
    property string seed: ""

    readonly property bool square: root.family === "2x2"
    readonly property real side: Math.min(root.width, root.height)
    readonly property var celsius: StatsService.temperature ? StatsService.temperature.celsius : null

    readonly property var badges: [
        { word: "CPU", figure: `${StatsService.cpu.toFixed(0)}`, fraction: StatsService.cpu / 100,
          hue: root.ink.accent },
        { word: "RAM", figure: `${Math.round(StatsService.memoryFraction * 100)}`,
          fraction: StatsService.memoryFraction, hue: root.ink.blue },
        root.celsius !== null
            ? { word: "TEMP", figure: `${Math.round(root.celsius)}°`, fraction: root.celsius / 100,
                hue: root.ink.yellow }
            : { word: Tr.t("LOAD"), figure: StatsService.load[0].toFixed(1), fraction: Math.min(1, StatsService.load[0] / 8),
                hue: root.ink.yellow }
    ]

    // Where each goes, as shares of the face: centre x, centre y, size.
    readonly property var spots: root.square
        ? [[0.36, 0.36, 0.68], [0.68, 0.7, 0.58], [0.8, 0.22, 0.46]]
        : [[0.16, 0.5, 0.74], [0.49, 0.5, 0.86], [0.83, 0.5, 0.72]]

    Repeater {
        model: 3

        Cut {
            id: badge

            required property int index

            readonly property var entry: root.badges[badge.index]
            readonly property var spot: root.spots[badge.index]

            Tone { id: tone; hue: badge.entry.hue }

            width: root.side * badge.spot[2] * (root.square ? 1 : 1.05)
            height: width
            x: root.width * badge.spot[0] - width / 2
            y: root.height * badge.spot[1] - height / 2
                + (root.square ? 0 : (badge.index - 1) * root.side * 0.04 * (badge.index % 2 ? -1 : 1))
            shape: "cookie"
            lobes: 8 + badge.index * 2
            depth: 0.05
            seed: root.seed + badge.entry.word
            fill: tone.fill

            Ring {
                anchors.centerIn: parent
                width: badge.side * 0.66
                height: width
                thickness: badge.side * 0.075
                fraction: badge.entry.fraction
                color: tone.deep
                track: tone.track
            }

            Column {
                anchors.centerIn: parent

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: badge.entry.figure
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(badge.side * 0.2)
                    font.weight: Font.Bold
                    color: tone.deep
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: badge.entry.word
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(Theme.fontSizeLabel - 2, Math.round(badge.side * 0.08))
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    color: tone.deep
                }
            }
        }
    }
}
