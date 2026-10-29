// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O N I T O R   T A B                                                  │
// │   the dashboard's system monitor · processor, memory, disks, network     │
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

// First the processor, with a bar per core, and every GPU; then memory, the
// disks and the network (both ways, and since boot); then the batteries of
// connected devices. Load and memory are `StatsService`'s; the rest is
// `SystemMonitorService`, which polls only while this tab is open.
Flickable {
    id: root

    // The arrows in the colour of their line in the graph.
    readonly property color downColor: Theme.accent
    readonly property color upColor: Theme.indicatorGood

    readonly property int graphHeight: 44

    contentHeight: grid.implicitHeight
    implicitHeight: grid.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Component.onCompleted: SystemMonitorService.subscribe()
    Component.onDestruction: SystemMonitorService.release()

    function percent(fraction: real): string {
        return `${Math.round(fraction * 100)} %`
    }

    function levelColor(fraction: real): color {
        return fraction >= 0.9 ? Theme.indicatorBad : fraction >= 0.7 ? Theme.indicatorWarn : Theme.accent
    }

    // A label, a bar and its figure.
    component Level: ColumnLayout {
        id: level

        property string label: ""
        property string figure: ""
        property real fraction: 0
        // "load" warns when high, "battery" when low, "plain" never.
        property string tone: "load"

        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: level.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.text
            }

            Text {
                text: level.figure
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.features: { "tnum": 1 }
                color: Theme.textMuted
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: 3
            color: Theme.surfaceHoverIn(QsWindow.window)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, level.fraction))
                height: parent.height
                radius: 3
                color: level.tone === "plain" ? Theme.accent
                    : level.tone === "battery" ? (level.fraction < 0.2 ? Theme.indicatorBad : Theme.accent)
                    : root.levelColor(level.fraction)
            }
        }
    }

    component Headline: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: Theme.text
    }

    GridLayout {
        id: grid

        width: root.width
        columns: 3
        columnSpacing: 12
        rowSpacing: 12

        DashCard {
            title: Tr.t("Processor")
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            Headline {
                text: [root.percent(StatsService.cpu / 100),
                       SystemMonitorService.cpuTemp > 0 ? `${Math.round(SystemMonitorService.cpuTemp)}°` : "",
                       SystemMonitorService.cpuPowerAvailable ? `${SystemMonitorService.cpuPower.toFixed(1)} W` : ""]
                    .filter(part => part !== "").join("  ·  ")
                color: root.levelColor(StatsService.cpu / 100)
            }

            Sparkline {
                Layout.fillWidth: true
                Layout.preferredHeight: root.graphHeight
                values: StatsService.cpuHistory
                stroke: root.levelColor(StatsService.cpu / 100)
            }

            // Per core, because an average hides a single pinned core.
            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: ScriptModel {
                        values: StatsService.cores
                    }

                    Rectangle {
                        required property real modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        radius: 2
                        color: Theme.surfaceHoverIn(QsWindow.window)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: Math.max(2, parent.height * Math.min(1, modelData / 100))
                            radius: 2
                            color: modelData > 80 ? Theme.red : Theme.accent
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: `${StatsService.cpuModel || Tr.t("Processor")} · ${Tr.t("load")} ${(StatsService.load[0] ?? 0).toFixed(2)} · ${StatsService.cores.length} ${Tr.t("threads")}`
                    + (SystemMonitorService.cpuPowerAvailable ? "" : ` · ${Tr.t("power unreadable")}`)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }
        }

        Repeater {
            model: SystemMonitorService.gpus

            DashCard {
                id: gpuCard

                required property var modelData
                readonly property real usage: gpuCard.modelData.usage ?? 0

                title: `GPU · ${gpuCard.modelData.name}`
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop

                Headline {
                    text: [gpuCard.modelData.usage === null || gpuCard.modelData.usage === undefined ? "—" : root.percent(gpuCard.usage),
                           gpuCard.modelData.temp ? `${Math.round(gpuCard.modelData.temp)}°` : "",
                           gpuCard.modelData.power ? `${Number(gpuCard.modelData.power).toFixed(1)} W` : ""]
                        .filter(part => part !== "").join("  ·  ")
                }

                Sparkline {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.graphHeight
                    values: gpuCard.modelData.history ?? []
                }

                Level {
                    visible: (gpuCard.modelData.vramTotalMiB ?? 0) > 0
                    label: "VRAM"
                    fraction: (gpuCard.modelData.vramUsedMiB ?? 0) / Math.max(1, gpuCard.modelData.vramTotalMiB ?? 1)
                    figure: `${Math.round(gpuCard.modelData.vramUsedMiB ?? 0)} / ${Math.round(gpuCard.modelData.vramTotalMiB ?? 0)} MiB`
                }

                Level {
                    visible: (gpuCard.modelData.maxFreqMHz ?? 0) > 0
                    label: Tr.t("Clock")
                    tone: "plain"
                    fraction: (gpuCard.modelData.freqMHz ?? 0) / Math.max(1, gpuCard.modelData.maxFreqMHz ?? 1)
                    figure: `${gpuCard.modelData.freqMHz ?? 0} / ${gpuCard.modelData.maxFreqMHz ?? 0} MHz`
                }
            }
        }

        DashCard {
            title: Tr.t("Memory")
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            Level {
                label: "RAM"
                fraction: StatsService.memoryFraction
                figure: `${SystemMonitorService.formatBytes(StatsService.memoryUsed)} / ${SystemMonitorService.formatBytes(StatsService.memoryTotal)}`
            }

            Sparkline {
                Layout.fillWidth: true
                Layout.preferredHeight: root.graphHeight
                values: StatsService.memoryHistory
            }

            Level {
                visible: StatsService.swapTotal > 0
                label: "Swap"
                fraction: StatsService.swapFraction
                figure: `${SystemMonitorService.formatBytes(StatsService.swapUsed)} / ${SystemMonitorService.formatBytes(StatsService.swapTotal)}`
            }
        }

        DashCard {
            title: Tr.t("Disks")
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            Repeater {
                model: SystemMonitorService.disks

                Level {
                    required property var modelData

                    label: modelData.mount
                    fraction: modelData.used / Math.max(1, modelData.total)
                    figure: `${SystemMonitorService.formatBytes(modelData.used)} / ${SystemMonitorService.formatBytes(modelData.total)}`
                }
            }
        }

        DashCard {
            title: Tr.t("Network")
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            Headline {
                textFormat: Text.StyledText
                text: `<font color="${root.downColor}">↓</font> ${SystemMonitorService.formatRate(SystemMonitorService.ethRx + SystemMonitorService.wifiRx)}   <font color="${root.upColor}">↑</font> ${SystemMonitorService.formatRate(SystemMonitorService.ethTx + SystemMonitorService.wifiTx)}`
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.graphHeight

                Sparkline {
                    anchors.fill: parent
                    values: SystemMonitorService.downHistory
                }

                Sparkline {
                    anchors.fill: parent
                    values: SystemMonitorService.upHistory
                    stroke: root.upColor
                    showDot: false
                }
            }

            Text {
                textFormat: Text.StyledText
                text: `${Tr.t("Since boot")}  <font color="${root.downColor}">↓</font> ${SystemMonitorService.formatBytes(SystemMonitorService.ethRxTotal + SystemMonitorService.wifiRxTotal)}  <font color="${root.upColor}">↑</font> ${SystemMonitorService.formatBytes(SystemMonitorService.ethTxTotal + SystemMonitorService.wifiTxTotal)}`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            Repeater {
                model: [
                    { name: "Wi-Fi", state: NetworkService.connectionName || "—", rx: SystemMonitorService.wifiRx, tx: SystemMonitorService.wifiTx },
                    { name: "Ethernet", state: SystemMonitorService.ethRxTotal > 0 ? "" : Tr.t("Disconnected"), rx: SystemMonitorService.ethRx, tx: SystemMonitorService.ethTx }
                ]

                RowLayout {
                    required property var modelData

                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: modelData.state ? `${modelData.name} · ${modelData.state}` : modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }

                    Text {
                        textFormat: Text.StyledText
                        text: `<font color="${root.downColor}">↓</font> ${SystemMonitorService.formatRate(modelData.rx)}  <font color="${root.upColor}">↑</font> ${SystemMonitorService.formatRate(modelData.tx)}`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }
            }
        }

        DashCard {
            title: Tr.t("Devices")
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            Text {
                visible: DeviceService.devices.length === 0
                text: Tr.t("No connected device reports a battery")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            Repeater {
                model: DeviceService.devices

                Level {
                    required property var modelData

                    label: `${modelData.glyph}  ${modelData.name}`
                    tone: "battery"
                    fraction: modelData.level
                    figure: root.percent(modelData.level)
                }
            }
        }
    }
}
