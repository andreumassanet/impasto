// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D   E   S   K   T   O   P       S   E   R   V   I   C   E              │
// │   desktop widgets and their grid positions                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Quickshell.Hyprland

import "../theme"

// Desktop widgets: which modules are on the wallpaper and where.
//
// A widget is a module (the same face and service the bar uses) placed on a
// grid in one of four families: 2×2, 4×2, 4×4 and 8×2 cells. Each family has
// its own face, and a module only offers the ones it has faces for. Widgets
// never overlap: a drop on an occupied cell moves to the nearest free fit, or
// is cancelled.
//
// Rows are keyed by `key`, not module id, so a module can be placed twice.
// Rows without a key use their module id.
//
// Notes can also sit on the left, right or bottom screen edge as a deck: a
// row with `edge` and a `notes` list instead of a cell. A note is shown in
// one place at a time. `DeckService` holds the deck geometry.
Singleton {
    id: root

    // ── FAMILIES ────────────────────────────────────────────────────────────
    //
    // In cells; `sizeFor` converts to pixels.
    readonly property var families: [
        { id: "2x2", cols: 2, rows: 2, label: "Small" },
        { id: "4x2", cols: 4, rows: 2, label: "Wide" },
        { id: "4x4", cols: 4, rows: 4, label: "Large" },
        { id: "8x2", cols: 8, rows: 2, label: "Band" }
    ]

    function family(id: string): var {
        return root.families.find(entry => entry.id === id) ?? root.families[1]
    }

    // The row's family, reduced to one its theme can draw. Defaults to 4×2,
    // which every module offers.
    function familyOf(widget: var): string {
        if (!widget || !widget.family)
            return "4x2"
        return root.drawnFamily(widget.id, widget.family, root.themeOf(widget))
    }

    function sizeFor(familyId: string): var {
        const shape = root.family(familyId)
        return { width: root.span(shape.cols), height: root.span(shape.rows) }
    }

    // ── THEMES ──────────────────────────────────────────────────────────────
    //
    // Modern (`faces/WidgetFace`) shows figures and labels; Analogue
    // (`faces/analogue/`) draws dials, gauges and similar objects. A row's
    // `theme` overrides the desktop setting.
    readonly property var themes: [
        { id: "modern",   label: "Modern" },
        { id: "analogue", label: "Analogue" }
    ]

    function themeOf(widget: var): string {
        const own = widget ? widget.theme : ""
        return own && root.themes.some(theme => theme.id === own)
            ? own : SettingsService.desktopTheme
    }

    function setTheme(key: string, theme: var): void {
        root.update(key, { theme: theme || null })
        root.conform()
    }

    // Families each theme has a face for, per module. Every module has 4×2.
    // Adding a face means an entry here and one in the theme's registry.
    readonly property var faces: ({
        modern: {
            media: ["2x2", "4x2", "4x4"],           timer: ["2x2", "4x2"],
            claude: ["2x2", "4x2", "4x4"],          battery: ["2x2", "4x2"],
            volume: ["2x2", "4x2"],                 brightness: ["2x2", "4x2"],
            network: ["2x2", "4x2"],                bluetooth: ["2x2", "4x2"],
            weather: ["2x2", "4x2", "4x4", "8x2"],  stats: ["2x2", "4x2", "4x4"],
            github: ["2x2", "4x2", "8x2"],
            updates: ["2x2", "4x2"],                pet: ["2x2", "4x2"],
            games: ["2x2", "4x2"],                  calendar: ["2x2", "4x2", "4x4"],
            notes: ["2x2", "4x2", "4x4", "8x2"],    tasks: ["2x2", "4x2", "4x4"],
            clock: ["2x2", "4x2", "8x2"],           photo: ["2x2", "4x2", "4x4", "8x2"]
        },
        analogue: {
            media: ["2x2", "4x2", "4x4"],           timer: ["2x2", "4x2"],
            claude: ["2x2", "4x2"],                 battery: ["2x2", "4x2"],
            volume: ["2x2", "4x2"],                 brightness: ["2x2", "4x2"],
            network: ["2x2", "4x2"],                bluetooth: ["2x2", "4x2"],
            weather: ["2x2", "4x2", "4x4", "8x2"],  stats: ["2x2", "4x2", "4x4"],
            github: ["2x2", "4x2", "8x2"],
            updates: ["2x2", "4x2"],                pet: ["2x2", "4x2"],
            games: ["2x2", "4x2"],                  calendar: ["2x2", "4x2", "4x4"],
            notes: ["2x2", "4x2", "4x4", "8x2"],    tasks: ["2x2", "4x2", "4x4"],
            clock: ["2x2", "4x2", "4x4", "8x2"],    photo: ["2x2", "4x2", "4x4", "8x2"]
        }
    })

    // `theme` defaults to the desktop's.
    function familiesFor(id: string, theme = ""): var {
        const table = root.faces[theme !== "" ? theme : SettingsService.desktopTheme]
            ?? root.faces.modern
        return table[id] ?? ["4x2"]
    }

    function offers(id: string, familyId: string, theme = ""): bool {
        return root.familiesFor(id, theme).indexOf(familyId) >= 0
    }

    // Without a face for `familyId`, use the largest offered family that fits
    // inside it, so a widget never grows into a neighbour.
    function drawnFamily(id: string, familyId: string, theme: string): string {
        if (root.offers(id, familyId, theme))
            return familyId
        const shape = root.family(familyId)
        let best = "2x2"
        let bestArea = 0
        for (const offered of root.familiesFor(id, theme)) {
            const candidate = root.family(offered)
            const area = candidate.cols * candidate.rows
            if (candidate.cols <= shape.cols && candidate.rows <= shape.rows && area > bestArea) {
                bestArea = area
                best = offered
            }
        }
        return best
    }

    // After a theme change, store each row's family as actually drawn. Only
    // ever shrinks, so no re-placement is needed.
    function conform(): void {
        for (const widget of root.squares) {
            const kept = widget.family ?? "4x2"
            const drawn = root.drawnFamily(widget.id, kept, root.themeOf(widget))
            if (drawn !== kept)
                root.update(widget.key, { family: drawn })
        }
    }

    Connections {
        target: SettingsService
        function onDesktopThemeChanged(): void { root.conform() }
    }

    // ── BOARD ───────────────────────────────────────────────────────────────
    //
    // The desktop surface covers the whole screen and ignores exclusive zones
    // so drags can cross the bar. The board is the surface minus the bar and
    // dock reservations; the grid and the decks share these insets.
    readonly property var insets: ({
        top: Theme.barReserve,
        left: DockService.edge === "left" ? DockService.zone : 0,
        right: DockService.edge === "right" ? DockService.zone : 0,
        bottom: DockService.edge === "bottom" ? DockService.zone : 0
    })

    property real boardWidth: 0
    property real boardHeight: 0

    // The grid on a board: the stride between squares, how many fit each way
    // and where the first one starts. The margin is the same on all four
    // sides, which takes a stride that splits the difference between the
    // board's sides into whole squares: the smallest such square no smaller
    // than `desktopCell`, and on each side the count whose margin is nearest
    // one street, never under half of one. A board too nearly square for that
    // keeps `desktopCell`, centred, with even margins on opposite sides.
    function gridFor(width: real, height: real): var {
        const gutter = Theme.desktopGutter
        if (width <= 0 || height <= 0)
            return { stride: Theme.desktopStride, columns: 8, rows: 6, originX: gutter, originY: gutter }
        const shortest = Math.min(width, height)
        const difference = Math.abs(width - height)
        const apart = Math.floor(difference / Theme.desktopStride)
        const even = apart > 0 && difference / apart - gutter <= Theme.desktopCellLargest
        const stride = even ? difference / apart : Theme.desktopStride
        let across = Math.max(1, Math.round((shortest - gutter) / stride))
        if (across > 1 && across * stride > shortest)
            across -= 1
        const count = length => even
            ? across + Math.round((length - shortest) / stride)
            : Math.max(1, Math.floor(length / stride))
        const columns = count(width)
        const rows = count(height)
        return {
            stride: stride,
            columns: columns,
            rows: rows,
            originX: (width + gutter - columns * stride) / 2,
            originY: (height + gutter - rows * stride) / 2
        }
    }

    readonly property var grid: root.gridFor(root.boardWidth, root.boardHeight)
    readonly property real stride: root.grid.stride
    readonly property int columns: root.grid.columns
    readonly property int rows: root.grid.rows
    readonly property real originX: root.grid.originX
    readonly property real originY: root.grid.originY

    // Cell edges fall on whole pixels. The stride can be fractional, so a box
    // is measured between two rounded edges and may be a pixel off `span`.
    function offsetX(col: int): real {
        return Math.round(root.originX + col * root.stride)
    }

    function offsetY(row: int): real {
        return Math.round(root.originY + row * root.stride)
    }

    // Length of `count` squares and the streets between them.
    function span(count: int): real {
        return Math.round(count * root.stride - Theme.desktopGutter)
    }

    // Nearest cell to a position (rounded, not floored).
    function cellX(x: real): int {
        return Math.round((x - root.originX) / root.stride)
    }

    function cellY(y: real): int {
        return Math.round((y - root.originY) / root.stride)
    }

    // ── ROWS ────────────────────────────────────────────────────────────────
    //
    // Kept locally rather than read back from the settings: a JsonAdapter
    // returns the previous value when read in the same turn as a write.
    // Written back on a debounce, so a drag is one write.
    //
    //   key      unique widget id, e.g. "clock-2"
    //   id       module shown
    //   col/row  top-left cell
    //   family   one of the four shapes
    //   theme    optional; defaults to the desktop's
    //   style    optional; defaults to the desktop's
    //   opacity  optional; defaults to the desktop's
    //
    // `normalise` migrates legacy rows: missing `key`, `bare` -> style, and
    // the removed `ink` field.
    function normalise(list: var): var {
        const rows = []
        const length = list && typeof list.length === "number" ? list.length : 0
        for (let index = 0; index < length; index++) {
            const kept = list[index]
            if (!kept || !kept.id)
                continue
            const row = Object.assign({}, kept)
            if (!row.key)
                row.key = row.id
            if (row.bare === true && !row.style)
                row.style = "bare"
            delete row.bare
            delete row.ink
            rows.push(row)
        }
        return rows
    }

    property var widgets: root.normalise(SettingsService.desktopWidgets)

    function isDeck(widget: var): bool {
        return widget && typeof widget.edge === "string" && widget.edge !== ""
    }

    readonly property var decks: root.widgets.filter(widget => root.isDeck(widget))
    readonly property var squares: root.widgets.filter(widget => !root.isDeck(widget))

    // Picks up external changes (reset, profile switch, manual edits). Our
    // own writes echo back with the same value, which is harmless.
    Connections {
        target: SettingsService

        function onDesktopWidgetsChanged(): void {
            if (saver.running)
                return
            root.widgets = root.normalise(SettingsService.desktopWidgets)
        }
    }

    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: SettingsService.set("desktopWidgets", root.widgets)
    }

    // Every widget is always drawn; one with no data shows an empty state
    // ("Nothing playing") instead of disappearing.
    readonly property var shown: root.squares

    // Non-empty decks, or all of them while arranging.
    readonly property var shownDecks: root.editing
        ? root.decks
        : root.decks.filter(deck => root.deckNotes(deck).length > 0)

    // Keys of drawn widgets, reassigned only when the set changes. The
    // surface's Repeater uses these instead of the rows, since a new array
    // would rebuild every delegate on each move or resize.
    property var keys: []
    property var deckKeys: []

    onShownChanged: root.syncKeys()
    onShownDecksChanged: root.syncKeys()
    Component.onCompleted: root.syncKeys()

    function syncKeys(): void {
        const next = root.shown.map(widget => widget.key)
        if (next.length !== root.keys.length
                || !next.every((key, index) => key === root.keys[index]))
            root.keys = next
        const decks = root.shownDecks.map(deck => deck.key)
        if (decks.length !== root.deckKeys.length
                || !decks.every((key, index) => key === root.deckKeys[index]))
            root.deckKeys = decks
    }

    // Every module not marked `desk: false`, including the clock (which the
    // bar doesn't offer). Not filtered by `ModuleService.has`.
    readonly property var offerable: ModuleService.catalogue
        .filter(entry => entry.desk !== false)

    function entryOf(key: string): var {
        return root.widgets.find(widget => widget.key === key) ?? null
    }

    function countOf(id: string): int {
        return root.widgets.filter(widget => widget.id === id).length
    }

    function placed(id: string): bool {
        return root.countOf(id) > 0
    }

    // ── GEOMETRY ────────────────────────────────────────────────────────────
    //
    // Shared by the widget and the surface's input mask. Computed rather than
    // measured so the mask never lags a frame behind. A square is drawn at its
    // spot on this board (`spots`).
    function geometry(widget: var, boardWidth: real, boardHeight: real): var {
        if (root.isDeck(widget)) {
            const count = root.deckNotes(widget).length
            return DeckService.stripBox(widget.edge, count,
                DeckService.startOf(widget.edge, count, root.alongOf(widget), boardWidth, boardHeight),
                boardWidth, boardHeight)
        }
        const shape = root.family(root.familyOf(widget))
        const spot = root.spotOf(widget)
        const x = root.offsetX(spot.col)
        const y = root.offsetY(spot.row)
        return {
            x: x,
            y: y,
            width: root.offsetX(spot.col + shape.cols) - Theme.desktopGutter - x,
            height: root.offsetY(spot.row + shape.rows) - Theme.desktopGutter - y
        }
    }

    // ── COLLISIONS ──────────────────────────────────────────────────────────
    //
    // Where each square is on this board: its own cell kept inside the board,
    // or the nearest free one when another already holds it. The farthest
    // right and down go first, so on a smaller board those against the edge
    // keep it and push their neighbours inward, in order. Never written back,
    // so a layout made on a larger screen stays intact.
    readonly property var spots: {
        const reach = widget => {
            const shape = root.family(root.familyOf(widget))
            return { right: (widget.col ?? 0) + shape.cols, bottom: (widget.row ?? 0) + shape.rows }
        }
        const order = root.squares.slice().sort((left, right) =>
            reach(right).right - reach(left).right || reach(right).bottom - reach(left).bottom)
        const taken = []
        const spots = {}
        for (const widget of order) {
            const shape = root.family(root.familyOf(widget))
            const home = root.clamped(widget, shape)
            let spot = home
            if (root.clashes(taken, home.col, home.row, shape)) {
                let nearest = Infinity
                for (let col = 0; col + shape.cols <= root.columns; col++) {
                    for (let row = 0; row + shape.rows <= root.rows; row++) {
                        const distance = (col - home.col) ** 2 + (row - home.row) ** 2
                        if (distance < nearest && !root.clashes(taken, col, row, shape)) {
                            nearest = distance
                            spot = { col: col, row: row }
                        }
                    }
                }
            }
            taken.push({ col: spot.col, row: spot.row, cols: shape.cols, rows: shape.rows })
            spots[widget.key] = spot
        }
        return spots
    }

    function spotOf(widget: var): var {
        return root.spots[widget.key] ?? root.clamped(widget, root.family(root.familyOf(widget)))
    }

    function clamped(widget: var, shape: var): var {
        return {
            col: Math.max(0, Math.min(root.columns - shape.cols, widget.col ?? 0)),
            row: Math.max(0, Math.min(root.rows - shape.rows, widget.row ?? 0))
        }
    }

    function clashes(taken: var, col: int, row: int, shape: var): bool {
        return taken.some(other => col < other.col + other.cols && other.col < col + shape.cols
            && row < other.row + other.rows && other.row < row + shape.rows)
    }

    function overlaps(col: int, row: int, familyId: string, exceptKey: string): bool {
        const shape = root.family(familyId)
        for (const other of root.squares) {
            if (other.key === exceptKey)
                continue
            const theirs = root.family(root.familyOf(other))
            const spot = root.spotOf(other)
            if (col < spot.col + theirs.cols && spot.col < col + shape.cols
                    && row < spot.row + theirs.rows && spot.row < row + shape.rows)
                return true
        }
        return false
    }

    function onBoard(col: int, row: int, familyId: string): bool {
        const shape = root.family(familyId)
        return col >= 0 && row >= 0
            && col + shape.cols <= root.columns
            && row + shape.rows <= root.rows
    }

    function free(col: int, row: int, familyId: string, exceptKey: string): bool {
        return root.onBoard(col, row, familyId)
            && !root.overlaps(col, row, familyId, exceptKey)
    }

    // Nearest free cell by squared distance, scanning the whole board (a few
    // hundred cells, once per drop). Null if the shape fits nowhere.
    function nearestFree(col: int, row: int, familyId: string, exceptKey: string): var {
        if (root.free(col, row, familyId, exceptKey))
            return { col: col, row: row }

        let best = null
        let bestDistance = Infinity
        for (let c = 0; c < root.columns; c++) {
            for (let r = 0; r < root.rows; r++) {
                if (!root.free(c, r, familyId, exceptKey))
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
    function firstFree(familyId: string, exceptKey: string): var {
        for (let r = 0; r < root.rows; r++) {
            for (let c = 0; c < root.columns; c++) {
                if (root.free(c, r, familyId, exceptKey))
                    return { col: c, row: r }
            }
        }
        return null
    }

    // ── WRITING ─────────────────────────────────────────────────────────────
    //
    // Always assign a new array through `write`: JsonAdapter only notices the
    // property being set, so in-place mutation is never saved.

    function write(next: var): void {
        root.widgets = next
        saver.restart()
    }

    // A null value removes the field, so the row inherits the desktop default.
    function update(key: string, changes: var): void {
        root.write(root.widgets.map(widget => {
            if (widget.key !== key)
                return widget
            const next = Object.assign({}, widget, changes)
            for (const field in changes) {
                if (changes[field] === null)
                    delete next[field]
            }
            return next
        }))
    }

    // "<id>-<n>" with the first free n, e.g. "clock-2".
    function newKey(id: string): string {
        for (let n = 1; ; n++) {
            const key = `${id}-${n}`
            if (!root.entryOf(key))
                return key
        }
    }

    // Adds a widget at its smallest family, at or near the given cell, else
    // at the first free one. Returns "" if there is no room. `fields` are
    // extra row fields (e.g. which note), so pinning is a single write.
    function add(id: string, col = -1, row = -1, fields = null): string {
        if (!ModuleService.entry(id))
            return ""
        const familyId = root.familiesFor(id)[0] ?? "4x2"
        const spot = col >= 0
            ? root.nearestFree(col, row, familyId, "")
            : root.firstFree(familyId, "")
        if (!spot)
            return ""
        const key = root.newKey(id)
        root.write(root.widgets.concat([Object.assign({}, fields ?? ({}), {
            key: key,
            id: id,
            col: spot.col,
            row: spot.row,
            family: familyId
        })]))
        return key
    }

    function remove(key: string): void {
        if (root.selected === key)
            root.selected = ""
        root.write(root.widgets.filter(widget => widget.key !== key))
    }

    // Removes every row whose `field` equals `value` (e.g. an archived note).
    function removeMatching(field: string, value: var): void {
        const kept = root.widgets.filter(widget => widget[field] !== value)
        if (kept.length === root.widgets.length)
            return
        if (root.selected !== "" && !kept.some(widget => widget.key === root.selected))
            root.selected = ""
        root.write(kept)
    }

    // ── DECKS ───────────────────────────────────────────────────────────────
    //
    // One deck per edge; empty decks are removed. Every move first removes
    // the note from wherever it was.

    readonly property var edges: ["left", "right", "bottom"]

    function deckOn(edge: string): var {
        return root.decks.find(deck => deck.edge === edge) ?? null
    }

    // Live, unarchived note keys on a deck, as a plain array.
    function deckNotes(deck: var): var {
        const list = deck && deck.notes ? deck.notes : []
        const keys = []
        const length = typeof list.length === "number" ? list.length : 0
        for (let index = 0; index < length; index++) {
            if (typeof list[index] === "string" && NotesService.entry(list[index])
                    && !NotesService.entry(list[index]).archived)
                keys.push(list[index])
        }
        return keys
    }

    // Position along the edge as a 0–1 fraction; defaults to 0.
    function alongOf(deck: var): real {
        const own = deck ? deck.along : undefined
        return typeof own === "number" ? Math.max(0, Math.min(1, own)) : 0
    }

    function setDeckAlong(key: string, along: real): void {
        if (root.isDeck(root.entryOf(key)))
            root.update(key, { along: Math.max(0, Math.min(1, along)) })
    }

    // Where a note is: "grid", an edge, or "" for nowhere.
    function placementOf(noteKey: string): string {
        if (root.squares.some(widget => widget.id === "notes" && widget.note === noteKey))
            return "grid"
        const deck = root.decks.find(deck => root.deckNotes(deck).indexOf(noteKey) >= 0)
        return deck ? deck.edge : ""
    }

    // `list` without any widget or deck entry for this note; decks left
    // empty are dropped.
    function withoutNote(list: var, noteKey: string): var {
        const kept = []
        for (const widget of list) {
            if (!root.isDeck(widget)) {
                if (!(widget.id === "notes" && widget.note === noteKey))
                    kept.push(widget)
                continue
            }
            const notes = root.deckNotes(widget).filter(key => key !== noteKey)
            if (notes.length > 0)
                kept.push(Object.assign({}, widget, { notes: notes }))
        }
        return kept
    }

    function removeNote(noteKey: string): void {
        const kept = root.withoutNote(root.widgets, noteKey)
        if (root.selected !== "" && !kept.some(widget => widget.key === root.selected))
            root.selected = ""
        root.write(kept)
    }

    // Puts a note on an edge at `index`, joining the existing deck or
    // creating one. An existing deck keeps its key and position even when
    // this was its only note, so a tab being dragged is not destroyed.
    function placeNote(noteKey: string, edge: string, index = -1): void {
        if (!NotesService.entry(noteKey) || root.edges.indexOf(edge) < 0)
            return
        const target = root.deckOn(edge)
        if (!target) {
            root.write(root.withoutNote(root.widgets, noteKey).concat([{
                key: root.newKey("notes"), id: "notes", edge: edge, notes: [noteKey], along: 0
            }]))
            return
        }
        const notes = root.deckNotes(target).filter(key => key !== noteKey)
        const at = index < 0 ? notes.length : Math.max(0, Math.min(notes.length, index))
        notes.splice(at, 0, noteKey)
        root.write(root.withoutNote(
            root.widgets.filter(widget => widget.key !== target.key), noteKey
        ).concat([Object.assign({}, target, { notes: notes })]))
    }

    // Moves a note to the nearest free 2×2. Returns false if there is none.
    function noteToGrid(noteKey: string, col: int, row: int): bool {
        if (!NotesService.entry(noteKey))
            return false
        const spot = root.nearestFree(col, row, "2x2", "")
        if (!spot)
            return false
        const list = root.withoutNote(root.widgets, noteKey)
        root.write(list.concat([{
            key: root.newKey("notes"), id: "notes",
            col: spot.col, row: spot.row, family: "2x2", note: noteKey
        }]))
        return true
    }

    // A notes widget dragged to an edge: its note joins the deck there.
    function noteToEdge(key: string, edge: string): void {
        const widget = root.entryOf(key)
        if (!widget || widget.id === undefined)
            return
        const note = NotesService.noteFor(widget)
        if (!note)
            return
        if (root.selected === key)
            root.selected = ""
        root.placeNote(note.key, edge)
    }

    // Tray tile dropped on an edge: puts the newest note there.
    function addDeck(edge: string): void {
        const note = NotesService.newest
        if (note)
            root.placeNote(note.key, edge)
    }

    // Moves a deck to another edge, merging into the deck already there.
    function setDeckEdge(key: string, edge: string): void {
        const deck = root.entryOf(key)
        if (!root.isDeck(deck) || root.edges.indexOf(edge) < 0 || deck.edge === edge)
            return
        const other = root.deckOn(edge)
        if (!other) {
            root.update(key, { edge: edge })
            return
        }
        const notes = root.deckNotes(other).concat(
            root.deckNotes(deck).filter(note => root.deckNotes(other).indexOf(note) < 0))
        if (root.selected === key)
            root.selected = other.key
        root.write(root.widgets
            .filter(widget => widget.key !== key)
            .map(widget => widget.key === other.key
                ? Object.assign({}, widget, { notes: notes }) : widget))
    }

    // A note ticked on or off a deck from the inspector.
    function toggleDeckNote(key: string, noteKey: string): void {
        const deck = root.entryOf(key)
        if (!root.isDeck(deck))
            return
        const notes = root.deckNotes(deck)
        if (notes.indexOf(noteKey) >= 0) {
            const left = notes.filter(note => note !== noteKey)
            if (left.length === 0)
                root.remove(key)
            else
                root.update(key, { notes: left })
            return
        }
        root.placeNote(noteKey, deck.edge)
    }

    // Drop: the target cell or the nearest free fit; otherwise unchanged.
    function place(key: string, col: int, row: int): void {
        const widget = root.entryOf(key)
        if (!widget)
            return
        const spot = root.nearestFree(col, row, root.familyOf(widget), key)
        if (!spot)
            return
        root.update(key, { col: spot.col, row: spot.row })
    }

    // Re-places from the current cell so a resized widget moves as little as
    // possible.
    function setFamily(key: string, familyId: string): void {
        const widget = root.entryOf(key)
        if (!widget || !root.offers(widget.id, familyId, root.themeOf(widget)))
            return
        if (root.familyOf(widget) === familyId)
            return
        const at = root.spotOf(widget)
        const spot = root.nearestFree(at.col, at.row, familyId, key)
        if (!spot)
            return
        root.update(key, { family: familyId, col: spot.col, row: spot.row })
    }

    // Scroll wheel while arranging: next family in `delta`'s direction that
    // fits.
    function cycleFamily(key: string, delta: int): void {
        const widget = root.entryOf(key)
        if (!widget)
            return
        const families = root.familiesFor(widget.id, root.themeOf(widget))
        const at = families.indexOf(root.familyOf(widget))
        const spot = root.spotOf(widget)
        for (let step = 1; step < families.length; step++) {
            const next = families[(at + delta * step + families.length * step) % families.length]
            if (root.nearestFree(spot.col, spot.row, next, key)) {
                root.setFamily(key, next)
                return
            }
        }
    }

    // Family selected by the resize handle, given the dragged extent in
    // cells. The pointer is pulled back by `handleInset` and the smallest
    // family containing it wins, so growing starts after about a third of a
    // cell. Beyond every footprint, the nearest corner decides.
    readonly property real handleInset: 0.35

    function familyNearest(id: string, cols: real, rows: real, theme = ""): string {
        const offered = root.familiesFor(id, theme)
        const x = cols - root.handleInset
        const y = rows - root.handleInset
        let best = ""
        let bestArea = Infinity
        for (const familyId of offered) {
            const shape = root.family(familyId)
            if (x <= shape.cols && y <= shape.rows && shape.cols * shape.rows < bestArea) {
                bestArea = shape.cols * shape.rows
                best = familyId
            }
        }
        if (best !== "")
            return best
        let bestDistance = Infinity
        for (const familyId of offered) {
            const shape = root.family(familyId)
            const distance = (shape.cols - cols) * (shape.cols - cols)
                + (shape.rows - rows) * (shape.rows - rows)
            if (distance < bestDistance) {
                bestDistance = distance
                best = familyId
            }
        }
        return best
    }

    // ── APPEARANCE ──────────────────────────────────────────────────────────
    //
    // Style and opacity, like theme, default to the desktop setting unless the
    // row overrides them. Colours always come from the active palette.

    readonly property var styles: [
        { id: "capsule", label: "Capsule" },
        { id: "accent",  label: "Accent" },
        { id: "outline", label: "Outline" },
        { id: "bare",    label: "No capsule" }
    ]

    function styleOf(widget: var): string {
        // Notes draw their own paper and photos are their picture, so both
        // are always bare.
        if (widget && (widget.id === "notes" || widget.id === "photo"))
            return "bare"
        const own = widget ? widget.style : ""
        return own && root.styles.some(style => style.id === own)
            ? own : SettingsService.desktopStyle
    }

    function opacityOf(widget: var): int {
        const own = widget ? widget.opacity : undefined
        return typeof own === "number" ? own : SettingsService.desktopOpacity
    }

    function setStyle(key: string, style: var): void {
        root.update(key, { style: style || null })
    }

    function setOpacity(key: string, value: var): void {
        root.update(key, { opacity: typeof value === "number" ? value : null })
    }


    // Colours for a widget's face, resolved through its style so faces never
    // read `Theme` directly. The ground is the island black; the accent style
    // inverts it, with the accent as ground.
    //
    //   ground      the capsule
    //   border      its edge
    //   text        readings and glyphs
    //   muted       labels
    //   accent      rings, sparklines, bars
    //   accentText  content on the accent
    //   raised      tracks, placeholders
    //   dim         a ring's empty track
    //
    // All values are `color`, not strings, because faces read `.r` etc. Wrap
    // any literal in `Qt.color()`.
    function inkFor(widget: var): var {
        const ink = {
            ground: Theme.island, border: Theme.islandBorder,
            text: Theme.text, muted: Theme.textMuted,
            accent: Theme.accent, accentText: Theme.accentText,
            raised: Theme.islandSurfaceHover, dim: Theme.indicatorDim
        }
        if (root.styleOf(widget) === "accent") {
            const onAccent = ink.accentText
            return {
                ground: ink.accent, border: Qt.color("transparent"),
                text: ink.accentText,
                muted: Qt.rgba(onAccent.r, onAccent.g, onAccent.b, 0.7),
                accent: ink.accentText, accentText: ink.accent,
                raised: Qt.rgba(onAccent.r, onAccent.g, onAccent.b, 0.18),
                dim: Qt.rgba(onAccent.r, onAccent.g, onAccent.b, 0.3)
            }
        }
        return ink
    }

    // ── PICTURES ────────────────────────────────────────────────────────────
    //
    // A photo widget's picture is a path on its row (`picture`), so it
    // travels with the profile, and an Analogue print writes the row's
    // `caption` under it. It is chosen on the desk, in the picker that takes
    // the inspector's place (`Picker.qml`).

    readonly property var pictureTypes: ["png", "jpg", "jpeg", "webp", "bmp"]

    // The key whose picker is open, or "". It closes with the inspector.
    property string picking: ""

    // Takes a path or a file:// URL. Anything that is not a picture is
    // refused.
    function setPicture(key: string, url: var): bool {
        const text = String(url)
        const path = text.startsWith("file://") ? decodeURIComponent(text.slice(7)) : text
        const dot = path.lastIndexOf(".")
        if (dot < 0 || root.pictureTypes.indexOf(path.slice(dot + 1).toLowerCase()) < 0)
            return false
        root.update(key, { picture: path })
        return true
    }

    // A path as a URL an Image or a folder listing loads, each segment
    // escaped.
    function urlOf(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/")
    }

    function pictureOf(widget: var): string {
        const path = widget && typeof widget.picture === "string" ? widget.picture : ""
        return path === "" ? "" : root.urlOf(path)
    }

    // A row's picture in imv, the viewer yazi hands pictures to. A plain
    // path: imv refuses a file:// URI without a word.
    function openPicture(widget: var): void {
        const path = widget && typeof widget.picture === "string" ? widget.picture : ""
        if (path !== "")
            Quickshell.execDetached(["imv", path])
    }

    // ── EDITING ─────────────────────────────────────────────────────────────
    //
    // Deliberately not persisted across sessions.

    property bool editing: false

    // True while the inspector's caption field is typed in. The surface holds
    // the keyboard for that long and no longer (`Desktop.qml`).
    property bool typing: false

    onSelectedChanged: {
        root.typing = false
        if (root.selected !== root.picking)
            root.picking = ""
    }

    // Key of the widget being dragged (drawn on top), or "".
    property string dragging: ""

    // Key of the widget whose inspector is open, or "".
    property string selected: ""

    // Drop preview for the widget or tray tile being dragged, as a cell and
    // family; null when nothing is dragged.
    property var landing: null

    // ── CONTEXT MENU ────────────────────────────────────────────────────────
    //
    // Right-click menu drawn by the desktop surface at the click position.
    // Arranging mode is only entered from this menu, never by a bare click.
    property var menu: null

    function openMenu(key: string, x: real, y: real): void {
        root.menu = { key: key, x: x, y: y }
    }

    function closeMenu(): void {
        root.menu = null
    }

    // Handled in `shell.qml`, which owns the settings window.
    signal settingsRequested()

    // The tray card's rectangle on the board; a widget dropped on it is
    // removed.
    property var trayBox: null

    // Where the card was moved to, until arranging ends, and its size in
    // columns and rows, for the rest of the session; null until it is moved
    // or resized.
    property var galleryAt: null
    property var gallerySize: null

    function overTray(x: real, y: real): bool {
        const box = root.trayBox
        return box !== null && x >= box.x && x <= box.x + box.width
            && y >= box.y && y <= box.y + box.height
    }

    function edit(on: bool): void {
        root.editing = on
        root.menu = null
        root.typing = false
        root.picking = ""
        if (!on) {
            root.dragging = ""
            root.selected = ""
            root.landing = null
            root.galleryAt = null
        }
    }

    // Arranging lasts while the screen stays as it was. Another workspace, a
    // special one shown or a window opening would be drawn under a surface
    // that covers it and takes its clicks, and a fullscreen window covers the
    // surface itself.
    readonly property Connections compositor: Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (!root.editing)
                return
            switch (event.name) {
            case "workspacev2":
            case "activespecialv2":
            case "openwindow":
                root.edit(false)
                break
            case "fullscreen":
                if (event.data === "1")
                    root.edit(false)
                break
            }
        }
    }
}
