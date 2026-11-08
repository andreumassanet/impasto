// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N E T   S P E E D   M O D U L E                                        │
// │   the traffic · speed now, totals, the route out, recent history         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// Download and upload on the chip (`ModuleService`); the card adds the
// totals, the interface the traffic leaves by and its address, and both
// histories on one ceiling so the two compare. Everything is `StatsService`'s
// sampler, which runs from boot. The connection itself is the network
// module's.
Item {
    id: root

    property bool compact: false

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    readonly property real ceiling: Math.max(1024,
        ...StatsService.downHistory, ...StatsService.upHistory)

    ModuleCard {
        id: card

        anchors.fill: parent
        title: Tr.t("Network speed")
        subtitle: StatsService.window

        mark: RingIndicator {
            anchors.fill: parent
            thickness: 3
            progress: 0
            trackColor: Theme.indicatorDim

            Text {
                anchors.centerIn: parent
                text: "󰓅"
                font.family: Theme.fontMono
                font.pixelSize: 18
                color: Theme.indicator
            }
        }

        CardFact {
            name: Tr.t("Now")
            value: `↓ ${StatsService.rate(StatsService.networkDown)}   ↑ ${StatsService.rate(StatsService.networkUp)}`
        }

        CardFact {
            name: Tr.t("Since boot")
            value: `↓ ${StatsService.bytes(StatsService.networkReceived)}   ↑ ${StatsService.bytes(StatsService.networkSent)}`
        }

        CardFact {
            name: StatsService.networkInterface !== "" ? StatsService.networkInterface : Tr.t("Address")
            value: StatsService.networkAddress !== "" ? StatsService.networkAddress : Tr.t("Offline")
            valueColor: StatsService.networkAddress !== "" ? Theme.text : Theme.textMuted
        }

        // Down in the accent, up muted, on the one ceiling.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            Sparkline {
                anchors.fill: parent
                values: StatsService.downHistory
                maximum: root.ceiling
            }

            Sparkline {
                anchors.fill: parent
                values: StatsService.upHistory
                maximum: root.ceiling
                stroke: Theme.textMuted
                showDot: false
            }
        }
    }
}
