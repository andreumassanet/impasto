// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D A S H   C L A U D E   C A R D                                        │
// │   claude's session and weekly limits, for the dashboard                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// Only drawn while Claude is on the bar (`DashboardPanel` loads it then):
// reading `ClaudeService` is what starts its first query, and the bar's
// module is what keeps it subscribed, so this card neither starts nor
// subscribes it.
DashCard {
    title: "Claude"

    Repeater {
        model: [
            { label: Tr.t("Session"), fraction: ClaudeService.sessionFraction, resets: ClaudeService.resetsIn },
            { label: Tr.t("Week"), fraction: ClaudeService.weeklyFraction, resets: "" }
        ]

        ColumnLayout {
            required property var modelData

            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                }

                Text {
                    text: ClaudeService.limitsKnown
                        ? `${Math.round(modelData.fraction * 100)} %${modelData.resets ? " · " + modelData.resets : ""}` : "—"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                radius: 4
                color: Theme.surfaceHoverIn(QsWindow.window)

                Rectangle {
                    width: parent.width * modelData.fraction
                    height: parent.height
                    radius: 4
                    color: modelData.fraction >= 0.85 ? Theme.indicatorBad
                        : modelData.fraction >= 0.6 ? Theme.indicatorWarn : Theme.accent
                }
            }
        }
    }

    Text {
        text: `${ClaudeService.messages(ClaudeService.blockMessages)} ${Tr.t("this block")} · ${ClaudeService.compact(ClaudeService.weekTokens)} ${Tr.t("tokens this week")}`
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        color: Theme.textMuted
    }
}
