// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G S   S E R V I C E                                        │
// │   user preferences · defaults here, overrides on disk                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every user preference. Defaults are the initialisers in `Store`; changes go
// to $XDG_STATE_HOME/quickshell/settings.json, outside the files `./setup`
// manages. JsonAdapter writes the file back on every change.
Singleton {
    id: root

    readonly property string stateDirectory:
        `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell`

    // ── ACCESS ──────────────────────────────────────────────────────────────

    readonly property alias clockFormat: config.clockFormat
    readonly property alias clockShowsDate: config.clockShowsDate
    readonly property alias clockShowsSeconds: config.clockShowsSeconds
    readonly property alias barHeight: config.barHeight
    readonly property alias barMargin: config.barMargin
    readonly property alias islandAttached: config.islandAttached
    readonly property alias barSideMargin: config.barSideMargin
    readonly property alias barStyle: config.barStyle
    readonly property alias barEverywhere: config.barEverywhere
    readonly property alias barHidden: config.barHidden
    readonly property alias screenCorners: config.screenCorners
    readonly property alias gameMode: config.gameMode
    readonly property alias barLeft: config.barLeft
    readonly property alias barRight: config.barRight
    readonly property alias islandSummary: config.islandSummary
    readonly property alias lyrics: config.lyrics
    readonly property alias islandActivities: config.islandActivities
    readonly property alias chipShape: config.chipShape
    readonly property alias chipFigure: config.chipFigure
    readonly property alias desktopWidgets: config.desktopWidgets
    readonly property alias desktopTheme: config.desktopTheme
    readonly property alias desktopOpacity: config.desktopOpacity
    readonly property alias desktopHidden: config.desktopHidden
    readonly property alias centreButtons: config.centreButtons
    readonly property alias centreTop: config.centreTop
    readonly property alias centreBlocks: config.centreBlocks
    readonly property alias centreColumns: config.centreColumns
    readonly property alias centreRows: config.centreRows
    readonly property alias centreToggles: config.centreToggles
    readonly property alias dockEnabled: config.dockEnabled
    readonly property alias dockPinned: config.dockPinned
    readonly property alias dockEdge: config.dockEdge
    readonly property alias dockAlignment: config.dockAlignment
    readonly property alias dockIconSize: config.dockIconSize
    readonly property alias dockMagnify: config.dockMagnify
    readonly property alias dockOpacity: config.dockOpacity
    readonly property alias dockGround: config.dockGround
    readonly property alias terminalGround: config.terminalGround
    readonly property alias dockRunning: config.dockRunning
    readonly property alias dockEverywhere: config.dockEverywhere
    readonly property alias dockAutohide: config.dockAutohide
    readonly property alias dockLauncher: config.dockLauncher
    readonly property alias weatherPlace: config.weatherPlace
    readonly property alias githubUser: config.githubUser
    readonly property alias markets: config.markets
    readonly property alias petStyle: config.petStyle
    readonly property alias launcherResults: config.launcherResults
    readonly property alias launcherOrder: config.launcherOrder
    readonly property alias launcherFits: config.launcherFits
    readonly property alias emojiTone: config.emojiTone
    readonly property alias cameraEnabled: config.cameraEnabled
    readonly property alias cameraEffect: config.cameraEffect
    readonly property alias cameraReactions: config.cameraReactions
    readonly property alias clipboardHistory: config.clipboardHistory
    readonly property alias clipboardKeep: config.clipboardKeep
    readonly property alias clipboardImages: config.clipboardImages
    readonly property alias clipboardWipeOnLock: config.clipboardWipeOnLock
    readonly property alias lockBlur: config.lockBlur
    readonly property alias lockClock: config.lockClock
    readonly property alias lockMusic: config.lockMusic
    readonly property alias lockMusicGround: config.lockMusicGround
    readonly property alias userName: config.userName
    readonly property alias userAvatar: config.userAvatar
    readonly property alias doNotDisturb: config.doNotDisturb
    readonly property alias recorderAudio: config.recorderAudio
    readonly property alias captureShape: config.captureShape
    readonly property alias captureKind: config.captureKind
    readonly property alias notesHandwriting: config.notesHandwriting
    readonly property alias deckOnEmpty: config.deckOnEmpty
    readonly property alias spectrumOnEmpty: config.spectrumOnEmpty
    readonly property alias workspaceCount: config.workspaceCount
    readonly property alias workspaceMax: config.workspaceMax
    readonly property alias workspaceMode: config.workspaceMode
    readonly property alias workspaceStyle: config.workspaceStyle
    readonly property alias workspaceIcons: config.workspaceIcons
    readonly property alias workspaceExtras: config.workspaceExtras
    readonly property alias workspaceIconRules: config.workspaceIconRules
    readonly property alias overviewScratchpads: config.overviewScratchpads
    readonly property alias motionScale: config.motionScale
    readonly property alias motionCurve: config.motionCurve
    readonly property alias animationPreset: config.animationPreset
    readonly property alias windowShadow: config.windowShadow
    readonly property alias barShadow: config.barShadow
    readonly property alias dockShadow: config.dockShadow
    readonly property alias widgetShadow: config.widgetShadow
    readonly property alias windowGlass: config.windowGlass
    readonly property alias surfaceStyle: config.surfaceStyle
    readonly property alias desktopGround: config.desktopGround
    readonly property alias barSides: config.barSides
    readonly property alias wallpaperTransition: config.wallpaperTransition
    readonly property alias greeting: config.greeting
    readonly property alias fontFamily: config.fontFamily
    readonly property alias fontMono: config.fontMono
    readonly property alias notificationTimeout: config.notificationTimeout
    readonly property alias compositor: config.compositor
    readonly property alias keyboard: config.keyboard
    readonly property alias displays: config.displays
    readonly property alias keys: config.keys
    readonly property alias launcherPrefixes: config.launcherPrefixes
    readonly property alias cursorColor: config.cursorColor
    readonly property alias cursorSize: config.cursorSize
    readonly property alias shakeToFind: config.shakeToFind
    readonly property alias nightLight: config.nightLight
    readonly property alias nightTemperature: config.nightTemperature
    readonly property alias powerTileProfile: config.powerTileProfile
    readonly property alias lidPolicy: config.lidPolicy
    readonly property alias idleLock: config.idleLock
    readonly property alias idleScreen: config.idleScreen
    readonly property alias idleSuspend: config.idleSuspend
    readonly property alias language: config.language

    // ── LAUNCHER PREFIXES ───────────────────────────────────────────────────
    //
    // The first character that selects each launcher mode. Stored as
    // overrides keyed by mode id, so a new mode needs no new key.
    readonly property var launcherPrefixDefaults: ({
        calculate: "=", desk: ">", windows: "@", timer: "!", clipboard: "'",
        emoji: ":"
    })

    function launcherPrefix(id: string): string {
        const kept = config.launcherPrefixes ?? ({})
        const chosen = kept[id]
        if (typeof chosen === "string" && chosen.length === 1)
            return chosen
        return root.launcherPrefixDefaults[id] ?? ""
    }

    function setLauncherPrefix(id: string, sigil: string): void {
        const next = Object.assign({}, config.launcherPrefixes ?? ({}))
        if (sigil === "" || sigil === root.launcherPrefixDefaults[id])
            delete next[id]
        else
            next[id] = sigil
        config.launcherPrefixes = next
    }

    // The workspace strip's own icon for a window class no desktop entry
    // names: `{ windowClass, icon }`, the class matched as a case-insensitive
    // fragment, the icon a name in the icon theme.
    function addIconRule(windowClass: string, icon: string): void {
        const fragment = windowClass.trim()
        const name = icon.trim()
        if (fragment === "" || name === "")
            return
        const kept = config.workspaceIconRules ? Array.from(config.workspaceIconRules) : []
        kept.push({ windowClass: fragment, icon: name })
        root.set("workspaceIconRules", kept)
    }

    function removeIconRule(index: int): void {
        const kept = config.workspaceIconRules ? Array.from(config.workspaceIconRules) : []
        kept.splice(index, 1)
        root.set("workspaceIconRules", kept)
    }

    readonly property var clockFormats: [
        { id: "HH:mm", label: "24-hour", sample: "17:04" },
        { id: "hh:mm AP", label: "12-hour", sample: "05:04 PM" }
    ]

    // ── BAR LAYOUT ──────────────────────────────────────────────────────────
    //
    // The style is how the bar is drawn; the layout is what is on it, as two
    // lists either side of the island. Changing style keeps the layout.
    readonly property var barStyles: [
        { id: "grouped", label: "Grouped",    note: "The workspaces, the island and the modules together in the middle." },
        { id: "spread",  label: "Spread",     note: "The workspaces at one edge, the modules at the other, the island between them." },
        { id: "island",  label: "One island", note: "Everything inside a single capsule." },
        { id: "bezel",   label: "Bezel",      note: "A band across the whole top edge, with the island dropping out of its middle." }
    ]

    // The island is cut into the top edge: chosen, or the bezel, which is
    // always cut in.
    readonly property bool notched: config.islandAttached || config.barStyle === "bezel"

    // Used while `barLeft`/`barRight` are null. `workspaces` is the strip,
    // `tray` the applications' icons and `split` starts a new capsule; none is
    // a module. The tray is not drawn while it is empty.
    readonly property var barDefaults: ({
        left: ["workspaces"],
        right: ["tray", "notifications", "network", "bluetooth", "volume", "battery"]
    })

    // An entry is a bare id, or `{ id, shape, figure, when }` when the piece
    // has its own look. Empty shape/figure follow `chipShape`/`chipFigure`;
    // `when: "running"` shows it only while active (`ModuleService.shows`).
    //
    // Copied out: JsonAdapter returns lists as Qt sequences, which fail
    // `Array.isArray` and would be mutated in place by a caller's filter.
    function barItems(side: string): var {
        const kept = side === "left" ? config.barLeft : config.barRight
        const list = kept ? Array.from(kept) : root.barDefaults[side]
        return list.map(entry => typeof entry === "string"
            ? { id: entry, shape: "", figure: "", when: "" }
            : { id: entry.id, shape: entry.shape ?? "", figure: entry.figure ?? "",
                when: entry.when ?? "" })
    }

    function barZone(side: string): var {
        return root.barItems(side).map(item => item.id)
    }

    function onBar(id: string): bool {
        return root.barZone("left").indexOf(id) >= 0
            || root.barZone("right").indexOf(id) >= 0
    }

    // Drops splits at either end or next to another split, which would draw
    // an empty capsule.
    function tidy(items: var): var {
        const out = []
        const idOf = item => typeof item === "string" ? item : item.id
        for (const item of items) {
            if (idOf(item) === "split" && (out.length === 0 || idOf(out[out.length - 1]) === "split"))
                continue
            out.push(item)
        }
        while (out.length > 0 && idOf(out[out.length - 1]) === "split")
            out.pop()
        return out
    }

    // Accepts ids or items; stores a bare id for any piece without its own
    // look.
    function setBarZone(side: string, items: var): void {
        const packed = root.tidy(items).map(item => {
            if (typeof item === "string")
                return item
            if ((item.shape ?? "") === "" && (item.figure ?? "") === "" && (item.when ?? "") === "")
                return item.id
            const out = { id: item.id }
            if (item.shape)
                out.shape = item.shape
            if (item.figure)
                out.figure = item.figure
            if (item.when)
                out.when = item.when
            return out
        })
        root.set(side === "left" ? "barLeft" : "barRight", packed)
    }

    // What may sit beside the time on the island while it runs. A module left
    // out still works on the bar; it just doesn't take a side of the island.
    // `privacy` is the microphone, camera or screen in use, which has no
    // module. A recording is always there, and is not on this list.
    readonly property var besideDefaults: ["privacy", "timer", "media", "machine"]
    // Every one the settings offer; the workspace is off until chosen.
    readonly property var besideChoices: ["privacy", "timer", "media", "machine", "workspace"]

    // A kept list predates any choice added since: one that is on by default
    // joins it once, and stays off if it is taken off after that. A list kept
    // before this was remembered saw the first four.
    function welcomeActivities(): void {
        const kept = config.islandActivities
        if (!kept)
            return
        const seen = config.islandActivitiesSeen
            ? Array.from(config.islandActivitiesSeen) : ["privacy", "timer", "media", "workspace"]
        const fresh = root.besideDefaults.filter(id => seen.indexOf(id) < 0 && Array.from(kept).indexOf(id) < 0)
        if (fresh.length === 0 && seen.length === root.besideChoices.length)
            return
        config.islandActivities = Array.from(kept).concat(fresh)
        config.islandActivitiesSeen = root.besideChoices.slice()
    }

    function beside(id: string): bool {
        const kept = config.islandActivities
        return (kept ? Array.from(kept) : root.besideDefaults).indexOf(id) >= 0
    }

    function setBeside(id: string, on: bool): void {
        const kept = config.islandActivities
        const next = (kept ? Array.from(kept) : root.besideDefaults.slice())
            .filter(other => other !== id)
        if (on)
            next.push(id)
        root.set("islandActivities", next)
        root.set("islandActivitiesSeen", root.besideChoices.slice())
    }

    // ── CHIPS ───────────────────────────────────────────────────────────────
    //
    // One shape and one figure mode for the whole bar; a piece may override
    // both (`barItems`). A module without a gauge draws its symbol in either
    // shape (`ModuleService.shapeOf`).
    readonly property var chipShapes: [
        { id: "icon", label: "Icon", note: "The symbol alone, small." },
        { id: "ring", label: "Ring", note: "The gauge, in a circle." }
    ]

    // How the workspace strip draws a workspace: shapes first, then the
    // number written out.
    readonly property var workspaceStyles: [
        { id: "dots", label: "Dots" },
        { id: "bars", label: "Bars" },
        { id: "rings", label: "Rings" },
        { id: "pills", label: "Pills" },
        { id: "numbers", label: "Numbers" },
        { id: "roman", label: "Roman" },
        { id: "kanji", label: "Kanji" },
        { id: "greek", label: "Greek" }
    ]

    readonly property var chipFigures: [
        { id: "off",   label: "No",       note: "No figure beside it" },
        { id: "hover", label: "On hover", note: "The figure opens under the pointer" },
        { id: "on",    label: "Always",   note: "The figure always beside it" }
    ]

    // No writes until the file has been read: `onAdapterUpdated` writes the
    // whole adapter, so an early `set` would overwrite every stored preference
    // with defaults. A second shell instance sharing the file makes the race
    // easy to hit. Refused writes are dropped, not queued, since a queue could
    // replay over a file another instance has written since.
    property bool arrived: false

    // No settings file existed at startup; `ProfileService` then starts on
    // the first bundled profile.
    property bool fresh: false

    function set(key: string, value: var): void {
        if (config[key] === undefined) {
            console.warn("Unknown setting:", key)
            return
        }
        if (!root.arrived) {
            console.warn("Settings not read yet; refusing to write", key)
            return
        }
        config[key] = value
    }

    // ── PROFILES ────────────────────────────────────────────────────────────
    //
    // A profile is every key except these, which belong to the machine or
    // the person: kept across switches, left out of exports and untouched by
    // Reset. The recorder and capture entries are last-used state.
    readonly property var machineKeys: [
        "displays", "lidPolicy", "workspaceMode",
        "userName", "userAvatar", "language", "keyboard", "weatherPlace", "githubUser", "markets",
        "emojiTone",
        "doNotDisturb", "nightLight", "nightTemperature", "barHidden", "desktopHidden",
        "gameMode", "powerTileProfile",
        "cameraEnabled", "cameraEffect", "cameraReactions",
        "recorderAudio", "captureShape", "captureKind"
    ]

    // A Store never read from disk: its initialisers are the defaults.
    readonly property Store pristine: Store {}

    // Enumerating a QML object yields its properties, methods and `objectName`.
    readonly property var storedKeys: {
        const out = []
        for (const key in root.pristine) {
            if (key !== "objectName" && typeof root.pristine[key] !== "function")
                out.push(key)
        }
        return out
    }

    readonly property var profileKeys:
        root.storedKeys.filter(key => root.machineKeys.indexOf(key) < 0)

    // Type tag for matching a loaded value against its default. Lists come
    // back as Qt sequences (see `barItems`), so test the JSON form.
    function shapeOf(value: var): string {
        if (value === null || value === undefined)
            return "null"
        if (typeof value !== "object")
            return typeof value
        return JSON.stringify(value).charAt(0) === "[" ? "list" : "map"
    }

    // Whether `value` can replace this key's default. A null default (an
    // unarranged layout) accepts null, a list or a map; numbers must be finite.
    function accepts(key: string, value: var): bool {
        const wanted = root.shapeOf(root.pristine[key])
        const given = root.shapeOf(value)
        if (wanted === "null")
            return given === "null" || given === "list" || given === "map"
        if (given === "number" && !Number.isFinite(value))
            return false
        return wanted === given
    }

    // Deep copy as plain data, so callers never hold the store's objects.
    function copy(value: var): var {
        return value === undefined ? null : JSON.parse(JSON.stringify(value))
    }

    // Every profile key, from `values` where valid and from the defaults
    // otherwise, so a switch never inherits the previous profile's values.
    function complete(values: var): var {
        const given = values ?? ({})
        const out = {}
        for (const key of root.profileKeys) {
            const taken = Object.prototype.hasOwnProperty.call(given, key)
                && root.accepts(key, given[key])
            out[key] = root.copy(taken ? given[key] : root.pristine[key])
        }
        return out
    }

    // The active profile, as plain data.
    function snapshot(): var {
        const out = {}
        for (const key of root.profileKeys)
            out[key] = root.copy(config[key])
        return out
    }

    // Applies a profile in one turn so the file is written once (`saver`).
    // Hyprland keeps the previous profile's values until reloaded; the caller
    // handles that (`CompositorService.reassert`).
    function adopt(values: var): bool {
        if (!root.arrived) {
            console.warn("Settings not read yet; refusing to adopt a profile")
            return false
        }
        const next = root.complete(values)
        for (const key of root.profileKeys)
            config[key] = next[key]
        return true
    }

    // Resets the active profile to defaults; machine keys are kept.
    function reset(): void {
        root.adopt({})
    }

    // A new desk types in the machine's layout, the one systemd-localed wrote
    // for the console and the login screen, rather than in input.lua's `us`.
    // Read into the first write, so nothing can reload over it.
    readonly property FileView machineKeyboard: FileView {
        path: "/etc/X11/xorg.conf.d/00-keyboard.conf"
        blockLoading: true
        printErrors: false
    }

    function machineLayout(): var {
        const text = root.machineKeyboard.text()
        const layout = /^\s*Option\s+"XkbLayout"\s+"([^"]+)"/m.exec(text)
        if (!layout)
            return ({})
        const found = { "input:kb_layout": layout[1] }
        const options = /^\s*Option\s+"XkbOptions"\s+"([^"]*)"/m.exec(text)
        const switches = options ? options[1].split(",").filter(o => o.startsWith("grp:")) : []
        if (switches.length > 0)
            found["input:kb_options"] = switches.join(",")
        return found
    }

    // ── STORAGE ─────────────────────────────────────────────────────────────

    readonly property FileView file: FileView {
        path: `${root.stateDirectory}/settings.json`
        watchChanges: true

        onFileChanged: reload()
        // Deferred to the end of the turn: calling `writeAdapter()` twice in
        // one turn reads back a stale `var` value and loses the second
        // change. Coalescing also means one write per turn (`adopt()`).
        onAdapterUpdated: saver.restart()
        onLoaded: {
            root.arrived = true
            root.welcomeActivities()
            // A ground named "frosted" is read as glass, and an empty one,
            // which followed the bar's, takes the bar's.
            for (const key of ["surfaceStyle", "desktopGround", "dockGround"])
                if (config[key] === "frosted")
                    config[key] = "glass"
            for (const key of ["desktopGround", "dockGround"])
                if (config[key] === "")
                    config[key] = config.surfaceStyle
            // The dock shared the bar's shadow before it had its own.
            if (!/"dockShadow"/.test(file.text()))
                config.dockShadow = config.barShadow
            // One island spanning the screen is the bezel now.
            if (/"barFullWidth":\s*true/.test(file.text()) && config.barStyle === "island")
                config.barStyle = "bezel"
        }
        // First run: write the defaults, which then count as read.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.fresh = true
                config.keyboard = root.machineLayout()
                root.arrived = true
                writeAdapter()
            }
        }

        readonly property Timer saver: Timer {
            interval: 0
            onTriggered: root.file.writeAdapter()
        }

        Store {
            id: config
        }
    }

    // ── SCHEMA ──────────────────────────────────────────────────────────────
    //
    // Declared once, instantiated twice: `config` is read from the file and
    // `pristine` holds the defaults.
    component Store: JsonAdapter {
        property string clockFormat: "HH:mm"
        property bool clockShowsDate: false
        property bool clockShowsSeconds: false

        // Capsule height and distance from the top edge. Every other bar
        // metric derives from `barHeight`.
        property int barHeight: 32
        property int barMargin: 16

        // A notch flush with the top edge instead of a floating capsule.
        property bool islandAttached: false

        property int barSideMargin: 18

        // A bar on every screen, or only on the one being worked on. The
        // surface is on every screen either way: this is whether it paints.
        property bool barEverywhere: true

        // Zen: the bar off the screen and its band given to the windows; the
        // island still comes down for what it has to show.
        property bool barHidden: false

        // Every screen's four corners rounded off in black.
        property bool screenCorners: false

        // Game mode: no animations, blur, shadow or glass on the compositor,
        // over whatever the rest of the settings say.
        property bool gameMode: false

        // Four shadows, one per layer: Hyprland's under the windows, the
        // shell's under the bar, the dock and the desk's widgets.
        property bool windowShadow: false
        property bool barShadow: false
        property bool dockShadow: false
        property bool widgetShadow: false

        // hyprglass. Dimmed in the settings when the plugin is not built;
        // `CompositorService` pushes it at login and after every reload.
        property bool windowGlass: false

        // The island's and the bar's ground: "classic" solid black,
        // "glass", the terminal's ground over the compositor's blur, or
        // "liquid", a clear frost over it (`Theme.islandGround`).
        property string surfaceStyle: "classic"

        // The desktop widgets' ground, as above.
        property string desktopGround: "classic"

        // The bar's sides: "capsule", each group in a capsule, or "bare",
        // the icons on the wallpaper. The one-capsule style has its band.
        property string barSides: "capsule"

        // Row id from `WallpaperService.transitions`; `random` picks anew on
        // each change.
        property string wallpaperTransition: "wipe"

        // Row id from `ThemeService.greetings`; `random` is picked by `fa` on
        // each run.
        property string greeting: "random"

        // One of `barStyles`.
        property string barStyle: "grouped"

        // Ids either side of the island; null means `barDefaults`.
        property var barLeft: null
        property var barRight: null

        // Hovering the island opens the glance; a click still opens the
        // control centre.
        property bool islandSummary: true

        // The playing track's lyrics, looked up on lrclib.net while
        // something on screen shows them.
        property bool lyrics: true

        // Null means `besideDefaults`.
        property var islandActivities: null
        // The choices there were when that list was kept, so one added since
        // can join it once (`welcomeActivities`).
        property var islandActivitiesSeen: null

        // One of `chipShapes` and one of `chipFigures`.
        property string chipShape: "icon"
        property string chipFigure: "on"

        property int launcherResults: 9

        // Order with an empty query: `recent` ranks by launch count with
        // decay; otherwise alphabetical.
        property string launcherOrder: "recent"

        // Fit the island to the number of results instead of a fixed-height
        // list. Off by default: a list that holds still is easier to aim at.
        // `launcherResults` caps it either way.
        property bool launcherFits: false

        // Skin tone for emoji that have one: 0 is the default yellow, 1 to 5
        // light to dark. The person's, so it stays with the machine.
        property int emojiTone: 0

        // ── CAMERA ──────────────────────────────────────────────────
        //
        // Off takes the virtual camera away from every program.
        property bool cameraEnabled: true

        // One of `CameraService.effects`.
        property string cameraEffect: "natural"

        // The gestures that set off a reaction, by `CameraService.reactions` id.
        property var cameraReactions: ["thumbsup", "heart", "peace", "thumbsdown", "horns", "ok"]

        // ── CLIPBOARD ───────────────────────────────────────────────
        //
        // Off stops the watcher, not just the list.
        property bool clipboardHistory: true

        // Payloads are stored as separate files, so the index stays small.
        property int clipboardKeep: 200

        property bool clipboardImages: true

        // Password-manager copies are never stored regardless
        // (`clipboard.py`).
        property bool clipboardWipeOnLock: false

        // Enough to make text unreadable, no more.
        property int lockBlur: 32

        // "stacked", hours over minutes as the login screen draws them, or
        // "inline".
        property string lockClock: "stacked"

        // What is playing on the lock: "lyrics" (the player and its lyrics),
        // "player" or "off"; and behind it, the "cover" blurred or the
        // "desktop" as without music.
        property string lockMusic: "lyrics"
        property string lockMusicGround: "cover"

        // Empty means read from the system: the passwd full name and
        // `~/.face` (`AccountService`).
        property string userName: ""
        property string userAvatar: ""

        // Persisted so silent mode survives a restart.
        property bool doNotDisturb: false

        property bool recorderAudio: false

        // The capture surface reopens on its last shape and kind. The
        // destination is not stored: it resets to saving a file.
        property string captureShape: "region"
        property string captureKind: "photo"

        // Note bodies in the handwriting font instead of the UI font.
        property bool notesHandwriting: true

        // Show edge note decks only on empty workspaces.
        property bool deckOnEmpty: false

        // Show the spectrum only on empty workspaces.
        property bool spectrumOnEmpty: false


        // Dots always shown, and the total number of workspaces. Workspaces
        // past `workspaceCount` still show while occupied.
        property int workspaceCount: 5
        property int workspaceMax: 10
        // `shared`: every screen shares the same workspaces. `screen`: each
        // has ten of its own, the main screen 1–10 and the rest after it.
        property string workspaceMode: "shared"
        // How the strip draws each workspace: a shape (`dots`, `bars`, `rings`),
        // pills holding the number and the apps (`pills`) or its number written
        // out (`numbers`, `roman`, `kanji`, `greek`).
        property string workspaceStyle: "dots"
        // The apps' icons on a workspace: `group` (the focused one's apps, up to
        // four), `single` (one per workspace, its last window) or `none`.
        property string workspaceIcons: "group"
        // Icons and the special workspace's pill beside the strip's other
        // styles; the pills style always shows them.
        property bool workspaceExtras: false
        // Class-to-icon rules for the strip, kept in the order added; see
        // `addIconRule`.
        property var workspaceIconRules: []

        // Tiles under the overview's special strip, one per scratchpad:
        // `{ name, label, keys, glyph, command }`. `name` is the special
        // workspace, `keys` the hint shown on the tile, `glyph` what it shows
        // while empty, and `command` a shell command that opens it (starting
        // its app the first time); empty, a click toggles the workspace. A
        // window dropped on a tile is sent there. Edit in settings.json.
        property var overviewScratchpads: []

        // Percentage. 100 is the designed speed; 0 disables animation.
        property int motionScale: 100

        // Named in Theme.easingCurves.
        property string motionCurve: "OutCubic"

        // Hyprland's animation preset, from Motion.presets (the two above
        // are the shell's own). `CompositorService` pushes it at startup and
        // after every reload; `animations.lua` deliberately has no preset.
        property string animationPreset: "macos"

        property string fontFamily: "Inter, Cantarell, SF Pro Text, sans-serif"
        property string fontMono: "JetBrainsMono Nerd Font Mono, monospace"

        property int notificationTimeout: 5000

        // ── COMPOSITOR ──────────────────────────────────────────────────
        //
        // Hyprland options changed from the settings window, keyed by
        // option path. Absent keys are left to the Lua config. The option
        // whitelist lives in `compositor.py`.
        property var compositor: ({})

        // The keyboard's own options (`input:kb_*`), kept apart from
        // `compositor` because the keyboard is the machine's, not the desk's.
        property var keyboard: ({})

        // ── DISPLAYS ────────────────────────────────────────────────────
        //
        // Arrangements keyed by the set of connected monitors (their
        // descriptions, sorted and joined). Without one, Hyprland's `auto`
        // applies.
        //
        //   <profile> primary   description of the screen the shell's
        //                       surfaces go on; "" means Quickshell's
        //                       first, where an unset
        //                       `PanelWindow.screen` lands anyway
        //             monitors  per description: mode, position, scale,
        //                       transform, mirror, vrr, disabled — each
        //                       optional, absent when unchanged
        //
        // Fields are defined by `monitors.py`.
        property var displays: ({})

        // ── KEYS ────────────────────────────────────────────────────────
        //
        // A combination per bind in `hypr/keybinds.lua`, keyed by its
        // description; "" leaves it unbound. Empty until the first change,
        // then complete. `ShortcutService` writes it to keys.tsv, which the
        // Lua config reads.
        property var keys: ({})

        // Launcher sigil overrides, keyed by mode id; absent means the
        // default in `launcherPrefixDefaults`.
        property var launcherPrefixes: ({})

        // ── DESKTOP ─────────────────────────────────────────────────────
        //
        // Desktop widgets in placement order; a module may appear more than
        // once:
        //
        //   key      this widget — "clock-1"; a row without one is keyed
        //            by its module on the way in
        //   id       the module, the same id the catalogue uses
        //   screen   the monitor's description; absent means the main screen
        //   col, row the square its top left corner is on
        //   family   "2x2", "4x2", "4x4" or "8x2" — which face it wears
        //   theme    "modern", "analogue" or "sticker"; absent means the
        //            desktop's
        //   style    how its capsule is drawn; absent means the desktop's
        //   opacity  how solid it is; absent means the desktop's
        //   note     for a notes widget, which note; absent means the
        //            front of the deck
        //
        // Or a deck of notes on a screen edge:
        //
        //   key      "notes-2"
        //   id       "notes"
        //   screen   as above
        //   edge     "left", "right" or "bottom"
        //   notes    the note keys on it, in order along the edge
        //   along    where on the edge, 0 to 1 from its first corner
        //   takesNew true on the one deck new notes land on
        property var desktopWidgets: []

        // The theme for widgets without their own, from
        // `DesktopService.themes`. Colours always come from the palette, and
        // the capsule's ground is the island's (`surfaceStyle`).
        property string desktopTheme: "modern"

        // Capsule opacity in percent; below 100 the desktop layer's blur
        // rule (`windowrules.lua`) shows through. Widgets may override it.
        property int desktopOpacity: 100

        // Every widget off the picture for a while; arranging shows them.
        property bool desktopHidden: false

        // ── CONTROL CENTRE ──────────────────────────────────────────────
        //
        // The top row's doors before `centreTop`, ids from
        // `ControlsService.doors`; read only as that row's default.
        property var centreButtons: null

        // The top row: `{ left, right }`, session action and door ids in
        // order. Null is the session's actions left and the doors above
        // right; two empty sides are no row at all.
        property var centreTop: null

        // The grid's columns and rows; 0 is the default the default layout
        // fills.
        property int centreColumns: 0
        property int centreRows: 0

        // The blocks on the control centre's grid, one row each:
        //
        //   id    the block, from `ControlsService.catalogue`
        //   col   which column its top left cell is in
        //   row   and which row
        //   size  "2x3": columns by rows, one of the sizes the block offers
        //
        // Null means the default layout.
        property var centreBlocks: null

        // Toggles on the tile block, in order, from
        // `ControlsService.toggleCatalogue`. Null is the default six;
        // overflow becomes a second page.
        property var centreToggles: null

        // ── DOCK ────────────────────────────────────────────────────────
        //
        // An empty dock is not drawn, so enabling it by default costs
        // nothing on a fresh install.
        property bool dockEnabled: true

        // Pinned desktop entry ids, in order. Name, icon and command are
        // read from the entry.
        property var dockPinned: []

        // Any edge but the top, which is the bar's.
        property string dockEdge: "bottom"

        property string dockAlignment: "center"

        // Every other dock metric derives from the icon size.
        property int dockIconSize: 44

        // The icons swell under the pointer and the neighbours make room.
        property bool dockMagnify: true

        // Percent; the compositor blurs behind the layer.
        property int dockOpacity: 100

        // The capsule's ground, as `surfaceStyle`.
        property string dockGround: "classic"

        // kitty's ground, as `surfaceStyle`.
        property string terminalGround: "glass"

        // Also show running applications that aren't pinned.
        property bool dockRunning: true

        // A dock on every screen, or only on the one being worked on.
        property bool dockEverywhere: true

        property bool dockAutohide: false

        // Launcher button at the start of the row.
        property bool dockLauncher: true

        // Anything wttr.in accepts: a city, postcode or airport code. Empty
        // lets wttr.in geolocate by IP, which can be tens of kilometres off.
        property string weatherPlace: ""

        // GitHub user for the contributions widget; empty draws nothing.
        property string githubUser: ""

        // The markets widget's pairs, BASE/QUOTE or a coin alone (in US
        // dollars), separated by commas.
        property string markets: "BTC, ETH, EUR/USD"

        // One of `PetService.styles`: how the pet is drawn, everywhere it is
        // drawn.
        property string petStyle: "creature"

        // Idle timeouts in minutes, 0 = never; all off by default.
        // `IdleService` runs one monitor per value.
        property int idleLock: 0
        property int idleScreen: 0
        property int idleSuspend: 0

        // Kelvin. Persisted, unlike keep-awake, so a restart comes back
        // warm. `SunsetService` drives hyprsunset.
        property bool nightLight: false
        property int nightTemperature: 4000

        // The profile the power tile's press goes to from balanced: the last
        // one picked that is not balanced. Saver first, the one a laptop
        // leaves the house in.
        property string powerTileProfile: "power-saver"

        // Closing the lid with another screen connected: `off` disables the
        // panel and moves its workspaces, `keep` leaves it on, `system`
        // defers to logind. The result is written into the display profile
        // so it survives hotplug. With no other screen, logind decides.
        property string lidPolicy: "off"

        // "palette" follows the accent; otherwise a fixed #rrggbb. Built and
        // applied by compositor.py.
        property string cursorColor: "palette"
        property int cursorSize: 24

        // hypr-dynamic-cursors' shake magnification (`shake.enabled`).
        property bool shakeToFind: true

        // Translations live in `theme/Tr.qml`; missing strings fall back to
        // English.
        property string language: "en"
    }
}
