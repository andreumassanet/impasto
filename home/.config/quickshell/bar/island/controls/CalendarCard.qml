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
// Days with tasks due or calendar events (khal, `AgendaService`) get a dot.
// Clicking one turns the card into that day's list, events and then tasks,
// with a way back in the corner. A task row opens the task on the board.
Card {
    id: root

    signal panelRequested(string panel)

    // The day shown instead of the month, as a day key; "" for the month.
    property string picked: ""

    // Weeks start on Monday; JavaScript counts from Sunday, hence the shift
    // wherever a weekday index is used.
    // One key, split: the letters repeat, so they cannot be keys one by one.
    readonly property var weekdays: Tr.t("M T W T F S S").split(" ")

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
    Component.onCompleted: {
        root.offsetMonths = 0
        AgendaService.show(root.shown)
        AgendaService.subscribe()
    }
    Component.onDestruction: AgendaService.release()
    onShownChanged: AgendaService.show(root.shown)

    // ── DAY ─────────────────────────────────────────────────────────────────

    ColumnLayout {
        id: dayPage

        anchors.fill: parent
        visible: root.picked !== ""
        spacing: 6

        readonly property var date: TasksService.dateOf(root.picked)
        readonly property var due: TasksService.on(root.picked)
        readonly property var events: AgendaService.on(root.picked)

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
                text: dayPage.date ? Tr.date(dayPage.date, "dddd d MMMM") : ""
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
                    const parts = []
                    if (dayPage.events.length > 0)
                        parts.push(dayPage.events.length === 1 ? Tr.t("1 event")
                            : Tr.t("%1 events").arg(dayPage.events.length))
                    if (n > 0)
                        parts.push(Tr.t("%1 of %2").arg(left).arg(n))
                    return parts.join(" · ")
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

        // All-day events, one line each, above the hours.
        Repeater {
            model: dayPage.events.filter(event => event.allDay)

            RowLayout {
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 20
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 3
                    Layout.fillHeight: true
                    radius: 1.5
                    color: Theme.accent
                }

                Text {
                    Layout.fillWidth: true
                    text: `${modelData.title}  ·  ${Tr.t("All day")}`
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                }
            }
        }

        // The whole day, scrolled: each event a block from its start to its
        // end against the hours on the left, side by side where they
        // overlap, and on today a line where the time is now. It opens on
        // now, or on the first event of another day.
        Flickable {
            id: hours

            readonly property var timed: dayPage.events.filter(event => !event.allDay)
                .map(event => {
                    const from = hours.minutesOf(event.time)
                    const to = Math.max(from + 15, event.endTime !== "" ? hours.minutesOf(event.endTime) : from + 60)
                    return Object.assign({ from: from, to: to }, event)
                })
            readonly property bool today: root.picked === TasksService.dayKey(root.today)
            readonly property int now: root.today.getHours() * 60 + root.today.getMinutes()
            readonly property int earliest: hours.timed.reduce((m, e) => Math.min(m, e.from), 24 * 60)
            readonly property int first: 0
            readonly property int last: 24 * 60
            // Room above midnight and below the end of the day for their labels.
            readonly property int pad: 7
            readonly property real perMinute: 44 / 60
            readonly property int gutter: 34
            // An hour label every hour, or every two when they would crowd.
            readonly property int every: 1

            // Each event's column, and how many columns its overlapping
            // neighbours make.
            readonly property var lanes: {
                const placed = []
                for (const event of hours.timed) {
                    const busy = placed.filter(other => other.from < event.to && event.from < other.to)
                    let lane = 0
                    while (busy.some(other => other.lane === lane))
                        lane += 1
                    placed.push(Object.assign({ lane: lane }, event))
                }
                return placed.map(event => Object.assign({
                    lanes: 1 + placed.filter(other => other.from < event.to && event.from < other.to)
                        .reduce((m, other) => Math.max(m, other.lane), 0)
                }, event))
            }

            function minutesOf(time: string): int {
                const parts = String(time).split(":")
                return parts.length < 2 ? 0 : parseInt(parts[0]) * 60 + parseInt(parts[1])
            }

            function yOf(minutes: int): real {
                return hours.pad + (minutes - hours.first) * hours.perMinute
            }

            // Where it opens: an hour before now, or before the first event.
            function settle(): void {
                const at = hours.today ? hours.now : hours.earliest
                hours.contentY = Math.max(0, Math.min(hours.contentHeight - hours.height,
                    hours.yOf(at - 60)))
            }

            visible: hours.timed.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            Layout.topMargin: 4
            clip: true
            contentWidth: hours.width
            contentHeight: hours.yOf(hours.last) + hours.pad
            boundsBehavior: Flickable.StopAtBounds
            onVisibleChanged: if (hours.visible) settler.restart()
            onTimedChanged: settler.restart()

            // A turn later, once laid out; a timer, unlike `Qt.callLater`,
            // goes with the card when the panel closes.
            Timer {
                id: settler
                interval: 0
                onTriggered: hours.settle()
            }

            Repeater {
                model: Math.floor((hours.last - hours.first) / 60) + 1

                Item {
                    required property int index

                    readonly property int minutes: hours.first + index * 60

                    width: hours.width
                    y: hours.yOf(minutes)
                    visible: (minutes / 60) % hours.every === 0

                    Text {
                        y: -height / 2
                        width: hours.gutter - 6
                        horizontalAlignment: Text.AlignRight
                        text: `${String(Math.floor(parent.minutes / 60)).padStart(2, "0")}:00`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel - 1
                        font.features: { "tnum": 1 }
                        color: Theme.textMuted
                    }

                    Rectangle {
                        x: hours.gutter
                        width: hours.width - hours.gutter
                        height: 1
                        color: Theme.hairline
                    }
                }
            }

            Repeater {
                model: hours.lanes

                Rectangle {
                    id: block

                    required property var modelData

                    readonly property bool past: hours.today && block.modelData.to <= hours.now
                    readonly property real lane: (hours.width - hours.gutter - 2) / block.modelData.lanes

                    x: hours.gutter + 2 + block.modelData.lane * block.lane
                    y: hours.yOf(block.modelData.from) + 1
                    width: block.lane - 2
                    height: Math.max(14, (block.modelData.to - block.modelData.from) * hours.perMinute - 2)
                    radius: Theme.radiusSmall - 2
                    color: Qt.alpha(Theme.accent, block.past ? 0.12 : 0.24)
                    clip: true

                    Rectangle {
                        width: 3
                        height: parent.height
                        color: block.past ? Theme.textMuted : Theme.accent
                    }

                    Column {
                        x: 7
                        y: 2
                        width: parent.width - 10
                        spacing: 0

                        Text {
                            width: parent.width
                            text: block.modelData.title
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            color: block.past ? Theme.textMuted : Theme.text
                        }

                        Text {
                            width: parent.width
                            visible: block.height > 26
                            text: block.modelData.location !== ""
                                ? `${block.modelData.time}–${block.modelData.endTime}  ·  ${block.modelData.location}`
                                : `${block.modelData.time}–${block.modelData.endTime}`
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel - 1
                            font.features: { "tnum": 1 }
                            color: Theme.textMuted
                        }
                    }
                }
            }

            // Now, on today.
            Item {
                visible: hours.today
                // On a whole pixel, or the thin line blurs into grey.
                y: Math.round(hours.yOf(hours.now))
                z: 1
                width: hours.width

                Rectangle {
                    x: hours.gutter - 3
                    y: -3
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.red
                }

                Rectangle {
                    x: hours.gutter
                    width: hours.width - hours.gutter
                    height: 2
                    color: Theme.red
                }
            }
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

        Item {
            visible: !hours.visible
            Layout.fillHeight: true
        }
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
                text: Tr.date(root.shown, "MMMM")
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
                text: Tr.date(root.today, "dddd")
                visible: root.showingThisMonth
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.accent
            }

            PillButton {
                visible: !root.showingThisMonth
                text: Tr.t("Today")
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
                    readonly property int events: cell.key !== "" ? AgendaService.on(cell.key).length : 0
                    readonly property bool marked: cell.tasks > 0 || cell.events > 0

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.centerIn: parent
                        // No larger than a day needs, however big the card.
                        width: Math.min(parent.width, parent.height, 34)
                        height: width
                        radius: width / 2
                        color: cell.isToday ? Theme.accent : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: cell.marked ? -1 : 0
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

                        // Tasks due or events: accent while a task is open or
                        // an event is on, muted once every task is done.
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            visible: cell.marked
                            width: 3
                            height: 3
                            radius: 1.5
                            color: cell.isToday ? Theme.accentText
                                : (cell.pending > 0 || cell.events > 0 ? Theme.accent : Theme.textMuted)
                        }

                        // Only days with tasks or events are clickable.
                        HoverHandler {
                            enabled: cell.marked
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            enabled: cell.marked
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: root.picked = cell.key
                        }
                    }
                }
            }
        }
    }
}
