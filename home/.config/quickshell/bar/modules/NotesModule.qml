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

        ModuleCard {
            title: Tr.t("Notes")
            subtitle: root.count === 0
                ? Tr.t("Nothing written down yet")
                : Tr.t(root.count === 1 ? "%1 note" : "%1 notes").arg(root.count)
                    + (NotesService.archived.length > 0
                        ? " · " + Tr.t("%1 archived").arg(NotesService.archived.length) : "")

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: 0
                trackColor: Theme.indicatorDim

                Text {
                    anchors.centerIn: parent
                    text: "󰎞"
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: Theme.indicator
                }
            }

            // The last three, most recently edited first.
            Repeater {
                model: ScriptModel {
                    values: NotesService.live.slice(0, 3)
                    objectProp: "key"
                }

                Item {
                    id: row

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.cardRow

                    // The hover reaches past the row, so its text lines up
                    // with the card's other rows.
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: -8
                        anchors.rightMargin: -8
                        radius: Theme.radiusSmall
                        color: Theme.surfaceHoverIn(QsWindow.window)
                        opacity: rowMouse.containsMouse ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                    }

                    RowLayout {
                        anchors.fill: parent
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
                            font.pixelSize: Theme.fontSizeSmall
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

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow
                spacing: 8

                Item { Layout.fillWidth: true }

                PillButton {
                    implicitHeight: Theme.cardRow
                    text: Tr.t("New")
                    icon: "󰐕"
                    onClicked: {
                        NotesService.create()
                        ModuleService.requestPanel("notes")
                    }
                }

                PillButton {
                    implicitHeight: Theme.cardRow
                    text: Tr.t("Open")
                    icon: "󰏫"
                    onClicked: root.openOn("")
                }
            }
        }
    }
}
