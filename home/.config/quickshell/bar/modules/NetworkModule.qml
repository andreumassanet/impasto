// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N E T W O R K   M O D U L E                                            │
// │   network · link status, radio switch when open                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The chip is the link's glyph and the network name. The detail shows the link
// type, internet reachability and the Wi-Fi switch; choosing a network is done
// in the control centre panel.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: NetworkService.refresh()

    // Shared with the desktop widget.
    readonly property string stateLine: NetworkService.stateLine

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
                        text: NetworkService.icon
                        font.family: Theme.fontMono
                        font.pixelSize: 18
                        color: NetworkService.online ? Theme.indicator : Theme.textMuted
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: NetworkService.connectionName
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.stateLine
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
                    label: "WI-FI"
                    value: NetworkService.wifiEnabled ? "On" : "Off"
                    note: NetworkService.wifiConnected ? "connected" : ""
                }

                Figure {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "LINK"
                    value: {
                        if (NetworkService.wiredConnected)
                            return "Wired"
                        return NetworkService.wifiConnected ? "Wireless" : "None"
                    }
                    note: NetworkService.online ? "internet reached" : ""
                }

                PillButton {
                    Layout.alignment: Qt.AlignVCenter
                    text: "Wi-Fi"
                    active: NetworkService.wifiEnabled
                    implicitHeight: 28
                    onClicked: NetworkService.toggleWifi()
                }
            }
        }
    }
}
