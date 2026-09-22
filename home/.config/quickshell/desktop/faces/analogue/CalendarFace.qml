// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   A   L   E   N   D   A   R       F   A   C   E                      │
// │   wall calendar · day, week and month views                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"
import ".."

// The calendar as paper. 2×2: one leaf, with rings, the month on a ribbon, the
// day and the weekday. 4×2: the week beside it as seven small leaves (today in
// the accent, a dot on days with tasks) and a summary line. 4×4: the month
// ruled on one sheet with today's tasks under it.
//
// Pressing a day with tasks (or the 2×2 leaf, which is today) shows that day's
// sheet. The 4×4 rewrites its own ribbon; the smaller faces lay a sheet over
// themselves. The face returns via the arrow or when the pointer leaves.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)

    readonly property date today: clock.date

    // The pressed day, while its sheet is shown.
    property string picked: ""

    // Its name on the ribbon, kept through the fade-out.
    property string ribbon: ""
    onPickedChanged: {
        if (root.picked !== "")
            root.ribbon = Qt.formatDate(TasksService.dateOf(root.picked), "dddd d").toUpperCase()
    }

    // The notes' ink, for what is written on the paper.
    readonly property var paperInk: ({
        text: Theme.paperInk, muted: Theme.paperInkMuted, accent: root.ink.accent,
        accentText: root.ink.accentText,
        raised: Qt.rgba(Theme.paperInk.r, Theme.paperInk.g, Theme.paperInk.b, 0.08),
        red: Theme.red,
        rule: Qt.rgba(Theme.paperInkMuted.r, Theme.paperInkMuted.g, Theme.paperInkMuted.b, 0.4)
    })

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    HoverHandler {
        onHoveredChanged: {
            if (!hovered)
                root.picked = ""
        }
    }

    // The summary line under the week.
    function agendaLine(): string {
        const left = TasksService.pendingOn(TasksService.todayKey)
        if (left > 0)
            return `${left} to do today`
        const next = TasksService.next
        if (next)
            return `${next.text} · ${TasksService.dueLabel(next.due)}`
        return Qt.formatDateTime(root.today, "dddd")
    }

    Loader {
        anchors.fill: parent
        opacity: root.picked !== "" && root.family !== "4x4" ? 0 : 1
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        sourceComponent: {
            if (root.family === "2x2")
                return square
            if (root.family === "4x4")
                return month
            return week
        }
    }

    Component {
        id: square

        Instrument {
            family: root.family
            ink: root.ink

            Leaf {
                anchors.centerIn: parent
                ink: root.ink
                width: Math.min(parent.width, parent.height * 0.74)
                height: parent.height
                month: Qt.formatDateTime(root.today, "MMMM").toUpperCase()
                day: `${root.today.getDate()}`
                weekday: Qt.formatDateTime(root.today, "dddd")

                HoverHandler {
                    enabled: TasksService.countOn(TasksService.todayKey) > 0
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: TasksService.countOn(TasksService.todayKey) > 0
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.picked = TasksService.todayKey
                }
            }
        }
    }

    Component {
        id: week

        Item {
            id: strip

            Leaf {
                x: 22
                y: 22
                width: 100
                height: parent.height - 44
                ink: root.ink
                month: Qt.formatDateTime(root.today, "MMMM").toUpperCase()
                day: `${root.today.getDate()}`
                weekday: Qt.formatDateTime(root.today, "dddd")
            }

            Row {
                id: days

                x: 146
                y: 40
                width: strip.width - 146 - 22
                height: 66
                spacing: 6

                Repeater {
                    model: 7

                    Item {
                        id: day

                        required property int index

                        // Monday first, the way the month is laid out.
                        readonly property date date: {
                            const base = new Date(root.today)
                            const shift = (base.getDay() + 6) % 7
                            base.setDate(base.getDate() - shift + day.index)
                            return base
                        }

                        readonly property bool today:
                            day.date.getDate() === root.today.getDate()
                            && day.date.getMonth() === root.today.getMonth()
                        readonly property string key: TasksService.dayKey(day.date)
                        readonly property int tasks: TasksService.countOn(day.key)
                        readonly property int pending: TasksService.pendingOn(day.key)

                        width: (days.width - 36) / 7
                        height: days.height

                        Leaf {
                            anchors.fill: parent
                            ink: root.ink
                            rings: false
                            band: 16
                            today: day.today
                            month: Qt.formatDateTime(day.date, "ddd").charAt(0)
                            day: `${day.date.getDate()}`
                        }

                        // A task due that day: the accent while any is open,
                        // muted once done.
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            visible: day.tasks > 0
                            width: 4
                            height: 4
                            radius: 2
                            color: day.pending > 0 ? root.ink.accent : Theme.paperInkMuted
                        }

                        HoverHandler {
                            enabled: day.tasks > 0
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            enabled: day.tasks > 0
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.picked = day.key
                        }
                    }
                }
            }

            Text {
                x: 146
                y: 122
                width: strip.width - 146 - 22
                text: root.agendaLine()
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: root.ink.muted
            }
        }
    }

    Component {
        id: month

        Leaf {
            id: sheet

            anchors.fill: parent
            anchors.margins: 22
            ink: root.ink
            band: 34
            month: root.picked !== "" ? root.ribbon
                : Qt.formatDateTime(root.today, "MMMM yyyy").toUpperCase()

            readonly property var cells: {
                const year = root.today.getFullYear()
                const index = root.today.getMonth()
                const shift = (new Date(year, index, 1).getDay() + 6) % 7
                const total = new Date(year, index + 1, 0).getDate()
                const list = []
                for (let blank = 0; blank < shift; blank++)
                    list.push(0)
                for (let date = 1; date <= total; date++)
                    list.push(date)
                while (list.length % 7 !== 0)
                    list.push(0)
                return list
            }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: sheet.band + 10
                spacing: 8
                opacity: root.picked === "" ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                Grid {
                    id: grid

                    width: parent.width
                    height: parent.height - agenda.height - 8 - 9
                    columns: 7

                    readonly property real cellWidth: width / 7
                    readonly property real cellHeight: height / (1 + sheet.cells.length / 7)

                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]

                        Item {
                            required property var modelData

                            width: grid.cellWidth
                            height: grid.cellHeight

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.weight: Font.DemiBold
                                color: Theme.paperInkMuted
                            }
                        }
                    }

                    Repeater {
                        model: sheet.cells

                        Item {
                            id: cell

                            required property int modelData

                            readonly property bool today: cell.modelData === root.today.getDate()
                            readonly property string key: cell.modelData > 0
                                ? TasksService.dayKey(new Date(root.today.getFullYear(),
                                    root.today.getMonth(), cell.modelData)) : ""
                            readonly property int tasks: cell.key !== "" ? TasksService.countOn(cell.key) : 0
                            readonly property int pending: cell.key !== "" ? TasksService.pendingOn(cell.key) : 0

                            width: grid.cellWidth
                            height: grid.cellHeight

                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 6
                                height: width
                                radius: width / 2
                                visible: cell.today
                                color: root.ink.accent
                            }

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: cell.tasks > 0 ? -1 : 0
                                visible: cell.modelData > 0
                                text: `${cell.modelData}`
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: cell.today ? Font.DemiBold : Font.Normal
                                color: cell.today ? root.ink.accentText : Theme.paperInk
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                visible: cell.tasks > 0
                                width: 3
                                height: 3
                                radius: 1.5
                                color: cell.today ? root.ink.accentText
                                    : (cell.pending > 0 ? root.ink.accent : Theme.paperInkMuted)
                            }

                            HoverHandler {
                                enabled: cell.tasks > 0
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                enabled: cell.tasks > 0
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: root.picked = cell.key
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.paperInkMuted
                    opacity: 0.4
                }

                // What is due today, ruled under the month.
                Column {
                    id: agenda

                    readonly property string day: TasksService.todayKey
                    readonly property var due: TasksService.on(agenda.day)

                    width: parent.width
                    spacing: 3

                    Text {
                        width: parent.width
                        text: {
                            const name = agenda.day === TasksService.todayKey ? "Today"
                                : Qt.formatDate(TasksService.dateOf(agenda.day), "dddd d")
                            const n = agenda.due.length
                            const left = agenda.due.filter(task => task.state !== "done").length
                            return n === 0 ? `${name} · nothing due` : `${name} · ${left} of ${n} to do`
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.weight: Font.DemiBold
                        color: Theme.paperInkMuted
                    }

                    Repeater {
                        model: ScriptModel {
                            values: agenda.due.slice(0, 2)
                            objectProp: "key"
                        }

                        TaskRow {
                            required property var modelData

                            width: parent.width
                            task: modelData
                            dated: false
                            ink: root.paperInk
                            onOpened: {
                                TasksService.open(modelData.key)
                                ModuleService.requestPanel("board")
                            }
                        }
                    }
                }
            }

            DayTasks {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: sheet.band + 10
                titled: false
                day: root.picked
                ink: root.paperInk
                opacity: root.picked !== "" ? 1 : 0
                visible: opacity > 0
                onBack: root.picked = ""

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }
        }
    }

    // ── ONE DAY ─────────────────────────────────────────────────────────────

    // The day sheet for the 2×2 and 4×2, laid over the face. The month rewrites
    // its own ribbon instead.
    Leaf {
        id: daySheet

        anchors.fill: parent
        anchors.margins: root.family === "2x2" ? 14 : 16
        ink: root.ink
        band: 26
        month: root.ribbon
        opacity: root.picked !== "" && root.family !== "4x4" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        DayTasks {
            anchors.fill: parent
            anchors.margins: 10
            anchors.topMargin: daySheet.band + 8
            titled: false
            day: root.family !== "4x4" ? root.picked : ""
            ink: root.paperInk
            onBack: root.picked = ""
        }
    }
}
