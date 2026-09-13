// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W   I   D   E   S                                                      │
// │   4×2 widget faces                                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"
import "../../bar/widgets"
import "../../bar/modules"

// 4×2 faces: the 2×2 grid with the right half filled in. The mark, label,
// reading and caption stay where they are on the square; whatever the square
// had no room for goes on the right. Faces read services, not modules. Modules
// with no row here fall back to their island detail.
Item {
    id: root

    property string moduleId: ""

    // Colours resolved by the widget. Faces read this rather than `Theme`.
    property var ink: DesktopService.inkFor(null)

    // The desktop row, for faces that draw what it names (a note).
    property var row: null

    readonly property var components: ({
        battery: batteryWide,
        volume: volumeWide,
        brightness: brightnessWide,
        network: networkWide,
        bluetooth: bluetoothWide,
        updates: updatesWide,
        weather: weatherWide,
        github: githubWide,
        stats: statsWide,
        claude: claudeWide,
        timer: timerWide,
        pet: petWide,
        media: mediaWide,
        clock: clockWide,
        calendar: calendarWide,
        notes: notesWide,
        tasks: tasksWide,
        photo: photoWide
    })

    Loader {
        anchors.fill: parent
        active: root.components[root.moduleId] !== undefined
        sourceComponent: root.components[root.moduleId] ?? null
    }

    // Fallback: the island detail at its catalogue size, centred. The grid's
    // cell size was chosen to fit it, so a new module works on the desktop
    // before it has a face of its own.
    //
    // Sized from the catalogue rather than filling the widget: a Loader resizes
    // what it loads, and the detail would lay out against the wrong edges.
    Loader {
        anchors.centerIn: parent
        active: root.components[root.moduleId] === undefined
        sourceComponent: detail
    }

    Component {
        id: detail

        Item {
            readonly property var entry: ModuleService.entry(root.moduleId)

            implicitWidth: entry.width
            implicitHeight: entry.height
            width: implicitWidth
            height: implicitHeight

            Module {
                anchors.fill: parent
                moduleId: root.moduleId
                compact: false
            }
        }
    }

    // ── GAUGES ──────────────────────────────────────────────────────────────
    //
    // Percentages are repeated as a bar on the right, which shows at a glance
    // whether the value is high or low.

    Component {
        id: batteryWide

        WidgetFace {

            ink: root.ink
            label: "Battery"
            reading: BatteryService.available ? `${BatteryService.percent}%` : "—"
            note: BatteryService.available ? BatteryService.estimate : "no battery"
            extraShare: 0.42

            BatteryWidget { size: 40; glyphColor: root.ink.text; track: root.ink.dim }

            extra: [
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 8

                    UsageBar {

                        trackColor: root.ink.raised
                        width: parent.width
                        progress: BatteryService.percent / 100
                        fillColor: BatteryService.tint
                    }

                    Text {
                        width: parent.width
                        text: !BatteryService.available ? ""
                            : BatteryService.watts > 0
                            ? `${BatteryService.watts.toFixed(1)} W · ${BatteryService.energy.toFixed(1)} Wh`
                            : `${BatteryService.energy.toFixed(1)} Wh`
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.ink.muted
                    }
                }
            ]
        }
    }

    Component {
        id: volumeWide

        WidgetFace {

            ink: root.ink
            label: "Volume"
            reading: AudioService.muted ? "Muted" : `${AudioService.volume}%`
            note: AudioService.muted ? "output silenced" : "output"
            tint: AudioService.muted ? root.ink.muted : root.ink.text
            extraShare: 0.42

            RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: AudioService.muted ? 0 : AudioService.volume / 100
                trackColor: root.ink.dim
                fillColor: root.ink.text

                Text {
                    anchors.centerIn: parent
                    text: AudioService.icon
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                    color: AudioService.muted ? root.ink.muted : root.ink.text
                }
            }

            extra: [
                UsageBar {
                    trackColor: root.ink.raised
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    progress: AudioService.muted ? 0 : AudioService.volume / 100
                    fillColor: root.ink.text
                }
            ]
        }
    }

    Component {
        id: brightnessWide

        WidgetFace {

            ink: root.ink
            label: "Brightness"
            reading: BrightnessService.available ? `${BrightnessService.percent}%` : "—"
            note: BrightnessService.available ? "backlight" : "no backlight"
            extraShare: 0.42

            RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: BrightnessService.percent / 100
                trackColor: root.ink.dim
                fillColor: root.ink.text

                Text {
                    anchors.centerIn: parent
                    text: BrightnessService.icon
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                    color: root.ink.text
                }
            }

            extra: [
                UsageBar {
                    trackColor: root.ink.raised
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    progress: BrightnessService.percent / 100
                    fillColor: root.ink.text
                }
            ]
        }
    }

    Component {
        id: claudeWide

        WidgetFace {

            ink: root.ink
            label: "Claude"
            reading: !ClaudeService.available ? "—"
                : ClaudeService.sessionMeasured
                ? ClaudeService.percent(ClaudeService.sessionFraction)
                : ClaudeService.compact(ClaudeService.blockTokens)
            note: !ClaudeService.available ? "no usage found"
                : ClaudeService.sessionMeasured
                ? `of this block · ${ClaudeService.compact(ClaudeService.blockTokens)}`
                : `this block · ${ClaudeService.messages(ClaudeService.blockMessages)}`
            extraShare: 0.42

            ClaudeMark {
                anchors.centerIn: parent
                width: 32
                height: 32
                color: ClaudeService.tint
            }

            extra: [
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 8
                    visible: ClaudeService.available

                    UsageBar {

                        trackColor: root.ink.raised
                        width: parent.width
                        progress: ClaudeService.gauge
                        fillColor: ClaudeService.tint
                    }

                    Text {
                        width: parent.width
                        text: ClaudeService.resetsIn
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.ink.muted
                    }
                }
            ]
        }
    }

    // ── DETAILS ─────────────────────────────────────────────────────────────

    Component {
        id: statsWide

        WidgetFace {

            ink: root.ink
            label: "System"
            reading: `${StatsService.cpu.toFixed(0)}%`
            note: `RAM ${Math.round(StatsService.memoryFraction * 100)}% · load ${StatsService.load[0].toFixed(2)}`
            extraShare: 0.45

            Text {
                anchors.centerIn: parent
                text: "󰻠"
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: root.ink.text
            }

            extra: [
                Sparkline {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 48
                    values: StatsService.cpuHistory
                    stroke: root.ink.accent
                }
            ]
        }
    }

    Component {
        id: weatherWide

        WidgetFace {

            ink: root.ink
            id: weather

            readonly property var hoursAhead: {
                const hour = WeatherService.clock.date.getHours()
                return (WeatherService.available ? (WeatherService.hourly ?? []) : [])
                    .filter(block => block.tomorrow || block.hour > hour)
                    .slice(0, 3)
            }

            label: WeatherService.place || "Weather"
            reading: WeatherService.available ? `${WeatherService.temperature}°` : "--°"
            note: !WeatherService.available ? "no forecast"
                : WeatherService.description !== ""
                ? `${WeatherService.description} · ${WeatherService.high}° / ${WeatherService.low}°`
                : `${WeatherService.high}° / ${WeatherService.low}°`
            extraShare: 0.45

            Text {
                anchors.centerIn: parent
                text: WeatherService.available ? WeatherService.glyph : "󰅤"
                font.family: Theme.fontMono
                font.pixelSize: 34
                color: root.ink.text
            }

            extra: [
                Row {
                    anchors.fill: parent

                    Repeater {
                        model: weather.hoursAhead

                        Item {
                            id: block

                            required property var modelData

                            width: parent.width / Math.max(1, weather.hoursAhead.length)
                            height: parent.height

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        const hour = `${block.modelData.hour}`.padStart(2, "0")
                                        return block.modelData.tomorrow
                                            ? `${hour}⁺` : `${hour}h`
                                    }
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    color: root.ink.muted
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: block.modelData.glyph
                                    font.family: Theme.fontMono
                                    font.pixelSize: 20
                                    color: root.ink.text
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: `${block.modelData.temperature}°`
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: root.ink.text
                                }
                            }
                        }
                    }
                }
            ]
        }
    }

    Component {
        id: updatesWide

        WidgetFace {

            ink: root.ink
            label: "Updates"
            reading: UpdatesService.available || UpdatesService.checking
                ? `${UpdatesService.count}` : "—"
            note: UpdatesService.checking
                ? "checking"
                : (!UpdatesService.available ? "cannot check"
                    : (UpdatesService.count === 0 ? "up to date" : "pending"))
            tint: UpdatesService.count === 0 ? root.ink.muted : root.ink.text
            extraShare: 0.45

            Text {
                anchors.centerIn: parent
                text: "󰏖"
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: UpdatesService.count === 0 ? root.ink.muted : root.ink.text
            }

            extra: [
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: UpdatesService.available ? UpdatesService.packages.slice(0, 4) : []

                        Text {
                            required property var modelData

                            width: parent.width
                            text: modelData
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: root.ink.muted
                        }
                    }
                }
            ]
        }
    }

    Component {
        id: bluetoothWide

        WidgetFace {

            ink: root.ink
            label: "Bluetooth"
            reading: BluetoothService.summary
            note: !BluetoothService.available ? "no adapter"
                : (BluetoothService.enabled ? "adapter on" : "adapter off")
            extraShare: 0.42

            Text {
                anchors.centerIn: parent
                text: BluetoothService.icon
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: BluetoothService.enabled ? root.ink.text : root.ink.muted
            }

            extra: [
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 3

                    Repeater {
                        model: BluetoothService.connectedDevices.slice(0, 3)

                        Text {
                            required property var modelData

                            width: parent.width
                            text: modelData.name
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: root.ink.muted
                        }
                    }
                }
            ]
        }
    }

    // The name and the state are the whole content, so they take the full
    // width.
    Component {
        id: networkWide

        WidgetFace {

            ink: root.ink
            label: "Network"
            reading: NetworkService.connectionName
            note: NetworkService.stateLine

            Text {
                anchors.centerIn: parent
                text: NetworkService.icon
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: NetworkService.online ? root.ink.text : root.ink.muted
            }
        }
    }

    // ── CONTROLS ────────────────────────────────────────────────────────────
    //
    // The controls go in the extra area, so these stay on the same grid as the
    // rest.

    Component {
        id: timerWide

        WidgetFace {

            ink: root.ink
            label: "Timer"
            reading: TimerService.running ? TimerService.display : "—"
            note: TimerService.running
                ? (TimerService.label !== "" ? TimerService.label : "counting down")
                : "nothing running"
            tint: TimerService.running ? root.ink.text : root.ink.muted
            extraShare: 0.4

            RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: TimerService.progress
                trackColor: root.ink.dim
                fillColor: Theme.indicatorTimer
            }

            extra: [
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    spacing: 10

                    PillButton {
                        text: TimerService.running
                            ? (TimerService.paused ? "Resume" : "Hold") : "5 min"
                        implicitHeight: 30
                        // Milliseconds: the service counts in Timer units.
                        onClicked: {
                            if (!TimerService.running)
                                TimerService.start(5 * 60 * 1000, "")
                            else
                                TimerService.toggle()
                        }
                    }

                    IconButton {

                        iconColor: root.ink.text
                        icon: "󰅖"
                        iconSize: 13
                        enabled: TimerService.running
                        opacity: TimerService.running ? 1 : 0.35
                        onClicked: TimerService.cancel()
                    }
                }
            ]
        }
    }

    Component {
        id: mediaWide

        WidgetFace {

            ink: root.ink
            label: MediaService.artist !== "" ? MediaService.artist : "Media"
            reading: MediaService.title !== "" ? MediaService.title
                : (MediaService.available ? MediaService.identity : "Nothing playing")
            note: !MediaService.available ? "no player"
                : (MediaService.playing ? "playing" : "paused")
            extraShare: 0.4

            ClippingRectangle {
                anchors.fill: parent
                radius: width * Theme.pictureCorner
                color: root.ink.raised

                Image {
                    anchors.fill: parent
                    source: MediaService.artUrl
                    visible: source != "" && status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 80
                    sourceSize.height: 80
                }

                Text {
                    anchors.centerIn: parent
                    visible: MediaService.artUrl === ""
                    text: "󰎇"
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: root.ink.muted
                }
            }

            extra: [
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    spacing: 16
                    enabled: MediaService.available
                    opacity: MediaService.available ? 1 : 0.4

                    IconButton {

                        iconColor: root.ink.text
                        icon: "󰒮"
                        iconSize: 16
                        onClicked: MediaService.previous()
                    }

                    IconButton {

                        iconColor: root.ink.text
                        icon: MediaService.playing ? "󰏤" : "󰐊"
                        iconSize: 18
                        onClicked: MediaService.toggle()
                    }

                    IconButton {

                        iconColor: root.ink.text
                        icon: "󰒭"
                        iconSize: 16
                        onClicked: MediaService.next()
                    }
                }
            ]
        }
    }

    Component {
        id: petWide

        WidgetFace {

            ink: root.ink
            label: PetService.name !== "" ? PetService.name : "Pet"
            reading: PetService.hatched ? `Lv ${PetService.level}` : "Egg"
            note: PetService.moodLine
            extraShare: 0.4

            RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: PetService.progress
                trackColor: root.ink.dim
                fillColor: root.ink.text
            }

            extra: [
                PetFace {
                    anchors.centerIn: parent
                    size: 56
                    lively: true
                }
            ]
        }
    }

    // ── TIME ────────────────────────────────────────────────────────────────

    Component {
        id: clockWide

        WidgetFace {

            ink: root.ink
            id: clockFace

            readonly property string format: SettingsService.clockShowsSeconds
                ? SettingsService.clockFormat.replace("mm", "mm:ss")
                : SettingsService.clockFormat

            label: Qt.formatDateTime(clock.date, "dddd")
            reading: Qt.formatDateTime(clock.date, clockFace.format)
            note: Qt.formatDateTime(clock.date, "d MMMM yyyy")

            SystemClock {
                id: clock
                precision: SettingsService.clockShowsSeconds
                    ? SystemClock.Seconds : SystemClock.Minutes
            }

            Text {
                anchors.centerIn: parent
                text: "󰥔"
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: root.ink.text
            }
        }
    }

    // The week around today; the month is the 4×4 face.
    Component {
        id: calendarWide

        Item {
            id: week

            // Pressing a day with tasks shows that day's list, as on the 4×4.
            // The week returns via the arrow or when the pointer leaves.
            property string picked: ""

            HoverHandler {
                onHoveredChanged: {
                    if (!hovered)
                        week.picked = ""
                }
            }

            WidgetFace {

                ink: root.ink
                id: calendarFace

                anchors.fill: parent
                opacity: week.picked === "" ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                readonly property date today: calendarClock.date

                // The same label and reading as the square, so the wide face
                // adds the week without rearranging anything.
                label: Qt.formatDateTime(calendarClock.date, "MMMM")
                reading: `${calendarFace.today.getDate()}`
                // Today's count if any; else the next task due; else the
                // weekday.
                note: {
                    const left = TasksService.pendingOn(TasksService.todayKey)
                    if (left > 0)
                        return `${left} to do today`
                    const next = TasksService.next
                    if (next)
                        return `${next.text} · ${TasksService.dueLabel(next.due)}`
                    return Qt.formatDateTime(calendarClock.date, "dddd")
                }
                extraShare: 0.5

                SystemClock {
                    id: calendarClock
                    precision: SystemClock.Minutes
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰃭"
                    font.family: Theme.fontMono
                    font.pixelSize: 30
                    color: root.ink.text
                }

                extra: [
                    Row {
                        anchors.fill: parent

                        Repeater {
                            model: 7

                            Item {
                                id: day

                                required property int index

                                // Monday first, the way the month is laid out.
                                readonly property date date: {
                                    const base = new Date(calendarFace.today)
                                    const shift = (base.getDay() + 6) % 7
                                    base.setDate(base.getDate() - shift + day.index)
                                    return base
                                }

                                readonly property bool today:
                                    day.date.getDate() === calendarFace.today.getDate()
                                    && day.date.getMonth() === calendarFace.today.getMonth()

                                readonly property string key: TasksService.dayKey(day.date)
                                readonly property int tasks: TasksService.countOn(day.key)
                                readonly property int pending: TasksService.pendingOn(day.key)

                                width: parent.width / 7
                                height: parent.height

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Qt.formatDateTime(day.date, "ddd").charAt(0)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel
                                        color: root.ink.muted
                                    }

                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: day.today ? root.ink.accent : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: day.tasks > 0 ? -1 : 0
                                            text: `${day.date.getDate()}`
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: day.today ? Font.DemiBold : Font.Normal
                                            color: day.today ? root.ink.accentText : root.ink.text
                                        }

                                        // A task due that day: the accent while
                                        // any is open, muted once done.
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 2
                                            visible: day.tasks > 0
                                            width: 3
                                            height: 3
                                            radius: 1.5
                                            color: day.today ? root.ink.accentText
                                                : (day.pending > 0 ? root.ink.accent : root.ink.muted)
                                        }
                                    }
                                }

                                HoverHandler {
                                    enabled: day.tasks > 0
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    enabled: day.tasks > 0
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: week.picked = day.key
                                }
                            }
                        }
                    }
                ]
            }

            DayTasks {
                anchors.fill: parent
                anchors.margins: 18
                day: week.picked
                opacity: week.picked !== "" ? 1 : 0
                visible: opacity > 0
                ink: ({
                    text: root.ink.text, muted: root.ink.muted, accent: root.ink.accent,
                    accentText: root.ink.accentText, raised: root.ink.raised,
                    red: Theme.red, rule: root.ink.dim
                })
                onBack: week.picked = ""

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }
        }
    }

    // The 2×2 plus the next three tasks, with checkboxes.
    Component {
        id: tasksWide

        WidgetFace {

            ink: root.ink
            label: "Tasks"
            reading: `${TasksService.pending}`
            note: TasksService.pending === 0
                ? (TasksService.count === 0 ? "nothing yet" : "all done")
                : TasksService.summary
            tint: TasksService.overdue.length > 0 ? Theme.red : root.ink.text
            extraShare: 0.55

            Text {
                anchors.centerIn: parent
                text: "󰄲"
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: root.ink.text
            }

            extra: [
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: TasksService.queue.slice(0, 3)

                        TaskRow {
                            required property var modelData

                            width: parent.width
                            task: modelData
                            dated: false
                            ink: ({
                                text: root.ink.text, muted: root.ink.muted, accent: root.ink.accent,
                                accentText: root.ink.accentText, raised: root.ink.raised, red: Theme.red
                            })
                            onOpened: {
                                TasksService.open(modelData.key)
                                ModuleService.requestPanel("board")
                            }
                        }
                    }
                }
            ]
        }
    }

    // A note is its text at any size; see `NoteFace`.
    Component {
        id: notesWide

        NoteFace { ink: root.ink; row: root.row; family: "4x2" }
    }

    // A picture of your own; see `PhotoFace`.
    Component {
        id: photoWide

        PhotoFace { ink: root.ink; row: root.row; family: "4x2" }
    }

    // Half a year of the contribution wall; see `GithubFace`.
    Component {
        id: githubWide

        GithubFace { ink: root.ink; family: "4x2" }
    }
}
