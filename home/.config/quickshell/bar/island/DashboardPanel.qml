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
    // The height this tab needs, for the island (`DynamicIsland`).
    signal heightWanted(int height)
    // A card inside asking for another panel, e.g. the board from a task.
    signal panelRequested(string panel)

    readonly property var tabs: [Tr.t("Overview"), Tr.t("Monitor"), Tr.t("System"), Tr.t("Weather")]
    property int tab: 0

    // Every tab is as tall as its cards, except System, whose update list
    // fills what it is given and so keeps the panel's usual height.
    readonly property int wanted: root.tab === 2 ? 614
        : Math.min(880, 2 * Theme.panelPadding + 34 + Theme.cardGap
            + Math.max(220, content.item ? content.item.implicitHeight : 400))
    onWantedChanged: root.heightWanted(root.wanted)

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
            id: content

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
            DashCard {
                Layout.preferredWidth: 300
                Layout.fillHeight: true

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

                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 4

                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]

                        Text {
                            required property string modelData

                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }
                    }

                    Repeater {
                        model: {
                            const today = clock.date
                            const first = new Date(today.getFullYear(), today.getMonth(), 1)
                            const offset = (first.getDay() + 6) % 7
                            const length = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()
                            const cells = []
                            for (let index = 0; index < offset; index++)
                                cells.push(0)
                            for (let day = 1; day <= length; day++)
                                cells.push(day)
                            return cells
                        }

                        Rectangle {
                            required property int modelData
                            readonly property bool today: modelData === clock.date.getDate()

                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 14
                            color: today ? Theme.accent : "transparent"

                            Text {
                                anchors.centerIn: parent
                                visible: parent.modelData > 0
                                text: parent.modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: parent.today ? Theme.accentText : Theme.text
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // Weather now and the next hours.
                DashCard {
                    title: WeatherService.place !== "" ? `Weather · ${WeatherService.place}` : "Weather"
                    Layout.fillWidth: true
                    // The column's height when Claude's card is not under it.
                    Layout.fillHeight: true
                    Layout.preferredHeight: 170

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        WeatherIcon {
                            name: WeatherService.icon
                            glyph: WeatherService.glyph
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
                                    ? `${WeatherService.description} · ${WeatherService.low}° / ${WeatherService.high}°` : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.textMuted
                            }
                        }

                        // As many of the next hours as the card has room
                        // for, right-aligned; never past its edge.
                        Item {
                            id: hoursRoom

                            readonly property int column: 62
                            readonly property var shown: WeatherService.ahead
                                .slice(0, Math.max(0, Math.floor(hoursRoom.width / hoursRoom.column)))

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                Repeater {
                                    model: hoursRoom.shown

                                    Column {
                                        required property var modelData
                                        required property int index

                                        width: hoursRoom.column
                                        spacing: 2

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: WeatherService.blockLabel(modelData, index, hoursRoom.shown)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeLabel
                                            color: Theme.textMuted
                                        }

                                        WeatherIcon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            name: modelData.icon
                                            glyph: modelData.glyph
                                            size: 26
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: `${modelData.temperature}°`
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.text
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Only while Claude is on the bar, where its module keeps the
                // service running; the card never starts it.
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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
    // The updates, as two lists in two colours with their own buttons, and
    // this machine as a fastfetch with the distribution's logo.

    Component {
        id: system

        RowLayout {
            spacing: 12

            Component.onCompleted: {
                UpdatesService.subscribe()
                MachineService.refresh()
                // Which AUR helper there is, so the update button uses it.
                if (!PackagesService.loaded)
                    PackagesService.load()
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
                        : UpdatesService.checkedAt > 0
                            ? `${Tr.t("Checked")} ${UpdatesService.age}${UpdatesService.every !== "" ? " · " + Tr.t(UpdatesService.every).toLowerCase() : ""}`
                            : Tr.t("Not checked yet")
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
                                id: group

                                required property var modelData

                                width: lists.width
                                visible: modelData.entries.length > 0
                                spacing: 2

                                Text {
                                    height: 26
                                    verticalAlignment: Text.AlignBottom
                                    text: `${group.modelData.glyph}  ${group.modelData.name} · ${group.modelData.entries.length}`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: group.modelData.tint
                                }

                                Repeater {
                                    model: group.modelData.entries

                                    RowLayout {
                                        required property var modelData

                                        width: lists.width
                                        height: 22
                                        spacing: 8

                                        // The source's colour, down the side of each line.
                                        Rectangle {
                                            Layout.preferredWidth: 3
                                            Layout.preferredHeight: 14
                                            radius: 1.5
                                            color: group.modelData.tint
                                        }

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
                                            color: group.modelData.tint
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    spacing: 8

                    PillButton {
                        text: UpdatesService.checking ? Tr.t("Checking…") : Tr.t("Check now")
                        icon: "󰑐"
                        enabled: !UpdatesService.checking
                        onClicked: UpdatesService.refresh()
                    }

                    // The packages panel's own upgrade: the AUR helper if there
                    // is one, else pacman, in a terminal that stays open.
                    PillButton {
                        text: Tr.t("Update in a terminal")
                        icon: "󰆍"
                        active: UpdatesService.count > 0
                        // Once the AUR helper is known, and not while a terminal
                        // from the packages panel is already up.
                        enabled: PackagesService.loaded && !PackagesService.busy
                        onClicked: {
                            root.closed()
                            PackagesService.upgrade()
                        }
                    }
                }
            }

            // This machine as a fastfetch: the logo, who and where, then one
            // fact to a line, each in its own colour.
            DashCard {
                id: machineCard

                readonly property var disk: StatsService.disks.find(entry => entry.target === "/")
                readonly property var tints: [Theme.accent, Theme.indicatorTimer, Theme.indicatorGood,
                                              Theme.indicatorWarn, Theme.indicatorBad]
                readonly property var facts: [
                    { glyph: "󰌢", key: Tr.t("Host"), value: MachineService.model },
                    { glyph: "󰒓", key: Tr.t("Kernel"), value: MachineService.kernel },
                    { glyph: "󰅐", key: Tr.t("Uptime"), value: StatsService.uptime > 0 ? StatsService.duration(StatsService.uptime) : "" },
                    { glyph: "󰏖", key: Tr.t("Packages"), value: MachineService.packages !== null ? String(MachineService.packages) : "" },
                    { glyph: "󰆍", key: Tr.t("Shell"), value: MachineService.shell },
                    { glyph: "󱂬", key: Tr.t("WM"), value: MachineService.wm },
                    { glyph: "󰻠", key: Tr.t("CPU"), value: StatsService.cpuModel }
                ].concat(MachineService.gpus.map((name, index) =>
                    ({ glyph: "󰢮", key: MachineService.gpus.length > 1 ? `${Tr.t("GPU")} ${index + 1}` : Tr.t("GPU"), value: name })))
                 .concat([
                    { glyph: "󰍛", key: Tr.t("Memory"), value: StatsService.memoryTotal > 0
                        ? `${StatsService.bytes(StatsService.memoryUsed)} / ${StatsService.bytes(StatsService.memoryTotal)}` : "" },
                    { glyph: "󰋊", key: Tr.t("Disk") + " (/)", value: machineCard.disk
                        ? `${StatsService.bytes(machineCard.disk.used)} / ${StatsService.bytes(machineCard.disk.total)}` : "" },
                    { glyph: "󰁹", key: Tr.t("Battery"), value: BatteryService.available ? `${BatteryService.percent} %` : "" },
                    { glyph: "󰩟", key: Tr.t("Address"), value: SystemMonitorService.addresses
                        .map(entry => entry.address.split("/")[0]).join(", ") }
                ]).filter(fact => fact.value)

                title: Tr.t("This machine")
                Layout.preferredWidth: 380
                Layout.fillHeight: true

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 52

                        Image {
                            id: logoImage

                            anchors.fill: parent
                            source: MachineService.logo !== "" ? `file://${MachineService.logo}` : ""
                            sourceSize.width: 104
                            sourceSize.height: 104
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        // Without a logo file, the Arch mark.
                        Text {
                            anchors.centerIn: parent
                            visible: !logoImage.visible
                            text: "󰣇"
                            font.family: Theme.fontMono
                            font.pixelSize: 40
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.StyledText
                            text: `<font color="${Theme.accent}">${AccountService.user}</font>@<font color="${Theme.indicatorGood}">${MachineService.host}</font>`
                            elide: Text.ElideRight
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeRegular
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            Layout.fillWidth: true
                            text: MachineService.os
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }
                }

                Repeater {
                    model: machineCard.facts

                    RowLayout {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 24
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.glyph
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: machineCard.tints[index % machineCard.tints.length]
                        }

                        Text {
                            Layout.preferredWidth: 66
                            text: modelData.key
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: machineCard.tints[index % machineCard.tints.length]
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

        GridLayout {
            columns: 3
            rows: 2
            columnSpacing: 12
            rowSpacing: 12

            DashCard {
                title: WeatherService.place !== "" ? `Now · ${WeatherService.place}, ${WeatherService.region}` : "Now"
                corner: [
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: WeatherService.refreshing ? Tr.t("Syncing…")
                            : WeatherService.available
                                ? `${Tr.t("Read")} ${WeatherService.age} · ${Tr.t(SettingsService.periodLabel(SettingsService.weatherRefreshMinutes)).toLowerCase()}`
                                : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    },
                    PillButton {
                        text: Tr.t("Sync now")
                        icon: "󰑐"
                        enabled: !WeatherService.refreshing
                        onClicked: WeatherService.refresh()
                    }
                ]
                Layout.row: 0
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 196

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 18

                    // The sky, the temperature, the conditions. A layout in a
                    // layout fills by default; this one keeps its width so the
                    // facts get the rest.
                    ColumnLayout {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 200
                        spacing: 2

                        RowLayout {
                            spacing: 12

                            WeatherIcon {
                                name: WeatherService.icon
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
                            text: WeatherService.available ? WeatherService.description : "No weather"
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeRegular
                            color: Theme.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: WeatherService.available
                            text: `${WeatherService.low}° low · ${WeatherService.high}° high`
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }

                    // The facts, four by two.
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 4
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: [
                                { glyph: "󰔏", key: "Feels", value: `${WeatherService.feelsLike}°` },
                                { glyph: "󰖎", key: "Humidity", value: `${WeatherService.humidity} %` },
                                { glyph: "󰖝", key: "Wind", value: `${WeatherService.wind} ${WeatherService.windUnit}` },
                                { glyph: "󰖙", key: "UV", value: `${WeatherService.uv}` },
                                { glyph: "󰖐", key: "Clouds", value: `${WeatherService.cloud} %` },
                                { glyph: "󰈈", key: "Visibility", value: `${WeatherService.visibility} ${WeatherService.visibilityUnit}` },
                                { glyph: "󰖜", key: "Sunrise", value: WeatherService.sunrise },
                                { glyph: "󰖛", key: "Sunset", value: WeatherService.sunset }
                            ]

                            Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radiusLarge
                                color: Theme.islandSurfaceHover

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

            // The days, down both rows.
            DashCard {
                title: "Days"
                Layout.row: 0
                Layout.column: 2
                Layout.rowSpan: 2
                Layout.preferredWidth: 300
                Layout.fillHeight: true

                Repeater {
                    model: WeatherService.days

                    Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusLarge
                        color: Theme.islandSurfaceHover

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: Qt.formatDate(new Date(modelData.date + "T12:00:00"), "dddd")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeRegular
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }

                                Text {
                                    text: `󰖗 ${modelData.rain} %`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.textMuted
                                }
                            }

                            WeatherIcon {
                                name: modelData.icon ?? ""
                                size: 40
                            }

                            Text {
                                text: `${modelData.low}° / ${modelData.high}°`
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

            DashCard {
                title: "Next hours"
                Layout.row: 1
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 128

                RowLayout {
                    Layout.fillWidth: true

                    Repeater {
                        model: WeatherService.upcoming.slice(0, 8)

                        ColumnLayout {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: WeatherService.blockLabel(modelData, index, WeatherService.upcoming)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: Theme.textMuted
                            }

                            WeatherIcon {
                                Layout.alignment: Qt.AlignHCenter
                                name: modelData.icon
                                size: 28
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: `${modelData.temperature}° · ${modelData.rain}%`
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: Theme.text
                            }
                        }
                    }
                }
            }
        }
    }
}
