// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A L E N D A R   C A R D                                              │
// │   the current month, with today marked                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// A month grid from plain date arithmetic; Qt's Calendar costs more to style
// than 42 cells cost to lay out.
//
// Clicking a day with tasks due turns the card into that day's list, with a
// way back in the corner. A row opens the task on the board.
Card {
    id: root

    signal panelRequested(string panel)

    // The day shown instead of the month, as a day key; "" for the month.
    property string picked: ""

    // Weeks start on Monday; JavaScript counts from Sunday, hence the shift
    // wherever a weekday index is used.
    readonly property var weekdays: ["M", "T", "W", "T", "F", "S", "S"]

    // Ticks at midnight; nothing here changes sooner.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property date today: clock.date

    // Months away from the current one; the header offers a way back when
    // nonzero.
    property int offsetMonths: 0

    readonly property date shown:
        new Date(root.today.getFullYear(), root.today.getMonth() + root.offsetMonths, 1)

    readonly property int year: root.shown.getFullYear()
    readonly property int month: root.shown.getMonth()

    readonly property int daysInMonth: new Date(root.year, root.month + 1, 0).getDate()
    readonly property int daysInPrevious: new Date(root.year, root.month, 0).getDate()

    // Column of the 1st, with Sunday moved to the end.
    readonly property int leadingBlanks: (new Date(root.year, root.month, 1).getDay() + 6) % 7

    // Today is only marked in its own month.
    readonly property bool showingThisMonth: root.offsetMonths === 0

    // Reset to the current month whenever the card is rebuilt.
    Component.onCompleted: root.offsetMonths = 0

    // ── DAY ─────────────────────────────────────────────────────────────────

    ColumnLayout {
        id: dayPage

        anchors.fill: parent
        visible: root.picked !== ""
        spacing: 6

        readonly property var date: TasksService.dateOf(root.picked)
        readonly property var due: TasksService.on(root.picked)

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            IconButton {
                icon: "󰁍"
                iconSize: 13
                implicitWidth: 26
                implicitHeight: 24
                onClicked: root.picked = ""
            }

            Text {
                Layout.fillWidth: true
                text: dayPage.date ? Qt.formatDate(dayPage.date, "dddd d MMMM") : ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                text: {
                    const n = dayPage.due.length
                    const left = dayPage.due.filter(task => task.state !== "done").length
                    return n === 0 ? "" : `${left} of ${n}`
                }
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.hairline
        }

        Repeater {
            model: ScriptModel {
                values: dayPage.due
                objectProp: "key"
            }

            TaskRow {
                required property var modelData

                Layout.fillWidth: true
                task: modelData
                dated: false
                onOpened: {
                    TasksService.open(modelData.key)
                    root.panelRequested("board")
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ── MONTH ───────────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        visible: root.picked === ""
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: Qt.formatDateTime(root.shown, "MMMM")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                text: root.year
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.textMuted
            }

            Item { Layout.fillWidth: true }

            // Today's weekday while showing the current month, otherwise a way
            // back to it.
            Text {
                text: Qt.formatDateTime(root.today, "dddd")
                visible: root.showingThisMonth
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.accent
            }

            PillButton {
                visible: !root.showingThisMonth
                text: "Today"
                implicitHeight: 22
                horizontalPadding: 9
                onClicked: root.offsetMonths = 0
            }

            IconButton {
                icon: "󰅁"
                iconSize: 12
                implicitWidth: 24
                implicitHeight: 22
                onClicked: root.offsetMonths -= 1
            }

            IconButton {
                icon: "󰅂"
                iconSize: 12
                implicitWidth: 24
                implicitHeight: 22
                onClicked: root.offsetMonths += 1
            }
        }

        GridLayout {
            id: grid

            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 2

            // Wheel pages the month. A WheelHandler, not a MouseArea: a
            // GridLayout would give an Item child a cell and shift every day by
            // one.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    root.offsetMonths += event.angleDelta.y < 0 ? 1 : -1
                }
            }

            Repeater {
                model: root.weekdays

                Text {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }
            }

            // Always 42 cells, so the card height doesn't change between five-
            // and six-row months.
            Repeater {
                model: 42

                Item {
                    id: cell

                    required property int index

                    readonly property int offset: cell.index - root.leadingBlanks
                    readonly property bool inMonth: cell.offset >= 0 && cell.offset < root.daysInMonth
                    readonly property int day: {
                        if (cell.offset < 0)
                            return root.daysInPrevious + cell.offset + 1
                        if (cell.offset >= root.daysInMonth)
                            return cell.offset - root.daysInMonth + 1
                        return cell.offset + 1
                    }
                    readonly property bool isToday: cell.inMonth
                        && root.showingThisMonth
                        && cell.day === root.today.getDate()

                    // Tasks due that day, for days in the month shown.
                    readonly property string key: cell.inMonth
                        ? TasksService.dayKey(new Date(root.year, root.month, cell.day)) : ""
                    readonly property int tasks: cell.key !== "" ? TasksService.countOn(cell.key) : 0
                    readonly property int pending: cell.key !== "" ? TasksService.pendingOn(cell.key) : 0

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        radius: width / 2
                        color: cell.isToday ? Theme.accent : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: cell.tasks > 0 ? -1 : 0
                            text: cell.day
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                            color: {
                                if (cell.isToday)
                                    return Theme.accentText
                                return cell.inMonth ? Theme.text : Theme.textMuted
                            }
                            // Days from the neighbouring months are dimmed.
                            opacity: cell.inMonth ? 1 : 0.35
                        }

                        // Tasks due: accent while any is open, muted once all
                        // are done.
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            visible: cell.tasks > 0
                            width: 3
                            height: 3
                            radius: 1.5
                            color: cell.isToday ? Theme.accentText
                                : (cell.pending > 0 ? Theme.accent : Theme.textMuted)
                        }

                        // Only days with tasks are clickable.
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
}
