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

        ModuleCard {
            title: NetworkService.connectionName
            subtitle: root.stateLine

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
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

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: Tr.t("Wi-Fi")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                Text {
                    text: NetworkService.wifiConnected ? Tr.t("connected")
                        : (NetworkService.wifiEnabled ? Tr.t("on") : Tr.t("off"))
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                }

                ToggleSwitch {
                    checked: NetworkService.wifiEnabled
                    onToggled: NetworkService.toggleWifi()
                }
            }

            CardFact {
                name: Tr.t("Link")
                value: {
                    const link = NetworkService.wiredConnected ? Tr.t("Wired")
                        : NetworkService.wifiConnected ? Tr.t("Wireless") : Tr.t("None")
                    return NetworkService.online ? Tr.t("%1 · internet reached").arg(link) : link
                }
            }
        }
    }
}
