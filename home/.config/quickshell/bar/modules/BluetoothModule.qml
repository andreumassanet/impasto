// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L U E T O O T H   M O D U L E                                        │
// │   bluetooth · connected devices, radio switch when open                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The chip names the connected device, so audio that fell back to the
// speakers is visible at a glance. Pairing is not supported (no PIN agent);
// the device list is in the control centre.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                RingIndicator {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    thickness: 2.5
                    progress: 0
                    trackColor: Theme.indicatorDim

                    Text {
                        anchors.centerIn: parent
                        text: BluetoothService.icon
                        font.family: Theme.fontMono
                        font.pixelSize: 18
                        color: BluetoothService.enabled
                            ? Theme.indicator : Theme.textMuted
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: BluetoothService.summary
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!BluetoothService.enabled)
                                return "Adapter off"
                            const count = BluetoothService.connectedDevices.length
                            if (count === 0)
                                return "On · nothing connected"
                            return count === 1
                                ? "On · 1 device connected"
                                : `On · ${count} devices connected`
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Figure {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "DEVICES"
                    value: `${BluetoothService.connectedDevices.length}`
                    note: "pairing lives in the control centre"
                }

                PillButton {
                    Layout.alignment: Qt.AlignVCenter
                    text: "Bluetooth"
                    active: BluetoothService.enabled
                    implicitHeight: 28
                    onClicked: BluetoothService.toggle()
                }
            }
        }
    }
}
