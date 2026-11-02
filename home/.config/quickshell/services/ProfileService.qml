// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P R O F I L E   S E R V I C E                                          │
// │   profiles · switch, rename, import and export                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

import "../theme"

// Named profiles: complete setups, one of them in use.
//
// The profile in use is the settings file itself, so neither SettingsService
// nor any other service knows profiles exist; the others wait in
// `profiles.json`. Switching stashes the current one there, adopts the other
// into the settings file and reloads Hyprland, as Reset does. A profile also
// carries its wallpaper and palette.
//
// Profiles are keyed by id; the name is only a label. They never carry
// `SettingsService.machineKeys` (screens, identity, per-session switches) or
// user data (notes, tasks, clipboard, pet).
Singleton {
    id: root

    // [{ id, name, wallpaper, palette, settings }]. The active entry's
    // `settings` goes stale at once, so `settingsOf` reads the live file for
    // it and a switch refreshes it on the way out.
    property var profiles: []
    property string active: ""

    // Nothing is written before the file has been read; an early write would
    // wipe every profile.
    property bool arrived: false

    // The version an export is written in, and the newest one an import
    // accepts.
    readonly property int format: 1

    readonly property int nameLength: 32

    function entry(id: string): var {
        return root.profiles.find(item => item.id === id) ?? null
    }

    readonly property var current: root.entry(root.active)

    // What a profile holds right now: the live file for the one in use, the
    // snapshot for the rest.
    function settingsOf(id: string): var {
        if (id === root.active)
            return SettingsService.snapshot()
        const found = root.entry(id)
        return SettingsService.complete(found ? found.settings : ({}))
    }

    function wallpaperOf(id: string): string {
        if (id === root.active)
            return WallpaperService.chosen
        const found = root.entry(id)
        return found ? found.wallpaper : ""
    }

    function paletteOf(id: string): string {
        if (id === root.active)
            return ThemeService.activeId
        const found = root.entry(id)
        return found ? found.palette : ""
    }

    // ── NAMES ───────────────────────────────────────────────────────────────

    function cleanName(name: string): string {
        return String(name ?? "").replace(/\s+/g, " ").trim().slice(0, root.nameLength)
    }

    // "Focus", then "Focus 2", "Focus 3"…
    function uniqueName(wanted: string, except: string): string {
        const base = root.cleanName(wanted) || Tr.t("Profile")
        const taken = name => root.profiles.some(item =>
            item.id !== except && item.name.toLowerCase() === name.toLowerCase())
        if (!taken(base))
            return base
        const stem = base.replace(/ \d+$/, "")
        for (let n = 2; ; n++) {
            if (!taken(`${stem} ${n}`))
                return `${stem} ${n}`
        }
    }

    function newId(): string {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────

    // Defaults with the current wallpaper and palette. Not switched to.
    function create(): string {
        if (!root.arrived)
            return ""
        const made = {
            id: root.newId(),
            name: root.uniqueName(Tr.t("New profile"), ""),
            wallpaper: WallpaperService.chosen,
            palette: ThemeService.activeId,
            settings: SettingsService.complete({})
        }
        root.profiles = root.profiles.concat([made])
        root.save()
        return made.id
    }

    // A copy, put straight after the one it was copied from.
    function duplicate(id: string): string {
        const from = root.entry(id)
        if (!from || !root.arrived)
            return ""
        const made = {
            id: root.newId(),
            name: root.uniqueName(from.name, ""),
            wallpaper: root.wallpaperOf(id),
            palette: root.paletteOf(id),
            settings: root.settingsOf(id)
        }
        const list = root.profiles.slice()
        list.splice(list.indexOf(from) + 1, 0, made)
        root.profiles = list
        root.save()
        return made.id
    }

    function rename(id: string, name: string): void {
        const clean = root.cleanName(name)
        if (clean === "" || !root.entry(id))
            return
        root.profiles = root.profiles.map(item => item.id === id
            ? Object.assign({}, item, { name: root.uniqueName(clean, id) })
            : item)
        root.save()
    }

    // The active profile cannot be removed.
    function remove(id: string): void {
        if (id === root.active)
            return
        root.profiles = root.profiles.filter(item => item.id !== id)
        root.save()
    }

    // ── SWITCHING ───────────────────────────────────────────────────────────

    // Saves the active profile's current state into the list.
    function stash(): void {
        root.profiles = root.profiles.map(item => item.id === root.active
            ? Object.assign({}, item, {
                settings: SettingsService.snapshot(),
                wallpaper: WallpaperService.chosen,
                palette: ThemeService.activeId })
            : item)
    }

    function switchTo(id: string): void {
        const target = root.entry(id)
        if (!target || id === root.active || !root.arrived)
            return
        root.stash()
        if (!SettingsService.adopt(target.settings))
            return
        root.active = id
        root.save()

        CompositorService.reassert()

        // Palette before wallpaper. With the adaptive palette the wallpaper's
        // `applied` repaints, so it is only set here if not already active.
        const palette = target.palette
        if (palette !== "" && palette !== ThemeService.activeId
                && (palette === "adaptive" || Palettes.byId(palette)))
            ThemeService.setTheme(palette)
        root.showWallpaper(target.wallpaper)

        OsdService.requested("󰀉", target.name, -1)
    }

    // Only if the file exists: an imported profile may name a missing one,
    // and WallpaperService would record it as current before
    // `theme_manager.py` refuses it.
    function showWallpaper(path: string): void {
        if (!path || path === WallpaperService.chosen)
            return
        root.wallpaperCheck.wanted = path
        root.wallpaperCheck.command = ["test", "-f", path]
        root.wallpaperCheck.running = true
    }

    readonly property Process wallpaperCheck: Process {
        property string wanted: ""

        onExited: code => {
            if (code === 0 && wanted !== WallpaperService.chosen)
                WallpaperService.apply(wanted)
        }
    }

    // ── IMPORT AND EXPORT ───────────────────────────────────────────────────
    //
    // A plain JSON file:
    //
    //   impasto    the format, `format` — a number, and the file's mark
    //   name       what it was called
    //   wallpaper  the picture, with the home directory written as `~`
    //   palette    "adaptive", or a palette id from `Palettes`
    //   settings   every profile key; never a machine key
    readonly property string home: Quickshell.env("HOME")

    function tilde(path: string): string {
        return path.startsWith(root.home + "/") ? "~" + path.slice(root.home.length) : path
    }

    // The path itself if it is a bundled wallpaper, else a bundled wallpaper
    // with the same file name, else the path as given (`showWallpaper` checks
    // it exists on switch).
    function resolveWallpaper(path: string): string {
        if (typeof path !== "string" || path === "")
            return ""
        const expanded = path.startsWith("~/") ? root.home + path.slice(1) : path
        const shipped = WallpaperService.wallpapers
        if (shipped.some(item => item.path === expanded))
            return expanded
        const name = expanded.slice(expanded.lastIndexOf("/") + 1)
        const same = shipped.find(item => item.path.endsWith("/" + name))
        return same ? same.path : expanded
    }

    function exportTo(id: string, path: string): void {
        const found = root.entry(id)
        if (!found || path === "")
            return
        const file = /\.json$/i.test(path) ? path : `${path}.json`
        const document = {
            impasto: root.format,
            name: found.name,
            wallpaper: root.tilde(root.wallpaperOf(id)),
            palette: root.paletteOf(id),
            settings: root.settingsOf(id)
        }
        root.exporter.name = found.name
        root.exporter.path = file
        root.exporter.setText(JSON.stringify(document, null, 2) + "\n")
    }

    // Reported only once the file is written.
    readonly property FileView exporter: FileView {
        property string name: ""

        printErrors: false

        onSaved: OsdService.requested("󰈝", Tr.t("Exported %1").arg(name), -1)
        onSaveFailed: OsdService.requested("󰀦", Tr.t("Could not write that file"), -1)
    }

    function importFrom(path: string): void {
        if (path === "" || !root.arrived)
            return
        if (root.importer.path === path)
            root.importer.reload()
        else
            root.importer.path = path
    }

    readonly property FileView importer: FileView {
        printErrors: false

        onLoaded: root.receive(text(), path)
        onLoadFailed: OsdService.requested("󰀦", Tr.t("Could not read that file"), -1)
    }

    // Rejected whole if it is not a profile. Otherwise unknown keys and
    // values of the wrong shape are skipped and counted, so an import from a
    // newer version says what it dropped.
    function receive(text: string, path: string): void {
        const document = root.parse(text)
        if (document === null) {
            OsdService.requested("󰀦", Tr.t("Not an impasto profile"), -1)
            return
        }
        if (document.impasto > root.format) {
            OsdService.requested("󰀦", Tr.t("Made by a newer impasto"), -1)
            return
        }

        const given = document.settings
        const skipped = Object.keys(given).filter(key =>
            SettingsService.profileKeys.indexOf(key) < 0
            || !SettingsService.accepts(key, given[key])).length
        const file = path.slice(path.lastIndexOf("/") + 1).replace(/\.json$/i, "")

        const made = root.fromDocument(document, file)
        root.profiles = root.profiles.concat([made])
        root.save()
        OsdService.requested("󰋺", skipped > 0
            ? Tr.t("Imported %1 · %2 left out").arg(made.name).arg(skipped) : Tr.t("Imported %1").arg(made.name), -1)
    }

    // An export's text as a document, or null when it is not one: it has to
    // parse, carry the mark, and hold its settings as a map.
    function parse(text: string): var {
        let document = null
        try {
            document = JSON.parse(text)
        } catch (error) {
            return null
        }
        const given = document ? document.settings : null
        if (!document || typeof document !== "object" || typeof document.impasto !== "number"
                || !given || typeof given !== "object" || Array.isArray(given))
            return null
        return document
    }

    // A new entry out of a document, named by it or by `fallback`. Every key
    // it does not carry is the default's (`complete`), never the last
    // profile's.
    function fromDocument(document: var, fallback: string): var {
        const palette = typeof document.palette === "string"
            && (document.palette === "adaptive" || Palettes.byId(document.palette))
            ? document.palette : ""
        return {
            id: root.newId(),
            name: root.uniqueName(typeof document.name === "string" ? document.name : fallback, ""),
            wallpaper: root.resolveWallpaper(document.wallpaper),
            palette: palette,
            settings: SettingsService.complete(document.settings)
        }
    }

    // ── SHIPPED PROFILES ────────────────────────────────────────────────────
    //
    // Example profiles ship as ordinary exports in the data directory. Each
    // is added to the list once and recorded in `offered`, so a deleted one
    // stays deleted and a new one arrives with an update. A fresh install
    // switches to the first. They are also what the Import dialog opens.
    readonly property string shippedDirectory:
        `${Quickshell.env("XDG_DATA_HOME") || root.home + "/.local/share"}/impasto/profiles`

    // File name without `.json` → document, as read. The name sorts them, so
    // they arrive in the order their files are numbered.
    property var shipped: ({})

    // The file names already put on the list once, kept in `profiles.json`.
    property var offered: []

    readonly property FolderListModel shippedFiles: FolderListModel {
        folder: "file://" + root.shippedDirectory
        nameFilters: ["*.json"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    readonly property Instantiator shippedReaders: Instantiator {
        model: root.shippedFiles

        delegate: FileView {
            required property string filePath
            required property string fileBaseName

            property bool counted: false

            path: filePath
            printErrors: false

            onLoaded: {
                const document = root.parse(text())
                if (document !== null && document.impasto <= root.format) {
                    const next = Object.assign({}, root.shipped)
                    next[fileBaseName] = document
                    root.shipped = next
                }
                counted = true
                root.shippedRead += 1
                root.offerShipped()
            }
            onLoadFailed: {
                counted = true
                root.shippedRead += 1
                root.offerShipped()
            }

            // Forget a file that disappears, or a renamed file would be
            // offered under both names.
            Component.onDestruction: {
                if (root.shipped[fileBaseName] !== undefined) {
                    const next = Object.assign({}, root.shipped)
                    delete next[fileBaseName]
                    root.shipped = next
                }
                if (counted)
                    root.shippedRead -= 1
            }
        }
    }

    // Files read so far. Nothing is offered until all are, since they load
    // in arbitrary order.
    property int shippedRead: 0

    // Adds everything shipped but not yet offered, in one write. A no-op when
    // nothing is new, which keeps the watched file from reloading in a loop.
    function offerShipped(): void {
        if (!root.arrived || !SettingsService.arrived)
            return
        if (root.shippedFiles.status !== FolderListModel.Ready
                || root.shippedRead < root.shippedFiles.count)
            return
        const waiting = Object.keys(root.shipped).sort()
            .filter(name => root.offered.indexOf(name) < 0)
        if (waiting.length === 0)
            return
        const made = waiting.map(name => root.fromDocument(root.shipped[name], name))
        root.profiles = root.profiles.concat(made)
        root.offered = root.offered.concat(waiting)

        // On a fresh install, the empty "Default" placeholder is replaced by
        // the first shipped profile. On an existing setup the placeholder is
        // the user's configuration and stays.
        const blank = root.placeholder
        root.placeholder = ""
        if (blank !== "" && blank === root.active && SettingsService.fresh) {
            root.switchTo(made[0].id)
            root.profiles = root.profiles.filter(item => item.id !== blank)
        }
        root.save()
    }

    // The "Default" made when there was no list at all, until the first
    // shipped profile has had the chance to take its place.
    property string placeholder: ""

    readonly property Connections settingsArrive: Connections {
        target: SettingsService

        function onArrivedChanged(): void {
            root.offerShipped()
        }
    }

    // ── STORAGE ─────────────────────────────────────────────────────────────

    // One entry as it came off the disk, or null when it is not one.
    function normalise(item: var): var {
        if (!item || typeof item !== "object" || typeof item.id !== "string" || item.id === "")
            return null
        const name = root.cleanName(typeof item.name === "string" ? item.name : "")
        return {
            id: item.id,
            name: name || Tr.t("Profile"),
            wallpaper: typeof item.wallpaper === "string" ? item.wallpaper : "",
            palette: typeof item.palette === "string" ? item.palette : "",
            settings: item.settings && typeof item.settings === "object" ? item.settings : ({})
        }
    }

    // The list must contain the profile in the settings file. With no list,
    // or a hand-edited one that lost it, it is added under a new name.
    function arrive(list: var, active: string): void {
        const seen = {}
        const out = []
        for (const item of list) {
            const entry = root.normalise(item)
            if (entry && !seen[entry.id]) {
                seen[entry.id] = true
                out.push(entry)
            }
        }
        root.profiles = out
        root.active = active
        root.offered = store.offered ? Array.from(store.offered) : []
        root.arrived = true
        // Only written when something was added: the file is watched.
        if (!seen[active]) {
            const made = { id: root.newId(), name: root.uniqueName(Tr.t("Default"), ""),
                           wallpaper: "", palette: "", settings: ({}) }
            root.profiles = [made].concat(out)
            root.active = made.id
            root.placeholder = made.id
            root.save()
        }
        root.offerShipped()
    }

    function save(): void {
        if (root.arrived)
            root.saver.restart()
    }

    readonly property Timer saver: Timer {
        interval: 0
        onTriggered: {
            store.profiles = root.profiles
            store.active = root.active
            store.offered = root.offered
            root.file.writeAdapter()
        }
    }

    readonly property FileView file: FileView {
        path: `${SettingsService.stateDirectory}/profiles.json`
        watchChanges: true

        onFileChanged: reload()
        onLoaded: root.arrive(store.profiles ? Array.from(store.profiles) : [], store.active)
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.arrive([], "")
        }

        JsonAdapter {
            id: store

            property string active: ""
            property var profiles: []
            property var offered: []
        }
    }
}
