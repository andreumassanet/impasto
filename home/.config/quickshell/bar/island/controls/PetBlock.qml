// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   B L O C K                                                      │
// │   pet block · feed and play                                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../../theme"
import "../../../services"
import "../../../components"

// The pet's face, mood and the feed and play buttons; three rows tall adds the
// shelf. The face opens the pet panel.
Card {
    id: root

    property int rows: 2

    signal panelRequested(string panel)

    Component.onCompleted: PetService.subscribe()
    Component.onDestruction: PetService.release()

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                Layout.alignment: Qt.AlignVCenter

                PetFace {
                    id: face

                    anchors.centerIn: parent
                    size: 46
                    lively: true
                    scale: faceMouse.containsMouse ? 1.08 : 1

                    Behavior on scale {
                        NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                    }
                }

                MouseArea {
                    id: faceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.panelRequested("pet")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: PetService.titleOf(PetService.pet)
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        visible: PetService.hatched
                        text: Tr.t("Lv %1").arg(PetService.level)
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: PetService.moodLine
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    UsageBar {
                        Layout.fillWidth: true
                        progress: PetService.progress
                        fillColor: face.coat
                    }

                    Text {
                        text: `${PetService.xp}/${PetService.threshold}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                PillButton {
                    Layout.fillWidth: true
                    implicitWidth: 64
                    implicitHeight: 24
                    text: PetService.canFeed ? Tr.t("Feed") : Tr.t("Fed")
                    enabled: PetService.canFeed
                    onClicked: PetService.feed()
                }

                PillButton {
                    Layout.fillWidth: true
                    implicitWidth: 64
                    implicitHeight: 24
                    text: PetService.canPlay ? Tr.t("Play") : Tr.t("Played")
                    enabled: PetService.canPlay
                    onClicked: PetService.play()
                }
            }
        }

        Item {
            Layout.fillHeight: true
            visible: root.rows >= 3
        }

        PetShelf {
            Layout.fillWidth: true
            visible: root.rows >= 3
            slot: 28
            brief: true
        }
    }
}
