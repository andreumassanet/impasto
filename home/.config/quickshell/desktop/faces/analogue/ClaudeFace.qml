// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   L   A   U   D   E       F   A   C   E                              │
// │   claude code usage as a fuel gauge                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// Claude usage as a fuel gauge: F with the block untouched, E when it is spent,
// red at the empty end. Uses the account's figure when available, else the
// block's elapsed time.
Instrument {
    id: face

    readonly property string figure: !ClaudeService.available ? "—"
        : ClaudeService.sessionMeasured
        ? ClaudeService.percent(ClaudeService.sessionFraction)
        : ClaudeService.compact(ClaudeService.blockTokens)

    line: !ClaudeService.available ? Tr.t("No usage found")
        : (ClaudeService.sessionMeasured ? Tr.t("%1 of this block").arg(face.figure) : Tr.t("%1 this block").arg(face.figure))
    reading: face.figure
    note: !ClaudeService.available ? Tr.t("no usage found")
        : ClaudeService.sessionMeasured
        ? `${Tr.t("of this block")} · ${ClaudeService.resetsIn}`
        : `${Tr.t("this block")} · ${ClaudeService.resetsIn}`
    filled: true

    Gauge {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height)
        fraction: 1 - ClaudeService.gauge
        lowIsBad: true
        ends: ["E", "F"]

        ClaudeMark {
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
                progress: ClaudeService.weeklyFraction
                fillColor: face.ink.accent
                trackColor: face.ink.raised
            }

            Text {
                text: ClaudeService.weeklyMeasured
                    ? Tr.t("%1 of the week").arg(ClaudeService.percent(ClaudeService.weeklyFraction)) : Tr.t("this week")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: face.ink.muted
            }
        }
    ]
}
