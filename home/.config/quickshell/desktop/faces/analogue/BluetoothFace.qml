// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B   L   U   E   T   O   O   T   H       F   A   C   E                  │
// │   bluetooth symbol · lit while connected                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// The Bluetooth rune, with two rings that take the accent while a device is
// connected.
Instrument {
    id: face

    readonly property int connected: BluetoothService.connectedDevices.length

    line: BluetoothService.summary
    reading: BluetoothService.summary
    note: !BluetoothService.available ? Tr.t("no adapter")
        : BluetoothService.enabled
        ? (face.connected === 1 ? Tr.t("1 connected") : face.connected > 1 ? Tr.t("%1 connected").arg(face.connected) : Tr.t("nothing connected")) : Tr.t("off")

    Item {
        id: plate

        anchors.fill: parent

        readonly property real side: Math.min(width, height)

        Repeater {
            model: [0.62, 0.9]

            Rectangle {
                required property int index
                required property real modelData

                anchors.centerIn: parent
                width: plate.side * modelData
                height: width
                radius: width / 2
                color: "transparent"
                border.color: face.connected > 0 ? face.ink.accent : face.ink.dim
                border.width: index === 0 ? 2 : 1
                opacity: index === 0 ? 1 : 0.6
            }
        }

        Text {
            anchors.centerIn: parent
            text: "󰂯"
            font.family: Theme.fontMono
            font.pixelSize: Math.round(plate.side * 0.4)
            color: BluetoothService.enabled ? face.ink.text : face.ink.muted
        }
    }
}
