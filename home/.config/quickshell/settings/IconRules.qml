// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I C O N   R U L E S                                                    │
// │   the workspace strip's own icons · a class fragment and an icon name    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"
import "../services"
import "../components"

// The rules for windows whose class no desktop entry names (a terminal
// started with `--class`, a web app), one row each, and a row to add one. A
// class matches when it contains the fragment, in any case; the icon is a
// name in the icon theme. Sits in a `SettingGroup`'s card.
ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 0

    component RuleInput: Rectangle {
        id: field

        property alias text: input.text
        property string placeholder: ""

        signal accepted()

        implicitHeight: 30
        radius: Theme.radiusSmall
        color: Theme.island
        border.color: input.activeFocus ? Theme.accent : Theme.islandBorder
        border.width: 1

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.text
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            clip: true
            onAccepted: field.accepted()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: field.placeholder
                font: input.font
                color: Theme.textMuted
            }
        }
    }

    function add(): void {
        if (classField.text.trim() === "" || iconField.text.trim() === "")
            return
        SettingsService.addIconRule(classField.text, iconField.text)
        classField.text = ""
        iconField.text = ""
    }

    Repeater {
        model: ScriptModel {
            values: Array.from(SettingsService.workspaceIconRules ?? [])
        }

        Item {
            id: rule

            required property var modelData
            required property int index
            readonly property string picture: Quickshell.iconPath(rule.modelData.icon, true)

            Layout.fillWidth: true
            implicitHeight: 48

            SettingDivider {}

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 12

                Image {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    source: rule.picture
                    sourceSize: Qt.size(48, 48)
                    fillMode: Image.PreserveAspectFit
                    visible: rule.picture !== "" && status === Image.Ready
                }

                Text {
                    Layout.fillWidth: true
                    text: `${rule.modelData.windowClass}  →  ${rule.modelData.icon}`
                    elide: Text.ElideRight
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "󰅖"
                    iconSize: 12
                    onClicked: SettingsService.removeIconRule(rule.index)
                }
            }
        }
    }

    SettingRow {
        label: Tr.t("Add an icon rule")
        reading: Tr.t("A window class containing the first, shown with the icon named in the second")

        RowLayout {
            spacing: 8

            RuleInput {
                id: classField

                Layout.preferredWidth: 150
                placeholder: Tr.t("Window class")
                onAccepted: iconField.forceActiveFocus()
            }

            RuleInput {
                id: iconField

                Layout.preferredWidth: 130
                placeholder: Tr.t("Icon name")
                onAccepted: root.add()
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "󰐕"
                iconSize: 14
                onClicked: root.add()
            }
        }
    }
}
