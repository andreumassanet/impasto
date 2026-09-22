// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T A S K S   M O D U L E                                                │
// │   tasks · open count and the next few                                    │
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

// The next three tasks by due date with their ticks, plus New and Open. A row
// opens the board on that task; editing happens in the panel.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    readonly property int pending: TasksService.pending
    readonly property int late: TasksService.overdue.length

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    function openOn(key: string): void {
        TasksService.open(key)
        ModuleService.requestPanel("board")
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "󰄲"
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: root.late > 0 ? Theme.red : Theme.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Tasks"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.pending === 0
                            ? (TasksService.count === 0 ? "Nothing on the board" : "All done")
                            : `${root.pending} to do · ${TasksService.summary}`
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.late > 0 ? Theme.red : Theme.textMuted
                    }
                }

                PillButton {
                    text: "New"
                    icon: "󰐕"
                    onClicked: {
                        TasksService.create()
                        ModuleService.requestPanel("board")
                    }
                }

                PillButton {
                    text: "Open"
                    icon: "󰄲"
                    onClicked: root.openOn("")
                }
            }

            // Soonest first. The tick completes a task in place; the rest of
            // the row opens it.
            Repeater {
                model: ScriptModel {
                    values: TasksService.queue.slice(0, 3)
                    objectProp: "key"
                }

                TaskRow {
                    required property var modelData

                    Layout.fillWidth: true
                    task: modelData
                    onOpened: root.openOn(modelData.key)
                }
            }
        }
    }
}
