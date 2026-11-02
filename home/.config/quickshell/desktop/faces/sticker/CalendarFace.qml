// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   A   L   E   N   D   A   R       F   A   C   E                      │
// │   today as a sticker, the month on a sheet · sticker                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import ".."

// Today as a soft red sticker, the weekday over the date, with a round one
// on its corner counting what is due; wide, the month and the day's agenda
// on a tag beside it. At 4×4 the month on a sheet of vinyl, today on a red
// seal. A day with something due, pressed, turns the widget into that day
// (`DayTasks`, on a sheet of its own) until the pointer leaves or the arrow.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)
    property string seed: ""

    readonly property date today: clock.date
    readonly property real side: Math.min(root.width, root.height)
    readonly property int dueToday: TasksService.pendingOn(TasksService.todayKey)

    // The pressed day, while its sheet is shown.
    property string picked: ""

    // What is written on the vinyl: the notes' ink, which stays dark.
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

    Tone { id: tone; hue: root.ink.red }

    function agendaLine(): string {
        if (root.dueToday > 0)
            return Tr.t("%1 to do today").arg(root.dueToday)
        const next = TasksService.next
        if (next)
            return `${next.text} · ${TasksService.dueLabel(next.due)}`
        return Tr.t("nothing due")
    }

    component Day: Cut {
        id: day

        shape: "soft"
        seed: root.seed
        fill: tone.fill

        Column {
            anchors.centerIn: parent
            spacing: -day.side * 0.04

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.today, "dddd").toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(Theme.fontSizeLabel - 1, Math.round(day.side * 0.08))
                font.weight: Font.Bold
                font.letterSpacing: 2
                color: tone.deep
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `${root.today.getDate()}`
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(day.side * 0.5)
                font.weight: Font.Bold
                color: tone.deep
            }
        }

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

    Loader {
        anchors.fill: parent
        opacity: root.picked !== "" ? 0 : 1
        visible: opacity > 0
        sourceComponent: root.family === "4x4" ? month : room

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    }

    Component {
        id: room

        Spread {
            family: root.family
            ink: root.ink
            seed: root.seed
            hue: root.ink.red
            reading: Qt.formatDateTime(root.today, "MMMM")
            note: root.agendaLine()

            Day {
                anchors.centerIn: parent
                width: parent.width * 0.92
                height: parent.height
            }

            Dot {
                visible: root.dueToday > 0
                live: false
                x: parent.width * 0.7
                y: -parent.height * 0.02
                width: parent.width * 0.32
                height: width
                seed: root.seed + "due"
                hue: root.ink.accent
                glyph: `${root.dueToday}`
            }
        }
    }

    Component {
        id: month

        Cut {
            id: sheet

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

            anchors.fill: parent
            anchors.margins: root.side * 0.03
            shape: "soft"
            lean: Theme.stickerLean * 0.3
            seed: root.seed
            fill: root.ink.paper

            Text {
                id: title

                x: sheet.side * 0.08
                y: sheet.side * 0.06
                text: Qt.formatDateTime(root.today, "MMMM")
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(sheet.side * 0.09)
                font.weight: Font.Bold
                color: tone.deep
            }

            Grid {
                id: grid

                readonly property real cellWidth: width / 7
                readonly property real cellHeight: height / (1 + sheet.cells.length / 7)

                x: sheet.side * 0.06
                y: title.y + title.height + sheet.side * 0.02
                width: sheet.width - 2 * x
                height: sheet.height - y - sheet.side * 0.06
                columns: 7

                Repeater {
                    model: Tr.t("M T W T F S S").split(" ")

                    Item {
                        required property var modelData

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.Bold
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

                        Cut {
                            anchors.centerIn: parent
                            visible: cell.today
                            width: Math.min(parent.width, parent.height) * 1.1
                            height: width
                            shape: "cookie"
                            lobes: 10
                            depth: 0.08
                            seed: root.seed + "today"
                            fill: tone.hue
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: cell.tasks > 0 ? -1 : 0
                            visible: cell.modelData > 0
                            text: `${cell.modelData}`
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: cell.today ? Font.Bold : Font.Medium
                            color: cell.today ? root.ink.paper : Theme.paperInk
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            visible: cell.tasks > 0
                            width: 4
                            height: 4
                            radius: 2
                            color: cell.today ? root.ink.paper
                                : (cell.pending > 0 ? tone.deep : Theme.paperInkMuted)
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
        }
    }

    // ── ONE DAY ─────────────────────────────────────────────────────────────

    Cut {
        id: daySheet

        anchors.fill: parent
        anchors.margins: root.side * 0.05
        shape: "soft"
        lean: 0
        fill: root.ink.paper
        opacity: root.picked !== "" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        DayTasks {
            anchors.fill: parent
            anchors.margins: daySheet.side * 0.08
            day: root.picked
            ink: root.paperInk
            onBack: root.picked = ""
        }
    }
}
