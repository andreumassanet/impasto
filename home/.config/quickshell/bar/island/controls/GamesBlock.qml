// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G A M E S   B L O C K                                                  │
// │   arcade block · best scores and play                                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// Arcade block. One row: the mark, the last best and Play. Two rows: the last
// three games.
Card {
    id: root

    property int rows: 1

    signal panelRequested(string panel)

    readonly property string last: GamesService.lastPlayed
    readonly property var lastEntry: GamesService.entry(root.last)

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 10
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)

                Text {
                    anchors.centerIn: parent
                    text: "󰊗"
                    font.family: Theme.fontMono
                    font.pixelSize: 17
                    color: Theme.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Games"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: root.lastEntry
                        ? `${root.lastEntry.name} · best ${GamesService.bestOf(root.last)}`
                        : "Nothing played yet"
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }

            PillButton {
                text: "Play"
                implicitHeight: 26
                onClicked: root.panelRequested("games")
            }
        }

        Repeater {
            model: ScriptModel {
                values: root.rows >= 2 ? GamesService.ranked.slice(0, 3) : []
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
                    text: `${GamesService.bestOf(row.modelData.id)}`
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }
        }

        Item {
            Layout.fillHeight: true
            visible: root.rows >= 2
        }
    }
}
