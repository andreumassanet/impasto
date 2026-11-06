// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D E V I C E S   F A C E                                                │
// │   the batteries of connected devices, the same in every theme            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// Each connected device with a battery (`DeviceService`) as a ring around its
// glyph, with its name and level under it: two in the square, four in the
// wide. Like the lyrics, one face in every theme: it is a row of gauges, not an
// object to redraw. With none, the reason, where the rings would be.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)

    Text {
        anchors.centerIn: parent
        visible: DeviceService.devices.length === 0
        text: "No device with a battery"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: root.ink.muted
    }

    Row {
        anchors.centerIn: parent
        spacing: 16

        Repeater {
            model: DeviceService.devices.slice(0, root.family === "2x2" ? 2 : 4)

            Column {
                required property var modelData

                spacing: 6

                RingIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64
                    thickness: 5
                    progress: modelData.level
                    trackColor: root.ink.dim
                    fillColor: modelData.level < 0.2 ? Theme.indicatorBad : root.ink.text

                    Text {
                        anchors.centerIn: parent
                        text: modelData.glyph
                        font.family: Theme.fontMono
                        font.pixelSize: 22
                        color: root.ink.text
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 80
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: `${modelData.name}\n${Math.round(modelData.level * 100)} %`
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: root.ink.muted
                }
            }
        }
    }
}
