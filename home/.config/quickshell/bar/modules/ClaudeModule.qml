// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C L A U D E   M O D U L E                                              │
// │   claude code usage · the plan's limits and the current session          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The account's limits — the session, the week and a week per model — with
// the session's tokens and messages from the local transcripts. The ring is
// the fullest limit, or the time elapsed in the block when they are unknown.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: ClaudeService.subscribe()
    Component.onDestruction: ClaudeService.release()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face: the block's clock. `ChipFace` draws the figure.
    Component {
        id: chip

        Item {
            RingIndicator {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight
                thickness: 2.5
                progress: ClaudeService.gauge
                trackColor: Theme.indicatorDim
                fillColor: ClaudeService.tint

                Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

                ClaudeMark {
                    anchors.centerIn: parent
                    width: Math.round(Theme.capsuleHeight * 0.53)
                    height: Math.round(Theme.capsuleHeight * 0.53)
                    color: Theme.indicator
                }
            }
        }
    }

    Component {
        id: detail

        ModuleCard {
            title: "Claude Code"
            subtitle: !ClaudeService.available && !ClaudeService.limitsKnown
                ? Tr.t("No sessions on disk")
                : [ClaudeService.plan, Tr.t("session %1").arg(ClaudeService.resetsIn)]
                    .filter(part => part !== "").join(" · ")

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: ClaudeService.gauge
                trackColor: Theme.indicatorDim
                fillColor: ClaudeService.tint

                Behavior on fillColor { ColorAnimation { duration: Theme.durationMedium } }

                ClaudeMark {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    color: Theme.indicator
                }
            }

            CardLimit {
                visible: ClaudeService.limitsKnown
                name: Tr.t("Session")
                fraction: ClaudeService.sessionFraction
                resets: ClaudeService.sessionResets
                tint: ClaudeService.sessionFraction >= 0.85 ? Theme.indicatorBad
                    : ClaudeService.sessionFraction >= 0.6 ? Theme.indicatorWarn : Theme.indicator
            }

            CardLimit {
                visible: ClaudeService.limitsKnown
                name: Tr.t("Week")
                fraction: ClaudeService.weeklyFraction
                resets: ClaudeService.weekResets
                tint: ClaudeService.weeklyFraction >= 0.85 ? Theme.indicatorBad
                    : ClaudeService.weeklyFraction >= 0.6 ? Theme.indicatorWarn : Theme.indicator
            }

            // A week of its own for each model the plan limits apart.
            Repeater {
                model: ClaudeService.limitsKnown ? ClaudeService.models : []

                CardLimit {
                    required property var modelData

                    name: Tr.t("%1 · week").arg(modelData.name)
                    fraction: modelData.used
                    resets: modelData.resets
                    tint: modelData.used >= 0.85 ? Theme.indicatorBad
                        : modelData.used >= 0.6 ? Theme.indicatorWarn : Theme.indicator
                }
            }

            CardFact {
                name: Tr.t("This session")
                value: Tr.t("%1 tokens · %2").arg(ClaudeService.compact(ClaudeService.blockTokens))
                    .arg(ClaudeService.messages(ClaudeService.blockMessages))
            }

            // Without the account's figures the week is counted too.
            CardFact {
                visible: !ClaudeService.limitsKnown
                name: Tr.t("This week")
                value: Tr.t("%1 tokens · %2").arg(ClaudeService.compact(ClaudeService.weekTokens))
                    .arg(ClaudeService.messages(ClaudeService.weekMessages))
            }
        }
    }
}
