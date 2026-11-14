// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   R   E   A   T   U   R   E       F   A   C   E                      │
// │   the pet on a disc · sticker                                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"
import "../../../components"

// The pet on a disc, its name on a tag; wide, its mood and a bar to the next
// level.
Spread {
    id: face

    readonly property string name: PetService.name !== "" ? PetService.name : Tr.t("Pet")

    line: PetService.hatched ? `${face.name} · ${Tr.t("Lv %1").arg(PetService.level)}` : Tr.t("An egg")
    hue: face.ink.green
    reading: face.name
    note: PetService.moodLine
    filled: true

    Tone { id: tone; hue: face.ink.green }

    Cut {
        id: plate

        anchors.centerIn: parent
        width: parent.width * 0.96
        height: width
        shape: "circle"
        seed: face.seed
        fill: tone.fill

        PetFace {
            anchors.centerIn: parent
            size: plate.side * 0.56
            lively: false
        }
    }

    extra: [
        Cut {
            width: Math.min(parent.width, 180)
            height: 22
            shape: "pill"
            lean: 1.5
            seed: face.seed + "level"
            fill: tone.fill

            Rectangle {
                x: parent.edge + 3
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(height, (parent.width - 2 * x) * PetService.progress)
                height: parent.height - 2 * x
                radius: height / 2
                color: tone.hue
            }
        }
    ]
}
