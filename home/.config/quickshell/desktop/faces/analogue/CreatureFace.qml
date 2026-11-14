// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   R   E   A   T   U   R   E       F   A   C   E                      │
// │   the pet, larger, on a line of ground · its level as a bar              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// The pet, larger, standing on a line with its name under it. 4×2 adds its mood
// and a bar of progress to the next level.
Instrument {
    id: face

    readonly property string name: PetService.name !== "" ? PetService.name : Tr.t("Pet")

    line: PetService.hatched ? `${face.name} · ${Tr.t("Lv %1").arg(PetService.level)}` : Tr.t("An egg")
    reading: face.name
    note: PetService.moodLine
    filled: true

    Item {
        anchors.fill: parent

        PetFace {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -8
            size: Math.min(parent.width, parent.height) * 0.5
            lively: true
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.14
            width: parent.width * 0.7
            height: 2
            radius: 1
            color: face.ink.dim
        }
    }

    extra: [
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 4

            UsageBar {
                width: parent.width
                progress: PetService.progress
                fillColor: face.ink.accent
                trackColor: face.ink.raised
            }

            Text {
                text: PetService.hatched ? Tr.t("Lv %1").arg(PetService.level) : Tr.t("not hatched yet")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: face.ink.muted
            }
        }
    ]
}
