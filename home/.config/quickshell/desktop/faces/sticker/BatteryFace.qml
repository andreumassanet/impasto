// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B   A   T   T   E   R   Y       F   A   C   E                          │
// │   the charge as a pill that fills · sticker                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"

// An upright pill that fills from the foot with the charge, a bolt on it
// while charging. Low, it takes the battery's fixed warning hue.
Spread {
    id: face

    readonly property color tint: BatteryService.low ? BatteryService.tint : face.ink.green

    hue: face.tint
    reading: BatteryService.available ? `${BatteryService.percent}%` : Tr.t("No battery")
    note: BatteryService.available ? `${BatteryService.stateWord} · ${BatteryService.estimate}` : Tr.t("nothing to read")

    Tone { id: tone; hue: face.tint }

    Cut {
        id: cell

        anchors.centerIn: parent
        width: parent.width * 0.52
        height: parent.height
        shape: "pill"
        seed: face.seed
        fill: tone.fill

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: cell.edge + cell.width * 0.1
            height: Math.max(width, (cell.height - 2 * anchors.margins) * BatteryService.percent / 100)
            visible: BatteryService.available
            radius: width / 2
            color: tone.hue
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: cell.height * 0.1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: BatteryService.charging || !BatteryService.available
                text: BatteryService.available ? "󱐋" : "󰂑"
                font.family: Theme.fontMono
                font.pixelSize: Math.round(cell.width * 0.3)
                color: tone.deep
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: BatteryService.available
                text: BatteryService.percent
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(cell.width * 0.36)
                font.weight: Font.Bold
                color: tone.deep
            }
        }
    }
}
