// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T   I   M   E   R       F   A   C   E                                  │
// │   the countdown as an hourglass · what is left is above the neck         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// The timer as an hourglass: the sand above is the time left, and the thread
// runs while it counts and stops when paused. The 4×2 adds the time, the label
// and the same two controls as the Modern face.
Instrument {
    id: face

    readonly property bool on: TimerService.running

    line: face.on
        ? `${TimerService.display}${TimerService.label !== "" ? " · " + TimerService.label : ""}`
        : Tr.t("Nothing running")
    reading: face.on ? TimerService.display : "—"
    note: face.on ? (TimerService.label !== "" ? TimerService.label : Tr.t("counting down")) : Tr.t("nothing running")
    tint: face.on ? face.ink.text : face.ink.muted
    filled: true

    Hourglass {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.height, parent.width / 0.72)
        fraction: face.on && TimerService.duration > 0 ? TimerService.remaining / TimerService.duration : 0
        running: face.on && !TimerService.paused
    }

    extra: [
        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            spacing: 10

            PillButton {
                text: TimerService.running
                    ? (TimerService.paused ? Tr.t("Resume") : Tr.t("Hold")) : "5 min"
                implicitHeight: 30
                onClicked: {
                    if (!TimerService.running)
                        TimerService.start(5 * 60 * 1000, "")
                    else
                        TimerService.toggle()
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                iconColor: face.ink.text
                icon: "󰅖"
                iconSize: 13
                enabled: TimerService.running
                opacity: TimerService.running ? 1 : 0.35
                onClicked: TimerService.cancel()
            }
        }
    ]
}
