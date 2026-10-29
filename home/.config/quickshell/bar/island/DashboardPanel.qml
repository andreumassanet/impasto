// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D A S H B O A R D   P A N E L                                          │
// │   system statistics as a dashboard · overview, monitor, system, weather  │
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
import "controls"

// The other design of the system statistics (`SettingsService.statsDesign`):
// more data in the island's cards, in four tabs.
//   Overview   the date and the month, the weather, the machine
//   Monitor    processor, GPUs, memory, disks, network, device batteries
//   System     pending updates, and what this machine is
//   Weather    now and the next hours
// Tab and Shift+Tab, or the arrows, switch.
FocusScope {
    id: root

    signal closed()
    // A card inside asking for another panel, e.g. the board from a task.
    signal panelRequested(string panel)

    readonly property var tabs: [Tr.t("Overview"), Tr.t("Monitor"), Tr.t("System"), Tr.t("Weather")]
    property int tab: 0

    Component.onCompleted: {
        root.forceActiveFocus()
        WeatherService.subscribe()
    }
    Component.onDestruction: WeatherService.release()

    Keys.onLeftPressed: strip.step(-1)
    Keys.onRightPressed: strip.step(1)
    Keys.onTabPressed: strip.step(1)
    Keys.onBacktabPressed: strip.step(-1)

    // "09:00", and "09:00⁺" past midnight, so 21, 0, 3 does not read as a
    // broken sort.
    function hourLabel(block: var): string {
        const hour = `${block.hour}`.padStart(2, "0")
        return block.tomorrow ? `${hour}:00⁺` : `${hour}:00`
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.cardGap

        PanelTabs {
            id: strip

            tabs: root.tabs
            current: root.tab
            onPicked: index => root.tab = index
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: [overview, monitor, system, weather][root.tab]
        }
    }

    // A count with its glyph and what it counts.
    component StatTile: Rectangle {
        id: tile

        property string glyph: ""
        property color tint: Theme.accent
        property string figure: ""
        property string label: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Theme.radiusMedium
        color: Theme.surfaceHoverIn(QsWindow.window)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: tile.glyph
                font.family: Theme.fontMono
                font.pixelSize: 22
                color: tile.tint
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: tile.figure
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: tile.label
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }
        }
    }

    // ── OVERVIEW ────────────────────────────────────────────────────────────

    Component {
        id: overview

        RowLayout {
            spacing: 12

            // The date, and the month with today marked.
            ColumnLayout {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                spacing: 12

                DashCard {
                    Layout.fillWidth: true

                    Text {
                        text: Qt.formatTime(clock.date, SettingsService.clockFormat)
                        font.family: Theme.fontDisplay
                        font.pixelSize: 56
                        font.weight: Font.Medium
                        color: Theme.text
                    }

                    Text {
                        text: Qt.formatDate(clock.date, "dddd d MMMM")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.textMuted
                    }
                }

                CalendarCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onPanelRequested: panel => root.panelRequested(panel)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // Weather now and the next hours.
                DashCard {
                    title: WeatherService.place !== ""
                        ? `${Tr.t("Weather")} · ${WeatherService.place}` : Tr.t("Weather")
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        WeatherIcon {
                            glyph: WeatherService.available ? WeatherService.glyph : ""
                            size: 50
                        }

                        ColumnLayout {
                            spacing: 0

                            Text {
                                text: WeatherService.available ? `${WeatherService.temperature}°` : "—"
                                font.family: Theme.fontDisplay
                                font.pixelSize: 36
                                color: Theme.text
                            }

                            Text {
                                text: WeatherService.available
                                    ? `${WeatherService.description} · ${WeatherService.low}° / ${WeatherService.high}°`
                                    : Tr.t("No reading")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.textMuted
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: ScriptModel {
                                values: WeatherService.ahead
                            }

                            ColumnLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.hourLabel(modelData)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel
                                    color: Theme.textMuted
                                }

                                WeatherIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    glyph: modelData.glyph
                                    size: 26
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: `${modelData.temperature}°`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.text
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // Only while Claude is on the bar, where its module keeps the
                // service running; the card never starts it.
                Loader {
                    Layout.fillWidth: true
                    active: SettingsService.onBar("claude")
                    visible: active
                    sourceComponent: Component { DashClaudeCard {} }
                }
            }

            // The machine: rings for the processor, memory, temperature and
            // battery.
            DashCard {
                title: Tr.t("This machine")
                Layout.preferredWidth: 260
                Layout.fillHeight: true

                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6
                    columns: 2
                    rowSpacing: 16
                    columnSpacing: 28

                    Repeater {
                        model: [
                            { label: Tr.t("CPU"), fraction: StatsService.cpu / 100, text: `${Math.round(StatsService.cpu)}%` },
                            { label: Tr.t("Memory"), fraction: StatsService.memoryFraction, text: `${Math.round(StatsService.memoryFraction * 100)}%` },
                            { label: Tr.t("Temperature"), fraction: (StatsService.temperature?.celsius ?? 0) / 100,
                              text: StatsService.temperature ? `${Math.round(StatsService.temperature.celsius)}°` : "—" },
                            { label: Tr.t("Battery"), fraction: BatteryService.available ? BatteryService.percent / 100 : 0,
                              text: BatteryService.available ? `${BatteryService.percent}%` : Tr.t("AC"), battery: true }
                        ]

                        ColumnLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 6

                            RingIndicator {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 84
                                Layout.preferredHeight: 84
                                thickness: 7
                                progress: modelData.fraction
                                trackColor: Theme.surfaceHoverIn(QsWindow.window)
                                // The battery warns when low, the rest when high.
                                fillColor: (modelData.battery === true ? modelData.fraction < 0.2 : modelData.fraction >= 0.9)
                                    ? Theme.indicatorBad : Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.textMuted
                            }
                        }
                    }
                }

                Text {
                    Layout.topMargin: 6
                    text: `${Tr.t("Up")} ${StatsService.duration(StatsService.uptime)} · ${Tr.t("load")} ${(StatsService.load[0] ?? 0).toFixed(2)}`
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── MONITOR ─────────────────────────────────────────────────────────────

    Component {
        id: monitor

        MonitorTab {}
    }

    // ── SYSTEM ──────────────────────────────────────────────────────────────
    //
    // For display only: the updates are the hourly-polled list the updates
    // module reads, and the machine is what the control centre's about card
    // reads.

    Component {
        id: system

        RowLayout {
            spacing: 12

            Component.onCompleted: {
                UpdatesService.subscribe()
                MachineService.refresh()
            }
            Component.onDestruction: UpdatesService.release()

            DashCard {
                id: updatesCard

                readonly property var repo: UpdatesService.updates.filter(update => update.source === "repo")
                readonly property var aur: UpdatesService.updates.filter(update => update.source === "aur")

                title: Tr.t("Updates")
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StatTile {
                        glyph: "󰏖"
                        tint: Theme.accent
                        figure: UpdatesService.checkedAt <= 0 ? (UpdatesService.checking ? "…" : "—") : String(updatesCard.repo.length)
                        label: Tr.t("repositories")
                    }

                    StatTile {
                        glyph: "󰣇"
                        tint: Theme.indicatorWarn
                        figure: UpdatesService.checkedAt <= 0 ? (UpdatesService.checking ? "…" : "—") : String(updatesCard.aur.length)
                        label: "AUR"
                    }
                }

                Text {
                    text: UpdatesService.checking ? Tr.t("Checking…")
                        : UpdatesService.checkedAt > 0 ? `${Tr.t("Checked")} ${UpdatesService.age}` : Tr.t("Not checked yet")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: lists.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: lists

                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: [
                                { glyph: "󰏖", name: Tr.t("Repositories"), tint: Theme.accent, entries: updatesCard.repo },
                                { glyph: "󰣇", name: "AUR", tint: Theme.indicatorWarn, entries: updatesCard.aur }
                            ]

                            Column {
                                required property var modelData

                                width: lists.width
                                visible: modelData.entries.length > 0
                                spacing: 2

                                Text {
                                    height: 26
                                    verticalAlignment: Text.AlignBottom
                                    text: `${modelData.glyph}  ${modelData.name} · ${modelData.entries.length}`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: modelData.tint
                                }

                                Repeater {
                                    model: parent.modelData.entries

                                    RowLayout {
                                        required property var modelData

                                        width: lists.width
                                        height: 22
                                        spacing: 8

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            elide: Text.ElideRight
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.text
                                        }

                                        Text {
                                            text: modelData.to
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeLabel
                                            color: Theme.textMuted
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // The facts of this machine, one to a line.
            DashCard {
                id: machineCard

                readonly property var disk: StatsService.disks.find(entry => entry.target === "/")
                readonly property var facts: [
                    { glyph: "󰣇", key: Tr.t("OS"), value: MachineService.os },
                    { glyph: "󰒓", key: Tr.t("Kernel"), value: MachineService.kernel },
                    { glyph: "󰅐", key: Tr.t("Uptime"), value: StatsService.uptime > 0 ? StatsService.duration(StatsService.uptime) : "" },
                    { glyph: "󰏖", key: Tr.t("Packages"), value: MachineService.packages !== null ? String(MachineService.packages) : "" },
                    { glyph: "󰆍", key: Tr.t("Shell"), value: MachineService.shell },
                    { glyph: "󱂬", key: Tr.t("WM"), value: MachineService.wm },
                    { glyph: "󰻠", key: Tr.t("CPU"), value: StatsService.cpuModel }
                ].concat([
                    { glyph: "󰍛", key: Tr.t("Memory"), value: StatsService.memoryTotal > 0
                        ? `${StatsService.bytes(StatsService.memoryUsed)} / ${StatsService.bytes(StatsService.memoryTotal)}` : "" },
                    { glyph: "󰋊", key: Tr.t("Disk") + " (/)", value: machineCard.disk
                        ? `${StatsService.bytes(machineCard.disk.used)} / ${StatsService.bytes(machineCard.disk.total)}` : "" },
                    { glyph: "󰁹", key: Tr.t("Battery"), value: BatteryService.available
                        ? `${BatteryService.percent} %` + (BatteryService.healthKnown ? ` · ${Tr.t("health")} ${BatteryService.health} %` : "") : "" },
                    { glyph: "󰩟", key: Tr.t("Address"), value: SystemMonitorService.addresses
                        .map(entry => entry.address.split("/")[0]).join(", ") }
                ]).filter(fact => fact.value)

                title: Tr.t("This machine")
                Layout.preferredWidth: 360
                Layout.fillHeight: true

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    textFormat: Text.StyledText
                    text: `<font color="${Theme.accent}">${AccountService.user}</font>@${MachineService.host}`
                    elide: Text.ElideRight
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeRegular
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Repeater {
                    model: machineCard.facts

                    RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 16
                            text: modelData.glyph
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.accent
                        }

                        Text {
                            Layout.preferredWidth: 66
                            text: modelData.key
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.value
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── WEATHER ─────────────────────────────────────────────────────────────
    //
    // "Now" (the sky and the temperature beside a grid of facts) over the
    // next hours, which run into tomorrow when today has none left.

    Component {
        id: weather

        ColumnLayout {
            id: weatherTab

            readonly property var upcoming: (WeatherService.hourly ?? [])
                .filter(block => block.tomorrow || block.hour > clock.date.getHours())
                .slice(0, 8)

            spacing: 12

            DashCard {
                title: WeatherService.place !== ""
                    ? `${Tr.t("Now")} · ${WeatherService.place}, ${WeatherService.region}` : Tr.t("Now")
                Layout.fillWidth: true
                Layout.preferredHeight: 220

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 18

                    // The sky, the temperature, the conditions. A layout in a
                    // layout fills by default; this one keeps its width so the
                    // facts get the rest.
                    ColumnLayout {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 220
                        spacing: 2

                        RowLayout {
                            spacing: 12

                            WeatherIcon {
                                glyph: WeatherService.available ? WeatherService.glyph : ""
                                size: 64
                            }

                            Text {
                                text: WeatherService.available ? `${WeatherService.temperature}°` : "—"
                                font.family: Theme.fontDisplay
                                font.pixelSize: 46
                                color: Theme.text
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: WeatherService.available ? WeatherService.description : Tr.t("No reading")
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeRegular
                            color: Theme.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: WeatherService.available
                            text: `${WeatherService.low}° ${Tr.t("low")} · ${WeatherService.high}° ${Tr.t("high")}`
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: [
                                { glyph: "󰔏", key: Tr.t("Feels like"), value: `${WeatherService.feelsLike}°` },
                                { glyph: "󰖎", key: Tr.t("Humidity"), value: `${WeatherService.humidity} %` },
                                { glyph: "󰖝", key: Tr.t("Wind"), value: `${WeatherService.wind} km/h` },
                                { glyph: "󰅐", key: Tr.t("Updated"), value: WeatherService.age }
                            ]

                            Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radiusMedium
                                color: Theme.surfaceHoverIn(QsWindow.window)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: `${modelData.glyph}  ${modelData.key}`
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel
                                        color: Theme.textMuted
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: WeatherService.available && modelData.value !== "" ? modelData.value : "—"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeRegular
                                        font.weight: Font.DemiBold
                                        font.features: { "tnum": 1 }
                                        color: Theme.text
                                    }
                                }
                            }
                        }
                    }
                }
            }

            DashCard {
                title: Tr.t("Next hours")
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Repeater {
                        model: ScriptModel {
                            values: weatherTab.upcoming
                        }

                        ColumnLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.hourLabel(modelData)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: Theme.textMuted
                            }

                            WeatherIcon {
                                Layout.alignment: Qt.AlignHCenter
                                glyph: modelData.glyph
                                size: 28
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: `${modelData.temperature}°`
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            // Only when there is some chance of rain.
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                visible: modelData.rain >= 20
                                text: `${modelData.rain}%`
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: Theme.blue
                            }
                        }
                    }
                }
            }
        }
    }
}
