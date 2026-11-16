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
// disks and the network (both ways, since boot, and the route out); then the
// batteries of connected devices. Everything is `StatsService`'s sampler but
// the GPUs and the processor's power, which `HardwareService` reads only
// while this tab is open.
Flickable {
    id: root

    // The arrows in the colour of their line in the graph.
    readonly property color downColor: Theme.accent
    readonly property color upColor: Theme.indicatorGood

    readonly property int graphHeight: 44

    // Both network histories on one ceiling, so the two compare.
    readonly property real ceiling: Math.max(1024,
        ...StatsService.downHistory, ...StatsService.upHistory)

    contentHeight: grid.implicitHeight
    implicitHeight: grid.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Component.onCompleted: HardwareService.subscribe()
    Component.onDestruction: HardwareService.release()

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
                       StatsService.temperature ? `${Math.round(StatsService.temperature.celsius)}°` : "",
                       HardwareService.cpuPowerAvailable ? `${HardwareService.cpuPower.toFixed(1)} W` : ""]
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
                    + (HardwareService.cpuPowerAvailable ? "" : ` · ${Tr.t("power unreadable")}`)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }
        }

        Repeater {
            // Kept across samples, so a card's sparkline is not rebuilt every 3 s.
            model: ScriptModel {
                objectProp: "name"
                values: HardwareService.gpus
            }

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
                figure: `${StatsService.bytes(StatsService.memoryUsed)} / ${StatsService.bytes(StatsService.memoryTotal)}`
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
                figure: `${StatsService.bytes(StatsService.swapUsed)} / ${StatsService.bytes(StatsService.swapTotal)}`
            }
        }

        DashCard {
            title: Tr.t("Disks")
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            Repeater {
                model: ScriptModel {
                    objectProp: "target"
                    values: StatsService.disks
                }

                Level {
                    required property var modelData

                    label: modelData.target
                    fraction: modelData.used / Math.max(1, modelData.total)
                    figure: `${StatsService.bytes(modelData.used)} / ${StatsService.bytes(modelData.total)}`
                }
            }
        }

        DashCard {
            title: Tr.t("Network")
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            Headline {
                textFormat: Text.StyledText
                text: `<font color="${root.downColor}">↓</font> ${StatsService.rate(StatsService.networkDown)}   <font color="${root.upColor}">↑</font> ${StatsService.rate(StatsService.networkUp)}`
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.graphHeight

                Sparkline {
                    anchors.fill: parent
                    values: StatsService.downHistory
                    maximum: root.ceiling
                }

                Sparkline {
                    anchors.fill: parent
                    values: StatsService.upHistory
                    maximum: root.ceiling
                    stroke: root.upColor
                    showDot: false
                }
            }

            Text {
                textFormat: Text.StyledText
                text: `${Tr.t("Since boot")}  <font color="${root.downColor}">↓</font> ${StatsService.bytes(StatsService.networkReceived)}  <font color="${root.upColor}">↑</font> ${StatsService.bytes(StatsService.networkSent)}`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            // The route out: the interface the traffic leaves by and its address.
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: StatsService.networkInterface !== "" ? StatsService.networkInterface : Tr.t("Address")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                }

                Text {
                    text: StatsService.networkAddress !== "" ? StatsService.networkAddress : Tr.t("Offline")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
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
