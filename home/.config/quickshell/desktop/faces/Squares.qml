// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S   Q   U   A   R   E   S                                              │
// │   2×2 widget faces                                                       │
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

// Registry of 2×2 faces. Each is a WidgetFace: the module's bar mark, its main
// value and a caption. Faces read the same services as the bar modules and
// never reach into the modules themselves. Adding one is a Component here and a
// family in the catalogue.
Item {
    id: root

    property string moduleId: ""

    // Colours resolved by the widget. Faces read this rather than `Theme`.
    property var ink: DesktopService.inkFor(null)

    // The desktop row, for faces that draw what it names (a note).
    property var row: null

    readonly property var components: ({
        battery: batterySquare,
        volume: volumeSquare,
        brightness: brightnessSquare,
        network: networkSquare,
        bluetooth: bluetoothSquare,
        updates: updatesSquare,
        weather: weatherSquare,
        github: githubSquare,
        screentime: screenTimeSquare,
        markets: marketsSquare,
        stats: statsSquare,
        claude: claudeSquare,
        codex: codexSquare,
        timer: timerSquare,
        pet: petSquare,
        games: gamesSquare,
        media: mediaSquare,
        clock: clockSquare,
        calendar: calendarSquare,
        notes: notesSquare,
        tasks: tasksSquare,
        photo: photoSquare
    })

    Loader {
        anchors.fill: parent
        sourceComponent: root.components[root.moduleId] ?? null
    }

    // ── READINGS ────────────────────────────────────────────────────────────

    Component {
        id: batterySquare

        WidgetFace {

            ink: root.ink
            // Every face shows something when there is no data: widgets are
            // always drawn.
            label: Tr.t("Battery")
            reading: BatteryService.available ? `${BatteryService.percent}%` : "—"
            note: BatteryService.available ? BatteryService.estimate : Tr.t("no battery")

            BatteryWidget { size: 40; glyphColor: root.ink.text; track: root.ink.dim }
        }
    }

    Component {
        id: volumeSquare

        WidgetFace {

            ink: root.ink
            label: Tr.t("Volume")
            reading: AudioService.muted ? Tr.t("Muted") : `${AudioService.volume}%`
            tint: AudioService.muted ? root.ink.muted : root.ink.text

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
        }
    }

    Component {
        id: brightnessSquare

        WidgetFace {

            ink: root.ink
            label: Tr.t("Brightness")
            reading: BrightnessService.available ? `${BrightnessService.percent}%` : "—"
            note: BrightnessService.available ? "" : Tr.t("no backlight")

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
        }
    }

    Component {
        id: networkSquare

        WidgetFace {

            ink: root.ink
            label: Tr.t("Network")
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

    Component {
        id: bluetoothSquare

        WidgetFace {

            ink: root.ink
            label: "Bluetooth"
            reading: BluetoothService.summary

            Text {
                anchors.centerIn: parent
                text: BluetoothService.icon
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: BluetoothService.enabled ? root.ink.text : root.ink.muted
            }
        }
    }

    Component {
        id: updatesSquare

        WidgetFace {

            ink: root.ink
            label: Tr.t("Updates")
            reading: UpdatesService.available || UpdatesService.checking
                ? `${UpdatesService.count}` : "—"
            note: UpdatesService.checking
                ? Tr.t("checking")
                : (!UpdatesService.available ? Tr.t("cannot check")
                    : (UpdatesService.count === 0 ? Tr.t("up to date") : Tr.t("pending")))
            tint: UpdatesService.count === 0 ? root.ink.muted : root.ink.text

            Text {
                anchors.centerIn: parent
                text: "󰏖"
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: UpdatesService.count === 0 ? root.ink.muted : root.ink.text
            }
        }
    }

    Component {
        id: weatherSquare

        WidgetFace {

            ink: root.ink
            label: WeatherService.place || Tr.t("Weather")
            reading: WeatherService.available ? `${WeatherService.temperature}°` : "--°"
            note: WeatherService.available ? WeatherService.description : Tr.t("no forecast")

            Text {
                anchors.centerIn: parent
                text: WeatherService.available ? WeatherService.glyph : "󰅤"
                font.family: Theme.fontMono
                font.pixelSize: 34
                color: root.ink.text
            }
        }
    }

    Component {
        id: statsSquare

        WidgetFace {

            ink: root.ink
            label: Tr.t("System")
            reading: `${StatsService.cpu.toFixed(0)}%`
            note: `RAM ${Math.round(StatsService.memoryFraction * 100)}%`

            Text {
                anchors.centerIn: parent
                text: "󰻠"
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: root.ink.text
            }
        }
    }

    Component {
        id: claudeSquare

        WidgetFace {

            ink: root.ink
            label: "Claude"
            reading: !ClaudeService.available ? "—"
                : ClaudeService.sessionMeasured
                ? ClaudeService.percent(ClaudeService.sessionFraction)
                : ClaudeService.compact(ClaudeService.blockTokens)
            note: !ClaudeService.available ? Tr.t("no usage found")
                : (ClaudeService.sessionMeasured ? Tr.t("of this block") : Tr.t("this block"))

            ClaudeMark {
                anchors.centerIn: parent
                width: 32
                height: 32
                color: root.ink.text
            }
        }
    }

    Component {
        id: codexSquare

        WidgetFace {

            ink: root.ink
            label: "Codex"
            reading: CodexService.figure
            note: !CodexService.available ? Tr.t("no usage found")
                : CodexService.fullest ? Tr.t("of the %1").arg(CodexService.fullestName)
                : Tr.t("until Codex runs again")

            CodexMark {
                anchors.centerIn: parent
                width: 32
                height: 32
                color: root.ink.text
            }
        }
    }

    Component {
        id: timerSquare

        WidgetFace {

            ink: root.ink
            label: Tr.t("Timer")
            reading: TimerService.running ? TimerService.display : "—"
            note: TimerService.running
                ? (TimerService.label !== "" ? TimerService.label : Tr.t("counting down"))
                : Tr.t("nothing running")
            tint: TimerService.running ? root.ink.text : root.ink.muted

            RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: TimerService.progress
                trackColor: root.ink.dim
                fillColor: Theme.indicatorTimer
            }
        }
    }

    Component {
        id: gamesSquare

        WidgetFace {

            ink: root.ink
            readonly property var last: GamesService.entry(GamesService.lastPlayed)

            label: Tr.t("Games")
            reading: last ? `${GamesService.bestOf(last.id)}` : "—"
            note: last ? `${last.name} · ${Tr.t("best")}` : Tr.t("Nothing played yet")

            RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: 0
                trackColor: root.ink.dim

                Text {
                    anchors.centerIn: parent
                    text: "󰊗"
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: root.ink.text
                }
            }
        }
    }

    Component {
        id: petSquare

        WidgetFace {

            ink: root.ink
            label: PetService.name !== "" ? PetService.name : Tr.t("Pet")
            reading: PetService.hatched ? Tr.t("Lv %1").arg(PetService.level) : Tr.t("Egg")
            note: PetService.mood

            RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: PetService.progress
                trackColor: root.ink.dim
                fillColor: root.ink.text

                PetFace {
                    anchors.centerIn: parent
                    size: 26
                    lively: true
                }
            }
        }
    }

    // ── OTHER FACES ────────────────────────────────────────────────────────

    // The album art as the mark, at mark size; the 4×4 face has room for the
    // full art.
    Component {
        id: mediaSquare

        WidgetFace {

            ink: root.ink
            // Without a player it says so rather than going blank.
            label: MediaService.artist !== "" ? MediaService.artist : Tr.t("Media")
            reading: MediaService.title !== "" ? MediaService.title
                : (MediaService.available ? MediaService.identity : Tr.t("Nothing playing"))
            note: !MediaService.available ? Tr.t("no player")
                : (MediaService.playing ? Tr.t("playing") : Tr.t("paused"))

            ClippingRectangle {
                anchors.fill: parent
                radius: width * Theme.pictureCorner
                // None behind a picture: a player may send its logo on transparency.
                color: squareArt.visible ? "transparent" : root.ink.raised

                Image {
                    id: squareArt

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
        }
    }

    Component {
        id: clockSquare

        WidgetFace {

            ink: root.ink
            id: clockFace

            readonly property string format: SettingsService.clockShowsSeconds
                ? SettingsService.clockFormat.replace("mm", "mm:ss")
                : SettingsService.clockFormat

            label: Qt.formatDateTime(clock.date, "ddd")
            reading: Qt.formatDateTime(clock.date, clockFace.format)
            note: Qt.formatDateTime(clock.date, "d MMMM")

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

    // The date; the month is the 4×4 face. The square is today, so pressing it
    // with tasks shows today's list, as a pressed day does on the larger faces.
    // The square returns via the arrow or when the pointer leaves.
    Component {
        id: calendarSquare

        Item {
            id: leaf

            property bool open: false

            HoverHandler {
                onHoveredChanged: {
                    if (!hovered)
                        leaf.open = false
                }
            }

            WidgetFace {

                ink: root.ink
                id: calendarFace

                anchors.fill: parent
                opacity: leaf.open ? 0 : 1
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                readonly property date today: calendarClock.date

                label: Qt.formatDateTime(calendarClock.date, "MMMM")
                reading: `${calendarFace.today.getDate()}`
                // The weekday, and how much of today is left when there are
                // tasks.
                note: {
                    const weekday = Qt.formatDateTime(calendarClock.date, "dddd")
                    const left = TasksService.pendingOn(TasksService.todayKey)
                    return left > 0 ? `${weekday} · ${Tr.t("%1 to do").arg(left)}` : weekday
                }

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

                HoverHandler {
                    enabled: TasksService.countOn(TasksService.todayKey) > 0
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: TasksService.countOn(TasksService.todayKey) > 0
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: leaf.open = true
                }
            }

            DayTasks {
                anchors.fill: parent
                anchors.margins: 16
                day: leaf.open ? TasksService.todayKey : ""
                opacity: leaf.open ? 1 : 0
                visible: opacity > 0
                ink: ({
                    text: root.ink.text, muted: root.ink.muted, accent: root.ink.accent,
                    accentText: root.ink.accentText, raised: root.ink.raised,
                    red: Theme.red, rule: root.ink.dim
                })
                onBack: leaf.open = false

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }
        }
    }

    // Notes use one face for all four families.
    Component {
        id: notesSquare

        NoteFace { ink: root.ink; row: root.row; family: "2x2" }
    }

    // A picture of your own, one face for all four families; see `PhotoFace`.
    Component {
        id: photoSquare

        PhotoFace { ink: root.ink; row: root.row; family: "2x2" }
    }

    // The contribution wall, one face for all four families.
    Component {
        id: githubSquare

        GithubFace { ink: root.ink; family: "2x2" }
    }

    // Tasks left, and one line: overdue, else due today, else the next one.
    Component {
        id: tasksSquare

        WidgetFace {

            ink: root.ink
            label: Tr.t("Tasks")
            reading: `${TasksService.pending}`
            note: TasksService.pending === 0
                ? (TasksService.count === 0 ? Tr.t("nothing yet") : Tr.t("all done"))
                : TasksService.summary
            tint: TasksService.overdue.length > 0 ? Theme.red : root.ink.text

            Text {
                anchors.centerIn: parent
                text: "󰄲"
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: root.ink.text
            }
        }
    }

    // The first pair's price, short, and its change.
    Component {
        id: marketsSquare

        WidgetFace {

            ink: root.ink
            label: MarketsService.lead ? `${MarketsService.lead.base}/${MarketsService.lead.quote}` : Tr.t("Markets")
            note: !MarketsService.lead
                ? (MarketsService.pairs.length === 0 ? Tr.t("nothing on the list") : Tr.t("no prices")
)
                : `${MarketsService.change(MarketsService.lead)} · ${MarketsService.lead.period}`
            noteTint: MarketsService.lead ? MarketsService.tint(MarketsService.lead) : root.ink.muted

            Text {
                anchors.centerIn: parent
                text: MarketsService.glyph(MarketsService.lead)
                font.family: Theme.fontMono
                font.pixelSize: 34
                color: root.ink.text
            }
            reading: MarketsService.short(MarketsService.lead)
        }
    }

    // Today's total, the ring split by group, and the most used under it.
    Component {
        id: screenTimeSquare

        WidgetFace {
            ink: root.ink
            label: Tr.t("Screen time")
            reading: ScreenTimeService.duration(ScreenTimeService.todayTotal)
            note: ScreenTimeService.todayNote

            UsageRing {
                anchors.fill: parent
                anchors.margins: 4
                parts: ScreenTimeService.todayParts
                thickness: 5
                accent: root.ink.accent
                ink: root.ink.text
            }
        }
    }
}
