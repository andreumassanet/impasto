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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "󰊗"
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: Theme.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Games"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: GamesService.totalPlays === 0
                            ? "Nothing played yet"
                            : `${GamesService.totalPlays} ${GamesService.totalPlays === 1 ? "round" : "rounds"}`
                                + ` · ${GamesService.catalogue.length} ${GamesService.catalogue.length === 1 ? "game" : "games"}`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }

                PillButton {
                    text: "Play"
                    icon: "󰐊"
                    onClicked: ModuleService.requestPanel("games")
                }
            }

            // The last three, most recent first.
            Repeater {
                model: ScriptModel {
                    values: GamesService.ranked.slice(0, 3)
                }

                RowLayout {
                    id: row

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        Layout.preferredWidth: 18
                        horizontalAlignment: Text.AlignHCenter
                        text: row.modelData.icon
                        font.family: Theme.fontMono
                        font.pixelSize: 13
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
                        text: `${GamesService.bestOf(row.modelData.id)} ${row.modelData.unit}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
