// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   V   O   L   U   M   E       F   A   C   E                              │
// │   the output level on a four-lobed sticker                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"

// A four-lobed sticker with the level on an open ring round the speaker.
Spread {
    id: face

    readonly property color tint: AudioService.muted ? face.ink.muted : face.ink.blue

    hue: face.tint
    reading: AudioService.muted ? Tr.t("Muted") : `${AudioService.volume}%`
    note: AudioService.muted ? `${AudioService.volume}% · ${Tr.t("muted")}` : Tr.t("output")

    Tone { id: tone; hue: face.tint }

    Cut {
        id: plate

        anchors.fill: parent
        shape: "cookie"
        lobes: 4
        depth: 0.06
        turn: Math.PI / 4
        seed: face.seed
        fill: tone.fill

        Ring {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: plate.side * 0.04
            width: plate.side * 0.64
            height: width
            thickness: plate.side * 0.085
            start: 150
            sweep: 240
            fraction: AudioService.muted ? 0 : AudioService.volume / 100
            color: tone.deep
            track: tone.track
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: plate.side * 0.05
            text: AudioService.muted ? "󰝟" : "󰕾"
            font.family: Theme.fontMono
            font.pixelSize: Math.round(plate.side * 0.2)
            color: tone.deep
        }
    }
}
