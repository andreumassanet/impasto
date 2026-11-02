// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D A Y   P I C K E R                                                    │
// │   month grid date picker                                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Layouts

import "../theme"
import "../services"

// A month grid for picking a day, drawn inside the surface that owns it
// rather than as a popup; the owner positions and dismisses it.
//
// 42 cells so the height never changes, Monday first. Today is ringed, the
// selection filled, and days with tasks get a dot (accent while any are
// open, muted once all are done).
//
//   selected   the day it opens on, as a day key, or ""
//   picked     a day key, or "" for none — the caller closes
//   dismissed  Escape
FocusScope {
    id: root

    property string selected: ""

    signal picked(string day)
    signal dismissed()

    readonly property var weekdays: Tr.t("M T W T F S S").split(" ")
    readonly property int cell: 30
    readonly property int gap: 2
    readonly property int pad: 12

    readonly property date today: TasksService.clock.date

    // Offset in months from the current one.
    property int offsetMonths: 0

    readonly property date shown:
        new Date(root.today.getFullYear(), root.today.getMonth() + root.offsetMonths, 1)
    readonly property int year: root.shown.getFullYear()
    readonly property int month: root.shown.getMonth()
    readonly property int daysInMonth: new Date(root.year, root.month + 1, 0).getDate()
    readonly property int daysInPrevious: new Date(root.year, root.month, 0).getDate()
    readonly property int leadingBlanks: (new Date(root.year, root.month, 1).getDay() + 6) % 7
    readonly property bool showingThisMonth: root.offsetMonths === 0

    implicitWidth: 7 * root.cell + 6 * root.gap + 2 * root.pad
    implicitHeight: column.implicitHeight + 2 * root.pad
    width: implicitWidth
    height: implicitHeight

    Component.onCompleted: {
        const date = TasksService.dateOf(root.selected) ?? root.today
        root.offsetMonths = (date.getFullYear() - root.today.getFullYear()) * 12
            + date.getMonth() - root.today.getMonth()
    }

    Keys.onEscapePressed: root.dismissed()
    Keys.onLeftPressed: root.offsetMonths -= 1
    Keys.onRightPressed: root.offsetMonths += 1

    // Lifted off the island's black so the plate reads as a surface.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.surfaceIn(QsWindow.window)
        border.color: Theme.borderIn(QsWindow.window)
        border.width: 1
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: Tr.date(root.shown, "MMMM")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                text: root.year
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: Theme.textMuted
            }

            Item { Layout.fillWidth: true }

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
            columns: 7
            rowSpacing: root.gap
            columnSpacing: root.gap

            // The wheel pages the month.
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
                    Layout.preferredWidth: root.cell
                    Layout.preferredHeight: 16
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }
            }

            Repeater {
                model: 42

                Item {
                    id: day

                    required property int index

                    readonly property int offset: day.index - root.leadingBlanks
                    readonly property bool inMonth: day.offset >= 0 && day.offset < root.daysInMonth
                    readonly property int number: {
                        if (day.offset < 0)
                            return root.daysInPrevious + day.offset + 1
                        if (day.offset >= root.daysInMonth)
                            return day.offset - root.daysInMonth + 1
                        return day.offset + 1
                    }
                    // Day key for this cell, including the spill-over days
                    // of the adjacent months, which can be picked too.
                    readonly property string key: TasksService.dayKey(
                        new Date(root.year, root.month, day.offset + 1))
                    readonly property bool isToday: day.key === TasksService.todayKey
                    readonly property bool chosen: day.key === root.selected
                    readonly property int tasks: TasksService.countOn(day.key)
                    readonly property int pending: TasksService.pendingOn(day.key)

                    Layout.preferredWidth: root.cell
                    Layout.preferredHeight: root.cell

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: day.chosen ? Theme.accent
                            : (hover.hovered ? Theme.surfaceHoverIn(QsWindow.window) : Qt.alpha(Theme.surfaceHoverIn(QsWindow.window), 0))
                        border.color: day.isToday && !day.chosen ? Theme.accent : "transparent"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: day.number
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: day.chosen || day.isToday ? Font.DemiBold : Font.Normal
                        color: day.chosen ? Theme.accentText
                            : (day.inMonth ? Theme.text : Theme.textMuted)
                        opacity: day.inMonth || day.chosen ? 1 : 0.5
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 3
                        height: 3
                        radius: 1.5
                        visible: day.tasks > 0
                        color: day.chosen ? Theme.accentText
                            : (day.pending > 0 ? Theme.accent : Theme.textMuted)
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: root.picked(day.key)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 6

            PillButton {
                text: Tr.t("Today")
                implicitHeight: 22
                horizontalPadding: 9
                onClicked: root.picked(TasksService.todayKey)
            }

            PillButton {
                text: Tr.t("Tomorrow")
                implicitHeight: 22
                horizontalPadding: 9
                onClicked: root.picked(TasksService.shifted(1))
            }

            Item { Layout.fillWidth: true }

            PillButton {
                visible: root.selected !== ""
                text: Tr.t("No day")
                implicitHeight: 22
                horizontalPadding: 9
                onClicked: root.picked("")
            }
        }
    }
}
