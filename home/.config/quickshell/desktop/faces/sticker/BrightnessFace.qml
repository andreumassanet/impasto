// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B   R   I   G   H   T   N   E   S   S       F   A   C   E              │
// │   the backlight on a sun · sticker                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"

// A ten-rayed sun with the backlight on a ring round the glyph.
Spread {
    id: face

    hue: face.ink.yellow
    reading: BrightnessService.available ? `${BrightnessService.percent}%` : Tr.t("No backlight")
    note: BrightnessService.available ? Tr.t("backlight") : Tr.t("nothing to dim")

    Tone { id: tone; hue: face.ink.yellow }

    Cut {
        id: plate

        anchors.fill: parent
        shape: "cookie"
        lobes: 10
        depth: 0.1
        seed: face.seed
        fill: tone.fill

        Ring {
            anchors.centerIn: parent
            width: plate.side * 0.56
            height: width
            thickness: plate.side * 0.075
            fraction: BrightnessService.available ? BrightnessService.percent / 100 : 0
            color: tone.deep
            track: tone.track
        }

        Text {
            anchors.centerIn: parent
            text: BrightnessService.available ? "󰃠" : "󰃞"
            font.family: Theme.fontMono
            font.pixelSize: Math.round(plate.side * 0.2)
            color: tone.deep
        }
    }
}
