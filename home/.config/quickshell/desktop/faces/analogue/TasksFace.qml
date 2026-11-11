// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T   A   S   K   S       F   A   C   E                                  │
// │   tasks on a clipboard · the next few                                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// The tasks on a clipboard: the next three on a 2×2, the same three beside the
// count on a 4×2, and nine lines at 4×4.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)

    readonly property string count: {
        if (TasksService.pending === 0)
            return TasksService.count === 0 ? Tr.t("Nothing yet") : Tr.t("All done")
        const late = TasksService.overdue.length
        return `${Tr.t("%1 to do").arg(TasksService.pending)}${late > 0 ? ` · ${Tr.t("%1 late").arg(late)}` : ""}`
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.family === "4x4" ? large : room
    }

    Component {
        id: room

        Instrument {
            family: root.family
            ink: root.ink
            line: root.count
            reading: `${TasksService.pending}`
            note: TasksService.pending === 0
                ? (TasksService.count === 0 ? Tr.t("nothing yet") : Tr.t("all done"))
                : TasksService.summary
            tint: TasksService.overdue.length > 0 ? Theme.red : root.ink.text
            filled: true

            Clipboard {
                anchors.fill: parent
                anchors.topMargin: 8
                ink: root.ink
                tasks: TasksService.queue.slice(0, 3)
            }

            extra: [
                PillButton {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: Tr.t("Open")
                    implicitHeight: 28
                    onClicked: ModuleService.requestPanel("board")
                }
            ]
        }
    }

    Component {
        id: large

        Item {
            Clipboard {
                anchors.fill: parent
                anchors.margins: 22
                anchors.topMargin: 30
                ink: root.ink
                title: `${Tr.t("Tasks")} · ${root.count.toLowerCase()}`
                tasks: TasksService.queue.slice(0, 9)
            }
        }
    }
}
