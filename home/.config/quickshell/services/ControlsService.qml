// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O N T R O L S   S E R V I C E                                        │
// │   control centre layout · shortcuts, grid and toggles                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQml
import QtQuick
import Quickshell

import "../theme"

// Control centre layout: the row of buttons along the top and the grid of
// blocks under it. Nothing here draws; the panel and the settings page read it.
//
// The row has the session actions on the left (fixed) and user-chosen buttons
// ("doors") on the right, each opening another island panel or the settings.
//
// The grid is `Theme.centreColumns` × `Theme.centreRows` cells. Blocks span
// whole cells, only offer sizes they have a face for, and never overlap: a
// drop on an occupied cell moves to the nearest free fit, or is cancelled.
// Toggles are a single block holding its own paged list of tiles.
//
// Stored lists that are absent mean "default", so catalogue additions reach
// anyone who never customised the layout.
Singleton {
    id: root

    // ── DOORS ───────────────────────────────────────────────────────────────
    //
    //   id      settings key
    //   icon    glyph on the button
    //   label   display name
    //   detail  subtitle in the launcher's `>` mode; also searched
    //   panel   island panel it opens, or "" for the settings window
    readonly property var doors: [
        { id: "stats",      icon: "󰕬", label: "System statistics",
          detail: "Processor, memory, disks, the network", panel: "stats" },
        { id: "settings",   icon: "󰒓", label: "Settings",
          detail: "The whole desk, in a window",           panel: "" },
        { id: "pet",        icon: "󰏩", label: "Pet",
          detail: "The creature living on the bar",        panel: "pet" },
        { id: "games",      icon: "󰊗", label: "Games",
          detail: "The arcade",                            panel: "games" },
        { id: "notes",      icon: "󰎞", label: "Notes",
          detail: "The deck of sticky notes",              panel: "notes" },
        { id: "board",      icon: "󰄲", label: "Task board",
          detail: "To do, doing, done",                    panel: "board" },
        { id: "overview",   icon: "󰕰", label: "Workspace overview",
          detail: "Every workspace side by side",          panel: "overview" },
        { id: "launcher",   icon: "󰍉", label: "Launcher",
          detail: "Where you already are",                 panel: "launcher" },
        { id: "appearance", icon: "󰔏", label: "Appearance",
          detail: "The wallpaper and the palette",         panel: "appearance" },
        { id: "session",    icon: "󰐥", label: "Session menu",
          detail: "Lock, log out, suspend, restart, off",  panel: "session" },
        { id: "keys",       icon: "󰌌", label: "Keys",
          detail: "Every shortcut, on one sheet",          panel: "keys" },
        { id: "packages",   icon: "󰏗", label: "Packages",
          detail: "Updates, what is installed, the AUR",   panel: "packages" }
    ]

    readonly property var defaultButtons: ["stats", "settings", "pet", "games", "notes", "board"]

    // Not `Array.isArray`: lists read back from the settings file are wrapped
    // sequences that behave like arrays but fail that check.
    function stored(value: var): bool {
        return value !== null && value !== undefined && typeof value.length === "number"
    }

    // Door ids on the row, left to right. Unknown ids are skipped.
    readonly property var buttons: {
        const kept = SettingsService.centreButtons
        const list = root.stored(kept) ? kept : root.defaultButtons
        return list.filter(id => root.door(id) !== null)
    }

    function door(id: string): var {
        return root.doors.find(entry => entry.id === id) ?? null
    }

    readonly property var shownDoors: root.buttons.map(id => root.door(id))

    // Settings page model: shown doors in row order, then the rest.
    readonly property var doorRows: root.shownDoors.concat(
        root.doors.filter(entry => root.buttons.indexOf(entry.id) < 0))

    function showsDoor(id: string): bool {
        return root.buttons.indexOf(id) >= 0
    }

    function setDoor(id: string, on: bool): void {
        const list = root.buttons.filter(entry => entry !== id)
        if (on)
            list.push(id)
        SettingsService.set("centreButtons", list)
    }

    function moveDoor(id: string, delta: int): void {
        SettingsService.set("centreButtons", root.moved(root.buttons, id, delta))
    }

    // Returns a copy of `list` with `id` moved by `delta` places.
    function moved(list: var, id: string, delta: int): var {
        const next = list.slice()
        const at = next.indexOf(id)
        const to = at + delta
        if (at < 0 || to < 0 || to >= next.length)
            return next
        next.splice(at, 1)
        next.splice(to, 0, id)
        return next
    }

    // ── TILES ───────────────────────────────────────────────────────────────

    // One toggle tile, bound live to its service. `closes` marks one-shot
    // actions that need the panel closed first (captures, the picker); the
    // launcher's `>` mode also lists exactly these.
    component Toggle: QtObject {
        property string key: ""
        property string icon: ""
        property string label: ""
        property string detail: ""
        property bool active: false
        property bool available: true
        property bool expandable: false
        property string panel: ""
        property bool closes: false
        property var action: null

        function activate(): void {
            // Inert while arranging or when its service is unavailable.
            if (root.editing || !available)
                return
            if (action)
                action()
        }
    }

    // Airplane mode = Wi-Fi (nmcli) and Bluetooth (bluez) both off. Neither
    // service owns it, so it is derived here.
    readonly property bool airborne: !NetworkService.radioOn && !BluetoothService.enabled

    readonly property list<QtObject> toggleCatalogue: [
        Toggle {
            key: "wifi"; icon: NetworkService.icon; label: "Wi-Fi"
            detail: NetworkService.connectionName
            active: NetworkService.wifiEnabled
            expandable: true; panel: "wifi"
            action: () => NetworkService.toggleWifi()
        },
        Toggle {
            key: "bluetooth"; icon: BluetoothService.icon; label: "Bluetooth"
            detail: BluetoothService.summary
            active: BluetoothService.enabled
            available: BluetoothService.available
            expandable: BluetoothService.available; panel: "bluetooth"
            // Toggling the radio swaps the audio sink; don't show a volume OSD.
            action: () => { OsdService.suppressAudio(); BluetoothService.toggle() }
        },
        Toggle {
            key: "power"; icon: "󰓅"; label: "Power"
            detail: SystemService.powerProfile || "Unknown"
            active: SystemService.performanceMode
            available: SystemService.ready
            action: () => SystemService.toggle("power-profile")
        },
        Toggle {
            key: "focus"; icon: NotificationService.doNotDisturb ? "󰂛" : "󰂚"; label: "Focus"
            detail: NotificationService.doNotDisturb ? "Silenced" : "Notifying"
            active: NotificationService.doNotDisturb
            action: () => NotificationService.toggleDoNotDisturb()
        },
        Toggle {
            key: "microphone"; icon: AudioService.sourceIcon; label: "Microphone"
            detail: AudioService.sourceMuted ? "Muted" : "Live"
            active: !AudioService.sourceMuted
            available: AudioService.sourceReady
            action: () => AudioService.toggleSourceMute()
        },
        Toggle {
            key: "airplane"; icon: root.airborne ? "󰀝" : "󰀞"; label: "Airplane"
            detail: root.airborne ? "Radios off" : "Radios on"
            active: root.airborne
            action: () => {
                const turnOn = root.airborne
                OsdService.suppressAudio()
                NetworkService.setWifi(turnOn)
                if (BluetoothService.available && BluetoothService.enabled !== turnOn)
                    BluetoothService.toggle()
            }
        },
        Toggle {
            key: "nightlight"; icon: SunsetService.icon; label: "Night light"
            detail: SunsetService.detail
            active: SunsetService.on
            available: SunsetService.available
            action: () => SunsetService.toggle()
        },
        Toggle {
            key: "output"; icon: AudioService.icon; label: "Output"
            detail: AudioService.muted ? "Muted" : `${AudioService.volume}%`
            active: !AudioService.muted
            available: AudioService.ready
            action: () => AudioService.toggleMute()
        },
        Toggle {
            key: "dock"; icon: "󱂠"; label: "Dock"
            detail: SettingsService.dockEnabled ? "Shown" : "Hidden"
            active: SettingsService.dockEnabled
            action: () => SettingsService.set("dockEnabled", !SettingsService.dockEnabled)
        },
        Toggle {
            key: "notch"; icon: "󰌢"; label: "Notch"
            detail: SettingsService.islandAttached ? "Attached" : "Floating"
            active: SettingsService.islandAttached
            action: () => SettingsService.set("islandAttached", !SettingsService.islandAttached)
        },
        Toggle {
            key: "shadow"; icon: "󰘷"; label: "Shadows"
            detail: SettingsService.windowShadow ? "On the windows" : "Off"
            active: SettingsService.windowShadow
            action: () => SettingsService.set("windowShadow", !SettingsService.windowShadow)
        },
        Toggle {
            key: "screenshot"; icon: "󰹑"; label: "Capture"
            detail: "Photo or video"
            available: CaptureService.can("grim")
            closes: true
            // Waits for the panel to close so it is not in the screenshot.
            // Empty arguments reuse the capture surface's last choices.
            action: () => CaptureService.open("", "", "", CaptureService.settle)
        },
        Toggle {
            key: "annotate"; icon: "󰏫"; label: "Annotate"
            detail: "A region, in satty"
            available: CaptureService.can("editor")
            closes: true
            action: () => CaptureService.open("region", "photo", "editor",
                                              CaptureService.settle)
        },
        Toggle {
            key: "text"; icon: "󱄽"; label: "Read text"
            detail: "A region, to the clipboard"
            available: CaptureService.can("text")
            closes: true
            action: () => CaptureService.open("region", "photo", "text",
                                              CaptureService.settle)
        },
        Toggle {
            key: "picker"; icon: PickerService.icon; label: "Colour"
            detail: "A pixel"
            active: PickerService.picking
            available: PickerService.available
            closes: true
            // hyprpicker freezes the screen as it is, so wait for the panel
            // to close. The delay is passed by the caller because a keybind
            // with nothing open needs none.
            action: () => PickerService.pick(PickerService.settle)
        },
        Toggle {
            key: "record"; icon: RecorderService.recording ? "󰑊" : "󰕧"
            label: "Record"
            detail: RecorderService.recording
                ? RecorderService.display : RecorderService.subject
            active: RecorderService.recording
            available: RecorderService.available
            closes: true
            action: () => RecorderService.toggle(CaptureService.settle)
        },
        Toggle {
            key: "clearClipboard"; icon: "󰅍"; label: "Clear clipboard"
            detail: ClipboardService.count === 1
                ? "1 entry kept" : `${ClipboardService.count} entries kept`
            available: SettingsService.clipboardHistory
                && ClipboardService.count > 0
            // A one-shot action, which also lists it in the launcher's `>`.
            closes: true
            action: () => ClipboardService.wipe()
        }
    ]

    readonly property var defaultToggles:
        ["wifi", "bluetooth", "power", "focus", "microphone", "airplane"]

    function tileOf(key: string): var {
        for (let index = 0; index < root.toggleCatalogue.length; index++) {
            const tile = root.toggleCatalogue[index]
            if (tile.key === key)
                return tile
        }
        return null
    }

    // Fallback tiles for a toggles block without its own list: the legacy
    // panel-wide `centreToggles`, else the defaults.
    readonly property var toggleKeys: {
        const kept = SettingsService.centreToggles
        const list = root.stored(kept) ? kept : root.defaultToggles
        return Array.from(list).filter(key => root.tileOf(key) !== null)
    }

    // Tiles for one block, from its own `toggles` field (set in the
    // inspector), so two toggle blocks can carry different sets.
    function toggleKeysOf(key: string): var {
        const block = root.entryOf(key)
        const own = block ? block.toggles : undefined
        const list = root.stored(own) ? Array.from(own) : root.toggleKeys
        return list.filter(tile => root.tileOf(tile) !== null)
    }

    function tilesOf(key: string): var {
        return root.toggleKeysOf(key).map(tile => root.tileOf(tile))
    }

    // Inspector model: carried tiles in order, then the rest.
    function tileRowsOf(key: string): var {
        const keys = root.toggleKeysOf(key)
        return keys.map(tile => root.tileOf(tile)).concat(
            root.toggleCatalogue.filter(tile => keys.indexOf(tile.key) < 0))
    }

    function showsTileIn(key: string, tile: string): bool {
        return root.toggleKeysOf(key).indexOf(tile) >= 0
    }

    // Adds the tile at the end, or removes it.
    function toggleTileIn(key: string, tile: string): void {
        const list = root.toggleKeysOf(key)
        const next = list.filter(entry => entry !== tile)
        if (next.length === list.length)
            next.push(tile)
        root.update(key, { toggles: next })
    }

    function moveTileIn(key: string, tile: string, delta: int): void {
        root.update(key, { toggles: root.moved(root.toggleKeysOf(key), tile, delta) })
    }

    // ── BLOCKS ──────────────────────────────────────────────────────────────
    //
    //   id     settings key, and what `BlockFace` draws
    //   name   display name
    //   icon   glyph in the tray's list
    //   sizes  columns × rows it has a face for, smallest first
    //
    // Cells are wider than tall, so 1×2 and 2×4 are the square sizes.
    readonly property var catalogue: [
        { id: "toggles",       name: "Toggles",       icon: "󰨚", sizes: ["2x2", "2x3", "2x4", "3x2", "3x3", "4x2", "4x3"] },
        { id: "volume",        name: "Volume",        icon: "󰕾", sizes: ["2x1", "3x1", "4x1"] },
        { id: "brightness",    name: "Brightness",    icon: "󰃠", sizes: ["2x1", "3x1", "4x1"] },
        { id: "appearance",    name: "Appearance",    icon: "󰔏", sizes: ["2x2", "2x3", "2x4", "3x3", "4x2"] },
        { id: "media",         name: "Media",         icon: "󰝚", sizes: ["2x2", "2x3", "3x2", "4x2"] },
        { id: "weather",       name: "Weather",       icon: "󰖐", sizes: ["2x1", "2x2", "2x3", "4x2"] },
        { id: "calendar",      name: "Calendar",      icon: "󰃭", sizes: ["2x3", "2x4", "3x4"] },
        { id: "notifications", name: "Notifications", icon: "󰂚", sizes: ["2x4", "2x6", "2x8", "3x8"] },
        { id: "impasto",       name: "impasto",       icon: "󰏘", sizes: ["1x2", "2x2", "2x4"] },
        { id: "pet",           name: "Pet",           icon: "󰏩", sizes: ["2x2", "2x3"] },
        { id: "clock",         name: "Clock",         icon: "󰥔", sizes: ["1x2", "2x2", "2x4"] },
        { id: "games",         name: "Games",         icon: "󰊗", sizes: ["2x1", "2x2"] },
        { id: "notes",         name: "Notes",         icon: "󰎞", sizes: ["1x2", "2x2", "2x4"] },
        { id: "tasks",         name: "Tasks",         icon: "󰄲", sizes: ["1x2", "2x2", "2x3", "2x4"] }
    ]

    // Toggles, sliders and appearance on the left; media, weather and
    // calendar in the middle; notifications on the right.
    readonly property var defaultBlocks: [
        { id: "toggles",       col: 0, row: 0, size: "2x3" },
        { id: "volume",        col: 0, row: 3, size: "2x1" },
        { id: "brightness",    col: 0, row: 4, size: "2x1" },
        { id: "appearance",    col: 0, row: 5, size: "2x3" },
        { id: "media",         col: 2, row: 0, size: "2x2" },
        { id: "weather",       col: 2, row: 2, size: "2x3" },
        { id: "calendar",      col: 2, row: 5, size: "2x3" },
        { id: "notifications", col: 4, row: 0, size: "2x8" }
    ]

    function entry(id: string): var {
        return root.catalogue.find(item => item.id === id) ?? null
    }

    function sizesFor(id: string): var {
        const item = root.entry(id)
        return item ? item.sizes : ["2x2"]
    }

    function offers(id: string, size: string): bool {
        return root.sizesFor(id).indexOf(size) >= 0
    }

    // "2x3" -> { cols: 2, rows: 3 }.
    function parse(size: string): var {
        const found = /^(\d+)x(\d+)$/.exec(size ?? "")
        return found
            ? { cols: parseInt(found[1]), rows: parseInt(found[2]) }
            : { cols: 2, rows: 2 }
    }

    // A size the block does not offer falls back to its smallest.
    function sizeOf(block: var): string {
        if (block && root.offers(block.id, block.size))
            return block.size
        return root.sizesFor(block ? block.id : "")[0]
    }

    function label(size: string): string {
        const shape = root.parse(size)
        return `${shape.cols}×${shape.rows}`
    }

    // ── BOARD ───────────────────────────────────────────────────────────────
    //
    // Computed from the grid rather than measured, so the island can size
    // itself before the panel exists.
    readonly property int columns: Theme.centreColumns
    readonly property int rows: Theme.centreRows

    readonly property int boardWidth:
        root.columns * Theme.centreCellWidth + (root.columns - 1) * Theme.centreGutter
    readonly property int boardHeight:
        root.rows * Theme.centreCellHeight + (root.rows - 1) * Theme.centreGutter

    // Button row along the top, and the gap below it.
    readonly property int rowHeight: 28
    readonly property int rowGap: 14

    readonly property int panelWidth: root.boardWidth + 2 * Theme.panelPadding
    readonly property int panelHeight:
        root.boardHeight + root.rowHeight + root.rowGap + 2 * Theme.panelPadding

    function offsetX(col: int): real {
        return col * Theme.centreStrideX
    }

    function offsetY(row: int): real {
        return row * Theme.centreStrideY
    }

    function pixels(size: string): var {
        const shape = root.parse(size)
        return {
            width: shape.cols * Theme.centreCellWidth + (shape.cols - 1) * Theme.centreGutter,
            height: shape.rows * Theme.centreCellHeight + (shape.rows - 1) * Theme.centreGutter
        }
    }

    // A stored row as a rectangle, clamped onto the board.
    function geometry(block: var): var {
        const size = root.sizeOf(block)
        const shape = root.parse(size)
        const box = root.pixels(size)
        const lastColumn = Math.max(0, root.columns - shape.cols)
        const lastRow = Math.max(0, root.rows - shape.rows)
        return {
            x: root.offsetX(Math.max(0, Math.min(lastColumn, block.col ?? 0))),
            y: root.offsetY(Math.max(0, Math.min(lastRow, block.row ?? 0))),
            width: box.width,
            height: box.height
        }
    }

    // ── LAYOUT ──────────────────────────────────────────────────────────────
    //
    // Kept locally and written to the settings on a debounce, because the
    // JsonAdapter returns stale values when read back in the same turn.
    //
    // Rows are keyed by `key`, not by block id, so a block can appear twice.
    // Rows without a key get their id.
    function normalise(list: var): var {
        const rows = []
        const length = list && typeof list.length === "number" ? list.length : 0
        for (let index = 0; index < length; index++) {
            const kept = list[index]
            if (!kept || root.entry(kept.id) === null)
                continue
            const row = Object.assign({}, kept)
            if (!row.key)
                row.key = row.id
            rows.push(row)
        }
        return rows
    }

    function read(): var {
        const kept = SettingsService.centreBlocks
        return root.normalise(root.stored(kept) ? kept : root.defaultBlocks)
    }

    property var blocks: root.read()

    Connections {
        target: SettingsService

        function onCentreBlocksChanged(): void {
            if (saver.running)
                return
            root.blocks = root.read()
        }
    }

    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: SettingsService.set("centreBlocks", root.blocks)
    }

    // Block keys, reassigned only when the set changes. The panel's Repeater
    // uses this so moving a block does not rebuild every delegate.
    property var keys: []

    onBlocksChanged: root.syncKeys()
    Component.onCompleted: root.syncKeys()

    function syncKeys(): void {
        const next = root.blocks.map(block => block.key)
        if (next.length === root.keys.length
                && next.every((key, index) => key === root.keys[index]))
            return
        root.keys = next
    }

    function entryOf(key: string): var {
        return root.blocks.find(block => block.key === key) ?? null
    }

    function countOf(id: string): int {
        return root.blocks.filter(block => block.id === id).length
    }

    function placed(id: string): bool {
        return root.countOf(id) > 0
    }

    // ── COLLISIONS ──────────────────────────────────────────────────────────

    function overlaps(col: int, row: int, size: string, exceptKey: string): bool {
        const shape = root.parse(size)
        for (const other of root.blocks) {
            if (other.key === exceptKey)
                continue
            const theirs = root.parse(root.sizeOf(other))
            const theirCol = other.col ?? 0
            const theirRow = other.row ?? 0
            if (col < theirCol + theirs.cols && theirCol < col + shape.cols
                    && row < theirRow + theirs.rows && theirRow < row + shape.rows)
                return true
        }
        return false
    }

    function onBoard(col: int, row: int, size: string): bool {
        const shape = root.parse(size)
        return col >= 0 && row >= 0
            && col + shape.cols <= root.columns
            && row + shape.rows <= root.rows
    }

    function free(col: int, row: int, size: string, exceptKey: string): bool {
        return root.onBoard(col, row, size)
            && !root.overlaps(col, row, size, exceptKey)
    }

    // Nearest free cell by squared distance, or null if the shape fits nowhere.
    function nearestFree(col: int, row: int, size: string, exceptKey: string): var {
        if (root.free(col, row, size, exceptKey))
            return { col: col, row: row }
        let best = null
        let bestDistance = Infinity
        for (let c = 0; c < root.columns; c++) {
            for (let r = 0; r < root.rows; r++) {
                if (!root.free(c, r, size, exceptKey))
                    continue
                const distance = (c - col) * (c - col) + (r - row) * (r - row)
                if (distance < bestDistance) {
                    bestDistance = distance
                    best = { col: c, row: r }
                }
            }
        }
        return best
    }

    // First free cell in reading order.
    function firstFree(size: string, exceptKey: string): var {
        for (let r = 0; r < root.rows; r++) {
            for (let c = 0; c < root.columns; c++) {
                if (root.free(c, r, size, exceptKey))
                    return { col: c, row: r }
            }
        }
        return null
    }

    // Nearest cell to a point on the board.
    function cellX(position: real): int {
        return Math.round(position / Theme.centreStrideX)
    }

    function cellY(position: real): int {
        return Math.round(position / Theme.centreStrideY)
    }

    // ── WRITING ─────────────────────────────────────────────────────────────
    //
    // Always assign a new array: JsonAdapter only notices the property being
    // set, not in-place mutation.

    function write(next: var): void {
        root.blocks = next
        saver.restart()
    }

    function update(key: string, changes: var): void {
        root.write(root.blocks.map(block => block.key === key
            ? Object.assign({}, block, changes) : block))
    }

    // "<id>-<n>" with the first free n.
    function newKey(id: string): string {
        for (let n = 1; ; n++) {
            const key = `${id}-${n}`
            if (!root.entryOf(key))
                return key
        }
    }

    // Adds a block at its smallest size, at or near the given cell, else at
    // the first free one. Returns "" if there is no room.
    function add(id: string, col = -1, row = -1): string {
        if (root.entry(id) === null)
            return ""
        const size = root.sizesFor(id)[0]
        const spot = col >= 0
            ? root.nearestFree(col, row, size, "")
            : root.firstFree(size, "")
        if (!spot)
            return ""
        const key = root.newKey(id)
        root.write(root.blocks.concat([{ key: key, id: id, col: spot.col, row: spot.row, size: size }]))
        return key
    }

    function remove(key: string): void {
        root.write(root.blocks.filter(block => block.key !== key))
        if (root.selected === key)
            root.selected = ""
    }

    // Drop: the target cell or the nearest free fit; otherwise unchanged.
    function place(key: string, col: int, row: int): void {
        const block = root.entryOf(key)
        if (!block)
            return
        const spot = root.nearestFree(col, row, root.sizeOf(block), key)
        if (!spot)
            return
        root.update(key, { col: spot.col, row: spot.row })
    }

    // Resizes in place, moving as little as possible.
    function setSize(key: string, size: string): void {
        const block = root.entryOf(key)
        if (!block || !root.offers(block.id, size))
            return
        if (root.sizeOf(block) === size)
            return
        const spot = root.nearestFree(block.col ?? 0, block.row ?? 0, size, key)
        if (!spot)
            return
        root.update(key, { size: size, col: spot.col, row: spot.row })
    }

    // Scroll wheel while arranging: next size in `delta`'s direction that fits.
    function cycleSize(key: string, delta: int): void {
        const block = root.entryOf(key)
        if (!block)
            return
        const sizes = root.sizesFor(block.id)
        const at = sizes.indexOf(root.sizeOf(block))
        for (let step = 1; step < sizes.length; step++) {
            const next = sizes[(at + delta * step + sizes.length * step) % sizes.length]
            if (root.nearestFree(block.col ?? 0, block.row ?? 0, next, key)) {
                root.setSize(key, next)
                return
            }
        }
    }

    // Size selected by the resize handle, given the dragged extent in cells:
    // the smallest offered footprint containing the pointer pulled back by
    // `handleInset`, else the nearest corner. Same rule as `DesktopService`.
    readonly property real handleInset: 0.35

    function sizeNearest(id: string, cols: real, rows: real): string {
        const offered = root.sizesFor(id)
        const x = cols - root.handleInset
        const y = rows - root.handleInset
        let best = ""
        let bestArea = Infinity
        for (const size of offered) {
            const shape = root.parse(size)
            if (x <= shape.cols && y <= shape.rows && shape.cols * shape.rows < bestArea) {
                bestArea = shape.cols * shape.rows
                best = size
            }
        }
        if (best !== "")
            return best
        let bestDistance = Infinity
        for (const size of offered) {
            const shape = root.parse(size)
            const distance = (shape.cols - cols) * (shape.cols - cols)
                + (shape.rows - rows) * (shape.rows - rows)
            if (distance < bestDistance) {
                bestDistance = distance
                best = size
            }
        }
        return best
    }

    // Stored as null so the shipped default applies.
    function restore(): void {
        SettingsService.set("centreBlocks", null)
    }

    // ── ARRANGING ───────────────────────────────────────────────────────────
    //
    // Deliberately not persisted across sessions.

    property bool editing: false

    // Key of the block being dragged, or "".
    property string dragging: ""

    // Key of the block whose inspector is open, or "".
    property string selected: ""

    // Drop preview for the block or tray tile being dragged, as a cell and a
    // size; null when nothing is dragged.
    property var landing: null

    // The grid item, published by the panel. The tray lives on the bar's
    // surface, outside the panel, and needs it to map the pointer to cells.
    property Item board: null

    // The tray item, so a block dropped on it is removed. An item rather than
    // a cached box: the tray can be created while the island is still
    // animating, so its position is mapped at query time.
    property Item tray: null

    // Where the tray card was moved to, until arranging ends, and its size in
    // columns and rows, for the rest of the session; null until it is moved
    // or resized.
    property var galleryAt: null
    property var gallerySize: null

    // `x`, `y` are in the board's coordinates.
    function overTray(x: real, y: real): bool {
        if (!root.tray || !root.board)
            return false
        const at = root.tray.mapFromItem(root.board, x, y)
        return at.x >= 0 && at.x <= root.tray.width
            && at.y >= 0 && at.y <= root.tray.height
    }

    function edit(on: bool): void {
        root.editing = on
        root.selected = ""
        if (!on) {
            root.dragging = ""
            root.landing = null
            root.galleryAt = null
        }
    }
}
