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

// Pending update count; the detail lists the first few pending, when it was
// checked, and opens the packages panel. No upgrade button: pacman needs a
// terminal and a password, which the panel's Update provides.
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

        ModuleCard {
            title: {
                if (UpdatesService.count === 0)
                    return Tr.t("Up to date")
                return UpdatesService.count === 1
                    ? Tr.t("1 update") : Tr.t("%1 updates").arg(UpdatesService.count)
            }
            // Flag results from the fallback, which reads the last synced
            // database; checkupdates is current and needs no label.
            subtitle: {
                const parts = []
                if (UpdatesService.tool === "pacman")
                    parts.push(Tr.t("as of the last sync"))
                if (UpdatesService.age !== "")
                    parts.push(Tr.t("checked %1").arg(UpdatesService.age))
                return parts.join(" · ")
            }

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: 0
                trackColor: Theme.indicatorDim

                Text {
                    anchors.centerIn: parent
                    text: "󰏖"
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: UpdatesService.count > 0 ? Theme.indicator : Theme.textMuted
                }
            }

            // The first three, with the version each goes to.
            Repeater {
                model: UpdatesService.updates.slice(0, 3)

                CardFact {
                    required property var modelData

                    name: modelData.name
                    value: modelData.source === "aur" ? `${modelData.to} · AUR` : modelData.to
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: UpdatesService.count > 3 ? Tr.t("and %1 more").arg(UpdatesService.count - 3) : ""
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                PillButton {
                    implicitHeight: Theme.cardRow
                    text: UpdatesService.checking ? Tr.t("Checking…") : Tr.t("Check")
                    enabled: !UpdatesService.checking
                    onClicked: UpdatesService.refresh()
                }

                // Modules can't reach the island, so this requests the panel,
                // opened on the updates list.
                PillButton {
                    implicitHeight: Theme.cardRow
                    text: Tr.t("Open")
                    active: UpdatesService.count > 0
                    onClicked: {
                        PackagesService.view = "updates"
                        ModuleService.requestPanel("packages")
                    }
                }
            }
        }
    }
}
