// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T I M E R   M O D U L E                                                │
// │   countdown timer · set, pause and cancel                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"
import "../widgets"

// Idle, the ring is empty and the detail sets a countdown; running, the ring
// drains and the detail holds, restarts or stops it. Clicking the chip never
// cancels.
Item {
    id: root

    property bool compact: false

    // The duration Start will use, seeded from the last run so restarting is
    // one click.
    property int hours: 0
    property int minutes: 5
    property int seconds: 0

    // The countdown Start would begin, shown on the idle ring.
    readonly property string preview: {
        const pad = value => value < 10 ? `0${value}` : `${value}`
        if (root.hours > 0)
            return `${root.hours}:${pad(root.minutes)}:${pad(root.seconds)}`
        return `${root.minutes}:${pad(root.seconds)}`
    }

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    readonly property int pending:
        (root.hours * 3600 + root.minutes * 60 + root.seconds) * 1000

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face; `ChipFace` draws the remaining time beside it.
    Component {
        id: chip

        Item {
            TimerWidget {
                id: mark
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.capsuleHeight
            }
        }
    }

    // The ring is the mark and the time the figure. Idle, the first row sets
    // the duration; running, it is the share left. The controls are the
    // second.
    Component {
        id: detail

        ModuleCard {
            title: TimerService.running ? (TimerService.label || Tr.t("Countdown")) : Tr.t("Timer")
            subtitle: {
                if (!TimerService.running)
                    return Tr.t("Set a countdown")
                return TimerService.paused ? Tr.t("Held") : Tr.t("Running")
            }
            figure: TimerService.running ? TimerService.display : root.preview
            figureColor: TimerService.paused ? Theme.textMuted : Theme.text

            mark: TimerWidget {
                anchors.fill: parent
                size: Theme.cardMark
                thickness: 3
            }

            CardLimit {
                visible: TimerService.running
                name: Tr.t("Time left")
                fraction: TimerService.progress
                tint: TimerService.tint
                note: TimerService.paused
                    ? Tr.t("held") : Tr.t("ends %1").arg(Tr.date(new Date(TimerService.endsAt), "HH:mm"))
            }

            // A RowLayout so the three fields split the card's width.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow
                visible: !TimerService.running
                spacing: 9

                Stepper {
                    Layout.fillWidth: true
                    value: root.hours
                    maximum: 23
                    unit: "h"
                    implicitWidth: 40
                    implicitHeight: Theme.cardRow
                    onChanged: value => root.hours = value
                }

                Stepper {
                    Layout.fillWidth: true
                    value: root.minutes
                    maximum: 59
                    unit: "m"
                    implicitWidth: 40
                    implicitHeight: Theme.cardRow
                    onChanged: value => root.minutes = value
                }

                Stepper {
                    Layout.fillWidth: true
                    value: root.seconds
                    maximum: 59
                    unit: "s"
                    implicitWidth: 40
                    implicitHeight: Theme.cardRow
                    onChanged: value => root.seconds = value
                }
            }

            // Idle: Start and Clear share the row. Running: Hold takes the
            // spare width and Restart and Stop stay square, icon only.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow
                spacing: 9

                PillButton {
                    Layout.fillWidth: true
                    // Zero preferred width so the buttons split the row
                    // evenly regardless of their labels.
                    Layout.preferredWidth: 0
                    text: {
                        if (!TimerService.running)
                            return Tr.tIn("timer", "Start")
                        return TimerService.paused ? Tr.t("Resume") : Tr.t("Hold")
                    }
                    icon: {
                        if (!TimerService.running)
                            return "󰐊"
                        return TimerService.paused ? "󰐊" : "󰏤"
                    }
                    active: !TimerService.running || TimerService.paused
                    enabled: TimerService.running || root.pending > 0
                    implicitWidth: 88
                    implicitHeight: Theme.cardRow
                    onClicked: {
                        if (TimerService.running)
                            TimerService.toggle()
                        else
                            TimerService.start(root.pending)
                    }
                }

                PillButton {
                    Layout.fillWidth: !TimerService.running
                    Layout.preferredWidth: TimerService.running ? 46 : 0
                    text: TimerService.running ? "" : Tr.t("Clear")
                    icon: "󰜉"
                    implicitWidth: 46
                    implicitHeight: Theme.cardRow
                    onClicked: {
                        if (TimerService.running)
                            TimerService.restart()
                        else {
                            root.hours = 0
                            root.minutes = 0
                            root.seconds = 0
                        }
                    }
                }

                PillButton {
                    Layout.preferredWidth: 46
                    visible: TimerService.running
                    icon: "󰓛"
                    implicitWidth: 46
                    implicitHeight: Theme.cardRow
                    onClicked: TimerService.cancel()
                }
            }
        }
    }
}
