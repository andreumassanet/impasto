// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G   A   M   E   S       F   A   C   E                                  │
// │   the arcade on a sticker, with play beside it                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"

// A pad on an eight-lobed sticker; wide, the last game and its best on the
// tag, and a round Play under it that opens the arcade.
Spread {
    id: face

    readonly property var last: GamesService.entry(GamesService.lastPlayed)

    hue: face.ink.red
    reading: face.last ? face.last.name : "Arcade"
    note: face.last ? `${Tr.t("best")} ${GamesService.bestOf(face.last.id)}` : Tr.t("nothing played yet")
    filled: true

    Tone { id: tone; hue: face.ink.red }

    Cut {
        id: plate

        anchors.fill: parent
        shape: "cookie"
        lobes: 8
        depth: 0.06
        seed: face.seed
        fill: tone.fill

        Text {
            anchors.centerIn: parent
            text: "󰊴"
            font.family: Theme.fontMono
            font.pixelSize: Math.round(plate.side * 0.44)
            color: tone.deep
        }
    }

    extra: [
        Dot {
            width: Math.min(parent.height, 68)
            height: width
            seed: face.seed + "play"
            hue: face.ink.green
            glyph: "󰐊"
            onClicked: ModuleService.requestPanel("games")
        }
    ]
}
