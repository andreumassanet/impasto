// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T E S   S E R V I C E                                              │
// │   notes storage and the open note                                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Sticky notes: a title, a body and a tint. No state or date; those are tasks
// (`TasksService`), and the two are independent.
//
// Shown by the bar chip, its detail, the notes panel, desktop widgets and edge
// decks. Placement belongs to `DesktopService`. Notes are only edited in the
// island, since the desktop never takes the keyboard.
//
// Stored in `notes.json` in the state directory, written after a short
// debounce. Archived before deleted.
Singleton {
    id: root

    readonly property bool ready: true

    // ── PAPER ───────────────────────────────────────────────────────────────
    //
    // A palette token (never a hex) washed towards white, so the paper follows
    // the wallpaper. The ink is fixed.
    readonly property var tints: ["yellow", "accent", "green", "blue", "red"]

    function tintColor(name: string): color {
        switch (name) {
        case "green":  return Theme.green
        case "yellow": return Theme.yellow
        case "red":    return Theme.red
        case "blue":   return Theme.blue
        }
        return Theme.accent
    }

    function paperOf(name: string): color {
        return Qt.tint(root.tintColor(name), Theme.paperWash)
    }

    // ── COLLECTION ──────────────────────────────────────────────────────────
    //
    //   key       unique id, e.g. "note-m2k9x1"
    //   title
    //   text      body
    //   tint      one of `tints`
    //   created   ms since epoch
    //   edited    ms since epoch; the deck sorts by it
    //   archived  hidden from the deck and the desktop
    property var notes: []

    function normalise(list: var): var {
        const rows = []
        const length = list && typeof list.length === "number" ? list.length : 0
        for (let index = 0; index < length; index++) {
            const kept = list[index]
            if (!kept || !kept.key)
                continue
            rows.push(Object.assign({
                title: "", text: "", tint: "yellow", created: 0, edited: 0,
                archived: false
            }, kept))
        }
        return rows
    }

    readonly property var live: root.notes
        .filter(note => !note.archived)
        .sort((left, right) => right.edited - left.edited)

    readonly property var archived: root.notes
        .filter(note => note.archived)
        .sort((left, right) => right.edited - left.edited)

    readonly property int count: root.live.length

    readonly property var newest: root.live[0] ?? null

    function entry(key: string): var {
        return root.notes.find(note => note.key === key) ?? null
    }

    // The note a desktop row names, if still live; otherwise the newest.
    function noteFor(row: var): var {
        const key = row && row.note ? row.note : ""
        const named = key !== "" ? root.entry(key) : null
        return named && !named.archived ? named : root.newest
    }

    // Title, else first line, else "Untitled".
    function titleOf(note: var): string {
        if (!note)
            return ""
        if (note.title && note.title.trim() !== "")
            return note.title.trim()
        const line = root.firstLine(note.text)
        return line !== "" ? line : "Untitled"
    }

    function isEmpty(note: var): bool {
        return !note || ((note.title ?? "").trim() === "" && (note.text ?? "").trim() === "")
    }

    // ── WRITING ─────────────────────────────────────────────────────────────

    signal added(string key)

    function newKey(): string {
        const stamp = Date.now().toString(36)
        let key = `note-${stamp}`
        for (let n = 2; root.entry(key); n++)
            key = `note-${stamp}-${n}`
        return key
    }

    function write(next: var): void {
        root.notes = next
        root.saver.restart()
    }

    function add(title: string, text = "", tint = "yellow"): string {
        const now = Date.now()
        const key = root.newKey()
        root.write(root.notes.concat([{
            key: key,
            title: title ?? "",
            text: text ?? "",
            tint: root.tints.indexOf(tint) >= 0 ? tint : "yellow",
            created: now,
            edited: now,
            archived: false
        }]))
        DesktopService.noteAdded(key)
        root.added(key)
        return key
    }

    // A blank note opened for writing; discarded if left empty (`leave`).
    function create(tint = "yellow", fromDeck = false): string {
        const key = root.add("", "", tint)
        root.opened = key
        root.direct = !fromDeck
        return key
    }

    // Only text changes bump `edited` and bring the note to the front.
    function update(key: string, changes: var): void {
        root.write(root.notes.map(note => {
            if (note.key !== key)
                return note
            const next = Object.assign({}, note, changes)
            const written = (changes.text !== undefined && changes.text !== note.text)
                || (changes.title !== undefined && changes.title !== note.title)
            if (written)
                next.edited = Date.now()
            return next
        }))
    }

    function setTint(key: string, tint: string): void {
        if (root.tints.indexOf(tint) >= 0)
            root.update(key, { tint: tint })
    }

    // An archived note also leaves the desktop and the edge decks.
    function archive(key: string, on = true): void {
        if (!root.entry(key))
            return
        root.update(key, { archived: on })
        if (on)
            DesktopService.removeNote(key)
    }

    function remove(key: string): void {
        if (!root.entry(key))
            return
        DesktopService.removeNote(key)
        root.write(root.notes.filter(note => note.key !== key))
        if (root.opened === key)
            root.opened = ""
    }

    // ── READING ─────────────────────────────────────────────────────────────

    function firstLine(text: string): string {
        for (const line of (text ?? "").split("\n")) {
            const trimmed = line.trim()
            if (trimmed !== "")
                return trimmed
        }
        return ""
    }

    // Lines starting `[ ]` or `[x]` render as checkboxes. Display only; the
    // stored text is unchanged.
    function display(text: string): string {
        return (text ?? "")
            .replace(/^\[x\] ?/gim, "󰄲 ")
            .replace(/^\[ \] ?/gm, "󰄱 ")
    }

    function ageOf(when: real): string {
        const seconds = Math.max(0, (Date.now() - when) / 1000)
        if (seconds < 60)
            return "just now"
        if (seconds < 3600)
            return `${Math.floor(seconds / 60)} min`
        if (seconds < 86400)
            return `${Math.floor(seconds / 3600)} h`
        if (seconds < 7 * 86400)
            return `${Math.floor(seconds / 86400)} d`
        return Qt.formatDate(new Date(when), "d MMM")
    }

    // ── PANEL ───────────────────────────────────────────────────────────────
    //
    // Declared here so the island and the panel lay the deck out at its
    // final size from the first frame of the morph.
    readonly property int panelWidth: 560
    readonly property int panelHeight: 520

    // The open note, or "" for the deck. Kept here because the panel is
    // destroyed on close, and widgets and edge decks open straight onto a
    // note.
    property string opened: ""

    // Opened from outside the deck (widget, edge tab, detail, menu). Going
    // back then closes the island instead of returning to the deck.
    property bool direct: false

    function open(key: string, fromDeck = false): void {
        root.opened = root.entry(key) ? key : ""
        root.direct = !fromDeck
    }

    // Back to the deck, discarding the note if it was never written on.
    function leave(): void {
        const note = root.entry(root.opened)
        root.opened = ""
        root.direct = false
        if (note && root.isEmpty(note))
            root.remove(note.key)
    }

    // ── STORAGE ─────────────────────────────────────────────────────────────

    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: {
            state.notes = root.notes
            root.file.writeAdapter()
        }
    }

    readonly property FileView file: FileView {
        path: `${SettingsService.stateDirectory}/notes.json`

        onLoaded: root.notes = root.normalise(state.notes)
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
        }

        JsonAdapter {
            id: state

            property var notes: []
        }
    }
}
