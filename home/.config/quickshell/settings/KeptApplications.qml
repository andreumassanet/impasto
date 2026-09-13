// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   K E P T   A P P L I C A T I O N S                                      │
// │   pinned applications list · shared by dock and launcher                 │
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

// The kept (pinned) applications, one row each, and a row to add one, whose
// matches open under it as you type. Stored as the dock's pinned list, but
// the launcher also ranks them first, so the rows stay editable while the
// dock is off. Sits in a `SettingGroup`'s card.
ColumnLayout {
    id: root

    readonly property string term: search.text.trim().toLowerCase()

    // Every application the launcher indexes, minus those already kept.
    readonly property var offered: {
        if (root.term === "")
            return []
        const list = []
        for (const app of LauncherService.applications) {
            if (DockService.isPinned(app.id))
                continue
            if (!app.name.toLowerCase().includes(root.term)
                    && !app.keywords.includes(root.term))
                continue
            list.push(app)
        }
        return list
    }

    Layout.fillWidth: true
    spacing: 0

    SettingBlock {
        visible: DockService.pinnedCount === 0

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Tr.t("Nothing kept yet.")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }
    }

    Repeater {
        model: DockService.pinned

        Item {
            id: kept

            required property string modelData
            required property int index

            readonly property var entry: DockService.entryOf(kept.modelData)
            readonly property string picture: kept.entry && kept.entry.icon
                ? Quickshell.iconPath(kept.entry.icon, true) : ""

            Layout.fillWidth: true
            implicitHeight: 52

            SettingDivider {}

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 12

                Text {
                    Layout.preferredWidth: 14
                    text: `${kept.index + 1}`
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                Image {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    source: kept.picture
                    sourceSize: Qt.size(48, 48)
                    fillMode: Image.PreserveAspectFit
                    visible: kept.picture !== "" && status === Image.Ready
                }

                Text {
                    visible: kept.picture === ""
                    text: "󰀻"
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: Theme.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: kept.entry ? kept.entry.name
                            : kept.modelData.replace(/\.desktop$/, "")
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.text
                    }

                    // An uninstalled entry keeps its place and says so.
                    Text {
                        Layout.fillWidth: true
                        text: kept.entry ? kept.modelData
                            : Tr.t("This application is no longer installed")
                        elide: Text.ElideRight
                        font.family: kept.entry ? Theme.fontMono : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: kept.entry ? Theme.textMuted : Theme.yellow
                    }
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "󰅖"
                    iconSize: 12
                    onClicked: DockService.unpin(kept.modelData)
                }
            }
        }
    }

    // ── ADD ─────────────────────────────────────────────────────────────────

    SettingRow {
        label: Tr.t("Add an application")

        Rectangle {
            implicitWidth: 300
            implicitHeight: 30
            radius: Theme.radiusSmall
            color: Theme.island
            border.color: search.activeFocus ? Theme.accent : Theme.islandBorder
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                spacing: 8

                Text {
                    text: "󰍉"
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    color: Theme.textMuted
                }

                TextInput {
                    id: search

                    Layout.fillWidth: true
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                    selectByMouse: true
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    clip: true

                    Keys.onEscapePressed: event => {
                        if (search.text === "") {
                            event.accepted = false
                            return
                        }
                        search.text = ""
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: Tr.t("Search applications")
                        font: search.font
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        Layout.bottomMargin: root.offered.length > 0 ? 6 : 0
        Layout.preferredHeight: Math.min(root.offered.length, 6) * 34
        visible: root.offered.length > 0
        clip: true
        model: root.offered
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: option

            required property var modelData

            readonly property string picture: option.modelData.icon
                ? Quickshell.iconPath(option.modelData.icon, true) : ""

            width: ListView.view.width
            height: 34
            radius: Theme.radiusSmall
            color: optionMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 10
                spacing: 10

                Image {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    source: option.picture
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectFit
                    visible: option.picture !== "" && status === Image.Ready
                }

                Text {
                    visible: option.picture === ""
                    Layout.preferredWidth: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: "󰀻"
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    color: Theme.textMuted
                }

                Text {
                    Layout.fillWidth: true
                    text: option.modelData.name
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                }

                Text {
                    visible: optionMouse.containsMouse
                    text: "󰐕"
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    color: Theme.accent
                }
            }

            MouseArea {
                id: optionMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DockService.pin(option.modelData.id)
            }
        }
    }
}
