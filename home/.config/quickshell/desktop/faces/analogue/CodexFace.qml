// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   O   D   E   X       F   A   C   E                                  │
// │   codex usage as a fuel gauge                                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"
import "../../../components"

// Codex usage as a fuel gauge: F with the fullest window untouched, E when it
// is spent, red at the empty end. Wide, the window it reads and its reset.
Instrument {
    id: face

    line: !CodexService.available ? Tr.t("No usage found")
        : CodexService.fullest ? Tr.t("%1 of the %2").arg(CodexService.figure).arg(CodexService.fullestName)
        : Tr.t("Nothing to read until Codex runs")
    reading: CodexService.figure
    note: !CodexService.available ? Tr.t("no usage found")
        : CodexService.fullest ? CodexService.windowLine(CodexService.fullest)
        : Tr.t("until Codex runs again")
    filled: true

    Gauge {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height)
        fraction: 1 - CodexService.gauge
        lowIsBad: true
        ends: ["E", "F"]

        CodexMark {
            x: (parent.width - width) / 2
            y: parent.height * 0.28
            width: 22
            height: 22
            color: face.ink.text
        }
    }

    extra: [
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 4

            UsageBar {
                width: parent.width
                progress: CodexService.gauge
                fillColor: face.ink.accent
                trackColor: face.ink.raised
            }

            Text {
                text: [CodexService.plan, CodexService.age].filter(part => part !== "").join(" · ")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: face.ink.muted
            }
        }
    ]
}
