// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   F A M I L Y                                                    │
// │   pet family · one row per pet and the next egg                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"
import "../services"

// The pet collection: one row per creature in the order found, plus one for
// the next egg. Each row has the face, an editable name, the level and a
// button to put it on the bar. Shared by the pet panel and module settings.
ColumnLayout {
    id: root

    spacing: 10

    Repeater {
        model: ScriptModel {
            values: PetService.family
        }

        Rectangle {
            id: member

            required property int index
            required property var modelData

            readonly property bool out: member.index === PetService.activeIndex
            readonly property bool egg: member.modelData.hatchedAt <= 0

            Layout.fillWidth: true
            implicitHeight: 52
            radius: Theme.radiusMedium
            color: Theme.islandSurface
            border.color: member.out ? Theme.accent : Theme.islandBorder
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                PetFace {
                    Layout.alignment: Qt.AlignVCenter
                    size: 28
                    record: member.modelData
                    mood: PetService.moodAt(member.index)
                }

                // An egg has no name field yet.
                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    visible: member.egg
                    text: Tr.t("Unhatched — care for it and see")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    visible: !member.egg
                    implicitHeight: 28
                    radius: Theme.radiusSmall
                    color: Theme.island
                    border.color: named.activeFocus ? Theme.accent : Theme.islandBorder
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                    TextInput {
                        id: named

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        text: member.modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                        selectByMouse: true
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        clip: true

                        onTextEdited: PetService.renameAt(member.index, named.text)
                        Keys.onEscapePressed: {
                            named.text = ""
                            PetService.renameAt(member.index, "")
                        }

                        // Empty means the species name, shown as the
                        // placeholder.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: named.text === ""
                            text: PetService.speciesOf(member.modelData).label
                            font: named.font
                            color: Theme.textMuted
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: `Lv ${member.modelData.level}`
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                PillButton {
                    Layout.alignment: Qt.AlignVCenter
                    text: member.out ? Tr.t("Out") : Tr.t("Bring out")
                    active: member.out
                    enabled: !member.out
                    onClicked: PetService.bringOut(member.index)
                }
            }
        }
    }

    // The next egg's slot: how many remain and what earns the next one.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.radiusMedium
        color: "transparent"
        border.color: Theme.hairline
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 28
                implicitHeight: 28
                radius: width / 2
                color: "transparent"
                border.color: Theme.hairline
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    visible: PetService.complete
                    text: "★"
                    font.pixelSize: 13
                    color: Theme.indicatorWarn
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    text: PetService.complete
                        ? Tr.t("All five found")
                        : Tr.t("The next egg")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: PetService.complete
                        ? Tr.t("Nothing left to find — there is a star waiting at level fifteen for each of them.")
                        : `${Tr.t("Levels across the family")}: ${PetService.totalLevel}/${PetService.nextEggAt}`
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }

            UsageBar {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 90
                visible: !PetService.complete
                progress: PetService.eggProgress
                fillColor: Theme.accent
            }
        }
    }
}
