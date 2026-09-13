// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O D U L E   S E R V I C E                                            │
// │   module catalogue · activity and open panel state                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQml
import QtQuick
import Quickshell

import "../theme"

// The bar's catalogue: what each module is, its glyph and figure, whether this
// machine can show it, and which detail is open.
//
// A module is a chip on the bar that opens a detail in the island. Detail
// sizes are declared here because the island has to reach that size before
// the detail exists. A button has no detail; it opens one of the panels.
//
// Adding a module: a file in bar/modules, a row in `catalogue` and a line in
// Module.qml. Adding a button: a row in `buttons`.
Singleton {
    id: root

    //   bar      whether it can go on the bar (board, deck and arcade live on
    //            the desktop and behind their panels instead)
    //   desk     false for the one module with no desktop face
    //   width    detail size
    //   height
    //
    // The chip look is global (`SettingsService.chipShape`, `chipFigure`);
    // desktop faces are listed per theme in `DesktopService.faces`.
    readonly property var catalogue: [
        { id: "media",         name: "Media",         bar: true,  width: 380, height: 150 },
        { id: "timer",         name: "Timer",         bar: true,  width: 348, height: 116 },
        { id: "claude",        name: "Claude",        bar: true,  width: 356, height: 150 },
        { id: "battery",       name: "Battery",       bar: true,  width: 320, height: 132 },
        { id: "volume",        name: "Volume",        bar: true,  width: 340, height: 116 },
        { id: "brightness",    name: "Brightness",    bar: true,  width: 340, height: 100 },
        { id: "network",       name: "Network",       bar: true,  width: 356, height: 132 },
        { id: "bluetooth",     name: "Bluetooth",     bar: true,  width: 356, height: 132 },
        { id: "notifications", name: "Notifications", bar: true,  desk: false, width: 380, height: 340 },
        { id: "weather",       name: "Weather",       bar: true,  width: 380, height: 150 },
        { id: "github",        name: "GitHub",        bar: false, width: 380, height: 158 },
        { id: "stats",         name: "System",        bar: true,  width: 380, height: 148 },
        { id: "updates",       name: "Updates",       bar: true,  width: 356, height: 132 },
        { id: "pet",           name: "Pet",           bar: true,  width: 380, height: 172 },
        { id: "games",         name: "Games",         bar: false, width: 380, height: 150 },
        { id: "recorder",      name: "Recorder",      bar: true,  width: 356, height: 150 },
        { id: "calendar",      name: "Calendar",      bar: true,  width: 340, height: 330 },
        { id: "notes",         name: "Notes",         bar: false, width: 356, height: 150 },
        { id: "tasks",         name: "Tasks",         bar: false, width: 356, height: 150 },
        { id: "photo",         name: "Photo",         bar: false, width: 356, height: 150 },
        { id: "clock",         name: "Clock",         bar: false,
          width: SettingsService.clockShowsDate ? 240 : 150, height: Theme.capsuleHeight }
    ]

    function entry(id: string): var {
        return root.catalogue.find(item => item.id === id) ?? root.catalogue[0]
    }

    // ── BUTTONS ─────────────────────────────────────────────────────────────
    //
    // Open one of the island's panels. Same glyphs as the control centre's
    // shortcuts. Alone in a capsule, a button is drawn as a circle.
    readonly property var buttons: ({
        launcher: { name: "Search",         glyph: "󰍉", panel: "launcher" },
        overview: { name: "Overview",       glyph: "󰕰", panel: "overview" },
        controls: { name: "Control centre", glyph: "󰨚", panel: "controls" },
        session:  { name: "Session",        glyph: "󰐥", panel: "session" }
    })

    function isButton(id: string): bool {
        return root.buttons[id] !== undefined
    }

    // Buttons cannot see the island, so they ask here and the bar listens.
    // The bar writes the open panel back to `shownPanel` so a button can stay
    // lit.
    signal panelToggled(string panel)

    function togglePanel(panel: string): void {
        root.panelToggled(panel)
    }

    property string shownPanel: ""

    // ── CHIP SHAPE ──────────────────────────────────────────────────────────
    //
    // Modules with a ring face. A ring is a gauge, so the bell, with nothing
    // to measure, keeps its symbol; on/off links get an empty ring.
    readonly property var ringed: ["media", "timer", "claude", "battery", "volume",
        "brightness", "network", "bluetooth", "weather", "stats", "updates",
        "pet", "recorder"]

    // A piece's own shape when it has one, the bar's when it does not.
    function shapeOf(id: string, own: var): string {
        const chosen = own ? own : SettingsService.chipShape
        return chosen === "ring" && root.ringed.indexOf(id) >= 0 ? "ring" : "icon"
    }

    function figureOf(own: var): string {
        return own ? own : SettingsService.chipFigure
    }

    // ── GLYPH AND FIGURE ────────────────────────────────────────────────────
    //
    // One table for every place a module's symbol and figure appear (bar,
    // glance, settings), in either chip shape. Claude and the pet draw their
    // own mark instead of a glyph (`ChipFace`).
    function glyphOf(id: string): string {
        switch (id) {
        case "network":
            return NetworkService.icon
        case "bluetooth":
            return BluetoothService.icon
        case "volume":
            return AudioService.icon
        case "brightness":
            return BrightnessService.icon
        case "battery":
            return BatteryService.icon
        case "weather":
            return WeatherService.glyph || "󰖐"
        case "updates":
            return "󰏖"
        case "notifications":
            return NotificationService.doNotDisturb ? "󰂛" : "󰂚"
        case "media":
            return "󰎇"
        case "timer":
            return "󰔛"
        case "stats":
            return "󰍛"
        case "calendar":
            return "󰃭"
        case "recorder":
            return RecorderService.recording ? "󰑊" : "󰕧"
        }
        return ""
    }

    // Never empty, so "always show the figure" applies to every module: a
    // connection shows its name, an empty bell "0", an idle countdown "0:00".
    function valueOf(id: string): string {
        switch (id) {
        case "volume":
            return AudioService.muted ? "Muted" : `${AudioService.volume}%`
        case "brightness":
            return `${BrightnessService.percent}%`
        case "battery":
            return `${BatteryService.percent}%`
        case "weather":
            return WeatherService.available ? `${WeatherService.temperature}°` : "--°"
        case "updates":
            return `${UpdatesService.count}`
        case "notifications":
            return `${NotificationService.history.length}`
        case "media":
            return MediaService.available
                ? (MediaService.title || MediaService.identity || "Playing") : "Nothing playing"
        case "timer":
            return TimerService.running ? TimerService.display : "0:00"
        case "claude":
            if (ClaudeService.measured)
                return `${Math.round(ClaudeService.sessionFraction * 100)}%`
            return ClaudeService.blockTokens > 0 ? ClaudeService.compact(ClaudeService.blockTokens) : "0%"
        case "stats":
            return `${StatsService.cpu.toFixed(0)}%`
        case "pet":
            return PetService.hatched ? `Lv ${PetService.level}` : "Egg"
        case "recorder":
            return RecorderService.recording ? RecorderService.display : "REC"
        case "network":
            return NetworkService.connectionName
        case "bluetooth":
            return BluetoothService.summary
        case "calendar":
            return Qt.formatDate(root.today.date, "ddd d")
        }
        return ""
    }

    // For the calendar's figure, which only changes at midnight.
    readonly property SystemClock today: SystemClock {
        precision: SystemClock.Minutes
    }

    // Maximum width for text figures (track title, network or device name)
    // before they are elided.
    function figureLimit(id: string): int {
        switch (id) {
        case "media":
            return 150
        case "network":
        case "bluetooth":
            return 110
        }
        return 0
    }

    // Warnings (low battery, hot CPU, recording) use the fixed indicator
    // hues; everything else is plain text colour.
    function tintOf(id: string): color {
        switch (id) {
        case "battery":
            if (BatteryService.available && !BatteryService.charging && !BatteryService.full) {
                if (BatteryService.percent <= 10)
                    return Theme.indicatorBad
                if (BatteryService.percent <= 20)
                    return Theme.indicatorWarn
            }
            break
        case "stats":
            if (StatsService.cpu >= 90)
                return Theme.indicatorBad
            if (StatsService.cpu >= 70)
                return Theme.indicatorWarn
            break
        case "recorder":
            return RecorderService.recording ? Theme.indicatorBad : Theme.textMuted
        case "timer":
            return TimerService.running ? TimerService.tint : Theme.text
        case "claude":
            return ClaudeService.measured ? ClaudeService.tint : Theme.indicator
        }
        return Theme.text
    }

    // ── VISIBILITY ──────────────────────────────────────────────────────────
    //
    // A placed piece always shows; the player says "Nothing playing" rather
    // than disappearing. Timer, recorder and player can instead be set to show
    // only while running (`when: "running"`).
    readonly property var runners: ["timer", "recorder", "media"]

    function runs(id: string): bool {
        switch (id) {
        case "timer":
            return TimerService.running
        case "recorder":
            return RecorderService.recording
        case "media":
            return MediaService.playing
        }
        return false
    }

    function shows(id: string, when: var): bool {
        if (when === "running" && root.runners.indexOf(id) >= 0)
            return root.runs(id)
        return id === "media" || root.has(id)
    }

    // ── ACTIVITIES ──────────────────────────────────────────────────────────
    //
    // Up to two running activities shown beside the time, most urgent first:
    // recording, countdown, music. Each can be kept off the island
    // (`SettingsService.beside`) without affecting its module.
    readonly property var activities: {
        const list = []
        if (RecorderService.recording && SettingsService.beside("recorder"))
            list.push("recorder")
        if (TimerService.running && SettingsService.beside("timer"))
            list.push("timer")
        if (MediaService.playing && SettingsService.beside("media"))
            list.push("media")
        return list.slice(0, 2)
    }

    // Resting width. Alone, the time keeps the catalogue width; with
    // activities it shrinks to fit and each side gets a slot. One activity
    // splits across both sides (mark left, figure right); two take one each.
    readonly property int clockCore: SettingsService.clockShowsDate
        ? 150 : (SettingsService.clockShowsSeconds ? 88 : 72)
    readonly property int activitySide: root.activities.length > 1 ? 92 : 64
    readonly property int restWidth: root.activities.length === 0
        ? root.entry("clock").width
        : root.clockCore + 2 * root.activitySide

    // The glance the island opens under a resting pointer.
    readonly property int summaryWidth: 384
    readonly property int summaryHeight: MediaService.available ? 168 : 116

    // ── OPEN DETAIL ─────────────────────────────────────────────────────────
    //
    // One detail at a time, always shown by the island (`Bar.qml` writes
    // "island" to `openHost`).
    property string openId: ""
    property string openHost: ""

    function close(): void {
        root.openId = ""
        root.openHost = ""
    }

    // The catalogue size, except network and Bluetooth, which open the
    // control centre's lists, and an empty notification list, which is short.
    function openSize(id: string): var {
        if (id === "network" || id === "bluetooth")
            return { width: 420, height: 500 }
        const item = root.entry(id)
        if (id === "notifications" && NotificationService.history.length === 0)
            return { width: item.width, height: 124 }
        return { width: item.width, height: item.height }
    }

    // A module that becomes unavailable closes its open detail.
    readonly property bool openGone: root.openId !== "" && !root.has(root.openId)

    onOpenGoneChanged: {
        if (root.openGone)
            root.close()
    }

    // Chips cannot see their bar, so they ask here and the bar listens. `from`
    // ("zone", "island" or "elsewhere") lets the screen with the island answer
    // for one without it.
    signal activationRequested(string id, string from)

    function activate(id: string, from: string): void {
        root.activationRequested(id, from)
    }

    // A module asking for a panel, e.g. the games detail opening the arcade.
    signal panelRequested(string panel)

    function requestPanel(panel: string): void {
        root.panelRequested(panel)
    }

    // ── AVAILABILITY ────────────────────────────────────────────────────────
    //
    // Whether this machine can show the module at all (a backlight, a player
    // on the bus, pacman-contrib installed). Not a preference; placement is
    // the layout's job.
    function has(id: string): bool {
        if (root.isButton(id))
            return true
        switch (id) {
        case "clock":
        case "calendar":
        case "timer":
        case "workspaces":
        case "notifications":
            return true
        case "media":
            return MediaService.available
        case "claude":
            // Reading this constructs the lazy singleton, which runs its
            // first query; it turns true a moment later.
            return ClaudeService.available
        case "battery":
            return BatteryService.available
        case "volume":
            return AudioService.ready
        case "brightness":
            // A desktop has no backlight, the way it has no battery.
            return BrightnessService.available
        case "network":
            // Disconnected is still a reading.
            return true
        case "bluetooth":
            return BluetoothService.available
        case "weather":
            // Builds the service, which runs its first fetch.
            return WeatherService.available
        case "github":
            // False until a name is set and a grid comes back, so nothing
            // shows on an unconfigured machine.
            return GithubService.available
        case "stats":
            // The sampler runs from boot (shell.qml touches it).
            return true
        case "updates":
            // False on a machine with neither checkupdates nor pacman.
            return UpdatesService.available
        case "pet":
            // `ready` is constant true; reading it builds the service, and
            // the service's trickle runs while the pet is on the bar.
            return PetService.ready
        case "games":
            return GamesService.ready
        case "recorder":
            // Needs an encoder.
            return RecorderService.available
        case "notes":
            return NotesService.ready
        case "tasks":
            return TasksService.ready
        case "photo":
            // An empty one asks for a picture.
            return true
        }
        return false
    }
}
