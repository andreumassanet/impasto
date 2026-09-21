// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   U P D A T E S   M O D U L E                                            │
// │   updates · pending count, installed in a terminal                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// Pending update count; the detail lists what is pending, when it was checked,
// and opens the packages panel. No upgrade button: pacman needs a terminal and
// a password, which the panel's Update provides.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: UpdatesService.subscribe()
    Component.onDestruction: UpdatesService.release()

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
            spacing: 10

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
                        text: "󰏖"
                        font.family: Theme.fontMono
                        font.pixelSize: 18
                        color: UpdatesService.count > 0
                            ? Theme.indicator : Theme.textMuted
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (UpdatesService.count === 0)
                                return "Up to date"
                            return UpdatesService.count === 1
                                ? "1 update" : `${UpdatesService.count} updates`
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        // Flag results from the fallback, which reads the last
                        // synced database; checkupdates is current and needs no
                        // label.
                        text: {
                            const parts = []
                            if (UpdatesService.tool === "pacman")
                                parts.push("as of the last sync")
                            if (UpdatesService.age !== "")
                                parts.push(`checked ${UpdatesService.age}`)
                            return parts.join(" · ")
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }

                PillButton {
                    Layout.alignment: Qt.AlignVCenter
                    text: UpdatesService.checking ? "Checking…" : "Check"
                    enabled: !UpdatesService.checking
                    implicitHeight: 28
                    onClicked: UpdatesService.refresh()
                }

                // Modules can't reach the island, so this requests the panel,
                // opened on the updates list.
                PillButton {
                    Layout.alignment: Qt.AlignVCenter
                    text: "Open"
                    active: UpdatesService.count > 0
                    implicitHeight: 28
                    onClicked: {
                        PackagesService.view = "updates"
                        ModuleService.requestPanel("packages")
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: UpdatesService.count > 0
                text: UpdatesService.packages.join("  ")
                elide: Text.ElideRight
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }
        }
    }
}
