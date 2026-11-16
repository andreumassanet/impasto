// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D A S H   C L A U D E   C A R D                                        │
// │   Claude's limits on the dashboard                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The rows of the bar module's card (`ClaudeModule`), on a dashboard card.
// Only drawn while Claude is on the bar (`DashboardPanel` loads it then):
// reading `ClaudeService` is what starts its first query, and the bar's
// module is what keeps it subscribed, so this card neither starts nor
// subscribes it.
DashCard {
    title: "Claude"

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
