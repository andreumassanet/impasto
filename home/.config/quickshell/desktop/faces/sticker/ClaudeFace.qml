// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   L   A   U   D   E       F   A   C   E                              │
// │   the block left as a ring round the mark · sticker                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"
import "../../../components"

// What is left of the block as a ring round the mark, on a nine-lobed
// sticker; wide, the reset and the week on the tag.
Spread {
    id: face

    readonly property string figure: !ClaudeService.available ? "—"
        : ClaudeService.sessionMeasured
        ? ClaudeService.percent(ClaudeService.sessionFraction)
        : ClaudeService.compact(ClaudeService.blockTokens)

    hue: face.ink.accent
    reading: ClaudeService.available ? Tr.t("%1 of this block").arg(face.figure) : Tr.t("No usage found")
    note: !ClaudeService.available ? Tr.t("nothing to read")
        : `${ClaudeService.resetsIn}${ClaudeService.weeklyMeasured
            ? " · " + Tr.t("%1 of the week").arg(ClaudeService.percent(ClaudeService.weeklyFraction)) : ""}`

    Tone { id: tone; hue: face.ink.accent }

    Cut {
        id: plate

        anchors.fill: parent
        shape: "cookie"
        lobes: 9
        depth: 0.06
        seed: face.seed
        fill: tone.fill

        Ring {
            anchors.centerIn: parent
            width: plate.side * 0.66
            height: width
            thickness: plate.side * 0.075
            fraction: 1 - ClaudeService.gauge
            color: ClaudeService.gauge > 0.85 ? face.ink.red : tone.deep
            track: tone.track
        }

        Column {
            anchors.centerIn: parent
            spacing: plate.side * 0.02

            ClaudeMark {
                anchors.horizontalCenter: parent.horizontalCenter
                width: plate.side * 0.14
                height: width
                color: tone.deep
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.figure
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(plate.side * 0.13)
                font.weight: Font.Bold
                color: tone.deep
            }
        }
    }
}
