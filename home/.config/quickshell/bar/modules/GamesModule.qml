// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G A M E S   M O D U L E                                                │
// │   arcade · best scores when open                                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// Recent games with their bests and a button that opens the arcade. Games need
// keyboard focus, which the resting island doesn't hold, so none runs here.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    readonly property string last: GamesService.lastPlayed
    readonly property var lastEntry: GamesService.entry(root.last)

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ModuleCard {
            title: Tr.t("Games")
            subtitle: GamesService.totalPlays === 0
                ? Tr.t("Nothing played yet")
                : Tr.t(GamesService.totalPlays === 1 ? "%1 round" : "%1 rounds").arg(GamesService.totalPlays)
                    + " · " + Tr.t(GamesService.catalogue.length === 1 ? "%1 game" : "%1 games").arg(GamesService.catalogue.length)

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: 0
                trackColor: Theme.indicatorDim

                Text {
                    anchors.centerIn: parent
                    text: "󰊗"
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: Theme.indicator
                }
            }

            // The last three, most recent first, with their bests.
            Repeater {
                model: ScriptModel {
                    values: GamesService.ranked.slice(0, 3)
                }

                RowLayout {
                    id: row

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.cardRow
                    spacing: 10

                    Text {
                        Layout.preferredWidth: 16
                        horizontalAlignment: Text.AlignHCenter
                        text: row.modelData.icon
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeRegular
                        color: GamesService.tintOf(row.modelData.id)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }

                    Text {
                        text: `${GamesService.bestOf(row.modelData.id)} ${Tr.t(row.modelData.unit)}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow

                Item { Layout.fillWidth: true }

                PillButton {
                    implicitHeight: Theme.cardRow
                    text: Tr.t("Play")
                    icon: "󰐊"
                    onClicked: ModuleService.requestPanel("games")
                }
            }
        }
    }
}
