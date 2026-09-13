// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L A Y O U T   P I C K E R                                              │
// │   every keyboard layout X knows, and the order they are loaded in        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// Hyprland passes the comma-separated list to xkb, which loads the layouts as
// groups in order: the first is the starting layout and the switch key cycles
// through the rest. Shows only the chosen layouts until Edit is pressed.
Rectangle {
    id: root

    // The stored value: a comma-separated list, possibly empty.
    property string current: ""

    property bool expanded: false

    signal changed(string value)

    readonly property var chosen: root.current
        .split(",")
        .map(entry => entry.trim())
        .filter(entry => entry !== "")

    property string filter: ""

    readonly property var matches: {
        const term = root.filter.trim().toLowerCase()
        if (term === "")
            return CompositorService.layouts
        return CompositorService.layouts.filter(
            entry => entry.label.toLowerCase().includes(term)
                || entry.id.toLowerCase().includes(term))
    }

    function toggle(id: string): void {
        const next = root.chosen.slice()
        const at = next.indexOf(id)
        if (at >= 0) {
            // Keep at least one layout loaded.
            if (next.length === 1)
                return
            next.splice(at, 1)
        } else {
            next.push(id)
        }
        root.changed(next.join(","))
    }

    // Sits in a `SettingGroup`'s card, padded like its rows.
    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 28
    color: "transparent"

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: Tr.t("Layouts, in order")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                visible: root.chosen.length > 1
                text: Tr.t("· the first is the one you start on")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            Item { Layout.fillWidth: true }

            PillButton {
                text: root.expanded ? Tr.t("Done") : Tr.t("Edit")
                icon: root.expanded ? "󰄬" : "󰐕"
                implicitWidth: 76
                implicitHeight: 26
                active: root.expanded
                onClicked: {
                    root.expanded = !root.expanded
                    if (root.expanded)
                        search.forceActiveFocus()
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.chosen

                Rectangle {
                    id: chip

                    required property string modelData
                    required property int index

                    width: chipRow.implicitWidth + 20
                    height: 26
                    radius: height / 2
                    color: chipMouse.containsMouse ? Theme.islandSurfaceHover : Theme.island
                    border.color: chip.index === 0 ? Theme.accent : Theme.islandBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: 7

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: CompositorService.labelForLayout(chip.modelData)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: chip.index === 0 ? Theme.accent : Theme.text
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰅖"
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: Theme.textMuted
                        }
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggle(chip.modelData)
                    }
                }
            }
        }

        Rectangle {
            visible: root.expanded
            Layout.fillWidth: true
            Layout.preferredHeight: 30
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

                    onTextEdited: root.filter = text
                    Keys.onEscapePressed: { search.text = ""; root.filter = "" }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: Tr.t("Search {} layouts")
                            .replace("{}", CompositorService.layouts.length)
                        font: search.font
                        color: Theme.textMuted
                    }
                }
            }
        }

        ListView {
            visible: root.expanded
            Layout.fillWidth: true
            Layout.preferredHeight: root.expanded ? 220 : 0
            clip: true
            spacing: 1
            model: root.matches
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property bool taken: root.chosen.indexOf(row.modelData.id) >= 0

                width: ListView.view.width
                height: 28
                radius: Theme.radiusSmall - 2
                color: rowMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    spacing: 10

                    Text {
                        text: row.taken ? "󰄬" : "󰝦"
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: row.taken ? Theme.accent : Theme.islandBorder
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.label
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: row.taken ? Font.DemiBold : Font.Normal
                        color: row.taken ? Theme.accent : Theme.text
                    }

                    Text {
                        text: row.modelData.id
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggle(row.modelData.id)
                }
            }
        }
    }
}
