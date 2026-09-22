// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T E S   M O D U L E                                                │
// │   notes · recent notes when open                                         │
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

// The latest notes, one line each, and a button that opens the deck; a row
// opens its note. Editing needs the keyboard, so it happens in the panel.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    readonly property int count: NotesService.count

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    function openOn(key: string): void {
        NotesService.open(key)
        ModuleService.requestPanel("notes")
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
                    text: "󰎞"
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: Theme.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Notes"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: root.count === 0
                            ? "Nothing written down yet"
                            : `${root.count} ${root.count === 1 ? "note" : "notes"}`
                                + (NotesService.archived.length > 0
                                    ? ` · ${NotesService.archived.length} archived` : "")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }

                PillButton {
                    text: "New"
                    icon: "󰐕"
                    onClicked: {
                        NotesService.create()
                        ModuleService.requestPanel("notes")
                    }
                }

                PillButton {
                    text: "Open"
                    icon: "󰏫"
                    onClicked: root.openOn("")
                }
            }

            // The last three, most recently edited first.
            Repeater {
                model: ScriptModel {
                    values: NotesService.live.slice(0, 3)
                    objectProp: "key"
                }

                Rectangle {
                    id: row

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: Theme.radiusSmall
                    color: rowMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 8
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: NotesService.tintColor(row.modelData.tint)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: NotesService.titleOf(row.modelData)
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: NotesService.isEmpty(row.modelData) ? Theme.textMuted : Theme.text
                        }

                        Text {
                            text: NotesService.ageOf(row.modelData.edited)
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
                        onClicked: root.openOn(row.modelData.key)
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
