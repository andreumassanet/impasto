// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S T A T S   M O D U L E                                                │
// │   system load · ring, sparklines when open                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// CPU load on the chip; the detail shows CPU and memory with recent history.
// Cores, disks and temperatures are in the stats panel. The ring steps through
// the indicator hues like the battery's.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    readonly property color loadTint: {
        if (StatsService.cpu >= 90)
            return Theme.indicatorBad
        if (StatsService.cpu >= 70)
            return Theme.indicatorWarn
        return Theme.indicator
    }

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    Component {
        id: chip

        Item {
            Item {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight

                RingIndicator {
                    anchors.fill: parent
                    thickness: 2.5
                    progress: StatsService.cpu / 100
                    trackColor: Theme.indicatorDim
                    fillColor: root.loadTint

                    Behavior on fillColor {
                        ColorAnimation { duration: Theme.durationMedium }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰻠"
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(Theme.capsuleHeight * 0.38)
                        color: Theme.indicator
                    }
                }
            }
        }
    }

    // The CPU ring is the mark and its load the figure; then processor and
    // memory as shares, and both histories side by side.
    Component {
        id: detail

        ModuleCard {
            title: Tr.t("System")
            subtitle: StatsService.cpuModel !== "" ? StatsService.cpuModel : StatsService.window
            figure: `${StatsService.cpu.toFixed(0)}%`
            figureColor: root.loadTint

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: StatsService.cpu / 100
                trackColor: Theme.indicatorDim
                fillColor: root.loadTint

                Behavior on fillColor {
                    ColorAnimation { duration: Theme.durationMedium }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰻠"
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: Theme.indicator
                }
            }

            CardLimit {
                name: Tr.t("Processor")
                fraction: StatsService.cpu / 100
                known: StatsService.ready
                tint: Theme.accent
                note: Tr.t("load %1").arg(StatsService.load[0].toFixed(2))
            }

            CardLimit {
                name: Tr.t("Memory")
                fraction: StatsService.memoryFraction
                known: StatsService.memoryTotal > 0
                tint: Theme.blue
                note: StatsService.bytes(StatsService.memoryUsed)
            }

            // Each series under its own share, in its colour.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 16

                Sparkline {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    values: StatsService.cpuHistory
                    maximum: 1
                    stroke: Theme.accent
                }

                Sparkline {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    values: StatsService.memoryHistory
                    maximum: 1
                    stroke: Theme.blue
                }
            }
        }
    }
}
