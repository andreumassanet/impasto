// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N E T   S P E E D   M O D U L E                                        │
// │   the connection in detail · speeds, name, addresses, totals, graph      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The network in detail, opened from the speed on the bar. The heading is the
// speed now, down and up, with the Wi-Fi signal beside it, all in one size.
// Under it the network's name, which wraps so a long one keeps its room; a line
// for each interface that has an address; the totals since boot; the last
// minutes drawn (`StatsService`) with a legend, a scale and a time axis; and
// the button to the Wi-Fi menu. The card's height is declared in
// `ModuleService.openSize`, so a row added here is counted there.
Item {
    id: root

    property bool compact: false

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Component.onCompleted: {
        SystemMonitorService.subscribe()
        SystemMonitorService.refreshAddresses()
    }
    Component.onDestruction: SystemMonitorService.release()

    ModuleCard {
        id: card

        anchors.fill: parent
        title: `↓ ${StatsService.rate(StatsService.networkDown)}   ↑ ${StatsService.rate(StatsService.networkUp)}`
        figure: NetworkService.wifiConnected ? `${Math.round(NetworkService.strength * 100)}%` : ""
        figureSize: Theme.fontSizeMedium

        mark: Text {
            anchors.centerIn: parent
            text: NetworkService.icon
            font.family: Theme.fontMono
            font.pixelSize: 20
            color: Theme.indicator
        }

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Theme.cardRow, implicitHeight)
            text: NetworkService.connectionName
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Repeater {
            model: SystemMonitorService.addresses

            CardFact {
                required property var modelData

                name: modelData.name
                value: modelData.address
            }
        }

        CardFact {
            visible: SystemMonitorService.addresses.length === 0
            name: "Address"
            value: "—"
        }

        CardFact {
            name: "Since boot"
            value: `↓ ${SystemMonitorService.formatBytes(SystemMonitorService.ethRxTotal + SystemMonitorService.wifiRxTotal)}  ↑ ${SystemMonitorService.formatBytes(SystemMonitorService.ethTxTotal + SystemMonitorService.wifiTxTotal)}`
        }

        // Down in the accent, up muted, on one ceiling so the two compare. The
        // legend names the two lines, the left axis the ceiling, the bottom
        // one how far back the sampler's history goes.
        ColumnLayout {
            id: graph

            readonly property real ceiling: Math.max(1024,
                ...StatsService.downHistory, ...StatsService.upHistory)
            readonly property int minutes: Math.round(StatsService.historyLength * StatsService.pollInterval / 1000 / 60)
            readonly property color axis: Qt.alpha(Theme.textMuted, 0.45)
            readonly property int labelWidth: 62

            Layout.fillWidth: true
            Layout.preferredHeight: ModuleService.netGraphHeight
            Layout.topMargin: 4
            spacing: 4

            RowLayout {
                Layout.preferredHeight: 16
                Layout.leftMargin: graph.labelWidth + 6
                spacing: 14

                Repeater {
                    model: [
                        { label: "↓ Download", color: Theme.accent },
                        { label: "↑ Upload", color: Theme.textMuted }
                    ]

                    RowLayout {
                        required property var modelData

                        spacing: 6

                        Rectangle {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 2
                            radius: 1
                            color: parent.modelData.color
                        }

                        Text {
                            text: parent.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                spacing: 6

                Item {
                    Layout.preferredWidth: graph.labelWidth
                    Layout.fillHeight: true

                    Text {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        text: StatsService.rate(graph.ceiling)
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        text: "0"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        width: 1
                        height: parent.height
                        color: graph.axis
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: graph.axis
                    }

                    Sparkline {
                        anchors.fill: parent
                        values: StatsService.downHistory
                        maximum: graph.ceiling
                    }

                    Sparkline {
                        anchors.fill: parent
                        values: StatsService.upHistory
                        maximum: graph.ceiling
                        stroke: Theme.textMuted
                        showDot: false
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 14
                Layout.leftMargin: graph.labelWidth + 6
                spacing: 0

                Text {
                    text: `−${graph.minutes} min`
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "now"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }
        }

        PillButton {
            Layout.topMargin: 4
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: ModuleService.netButtonHeight
            text: "Wi-Fi menu"
            onClicked: ModuleService.requestPanel("wifi")
        }
    }
}
