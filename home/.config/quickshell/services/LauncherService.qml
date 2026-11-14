// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L A U N C H E R   S E R V I C E                                        │
// │   application index · search and activation                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Application index and launcher query logic.
//
// The first character selects the mode: plain text searches applications, and
// a sigil switches to calculator, shell entries (`>`), windows, timer,
// clipboard or emoji. Modes are explicit so `100` or `5:30` is never misread as a sum
// or a duration.
QtObject {
    id: root

    readonly property int maxResults: SettingsService.launcherResults

    // The prefix-less mode must be last. Sigils come from the settings
    // (`SettingsService.launcherPrefixDefaults`).
    readonly property var modes: [
        { id: "calculate", prefix: SettingsService.launcherPrefix("calculate"),
          label: Tr.t("Calculate"), icon: "󰃬",
          hint: Tr.t("Work something out"), empty: Tr.t("An expression — 12 * 34, (5 + 5) / 2") },
        { id: "desk",      prefix: SettingsService.launcherPrefix("desk"),
          label: Tr.t("Desk"), icon: "󰍜",
          hint: Tr.t("Open a panel or an action"),
          empty: Tr.t("Nothing on the desk by that name") },
        { id: "windows",   prefix: SettingsService.launcherPrefix("windows"),
          label: Tr.t("Windows"), icon: "󰖯",
          hint: Tr.t("Find an open window"), empty: Tr.t("No window by that name is open") },
        { id: "timer",     prefix: SettingsService.launcherPrefix("timer"),
          label: Tr.t("Timer"), icon: "󰔟",
          hint: Tr.t("Start a countdown"), empty: Tr.t("A duration — 25m, 90s, 1:30") },
        { id: "clipboard", prefix: SettingsService.launcherPrefix("clipboard"),
          label: Tr.t("Clipboard"), icon: "󰅍",
          hint: Tr.t("Copy something again"),
          empty: ClipboardService.entries.length === 0
              ? Tr.t("Nothing has been copied yet") : Tr.t("Nothing copied says that") },
        { id: "emoji",     prefix: SettingsService.launcherPrefix("emoji"),
          label: Tr.t("Emoji"), icon: "󰇲",
          hint: Tr.t("Copy an emoji"), empty: Tr.t("No emoji by that name") },
        { id: "apps",      prefix: "",  label: Tr.t("Apps"), icon: "󰀻",
          hint: Tr.t("Search applications"),
          empty: Tr.t("No application matches. Type %1 for what the shell itself can do.").arg(SettingsService.launcherPrefix("desk")) }
    ]

    function modeFor(query: string): var {
        const raw = query ?? ""
        for (const mode of root.modes) {
            if (mode.prefix !== "" && raw.startsWith(mode.prefix))
                return mode
        }
        return root.modes[root.modes.length - 1]
    }

    function termFor(query: string): string {
        return (query ?? "").slice(root.modeFor(query).prefix.length).trim()
    }

    // ── QUERY AND SIZE ──────────────────────────────────────────────────────
    //
    // The query lives here, not in the panel, because with `launcherFits` the
    // panel height depends on the results and the island must know its size
    // before the panel exists. Cleared when the panel closes.
    property string query: ""

    readonly property var results: root.search(root.query)

    // ── INDEX ───────────────────────────────────────────────────────────────
    //
    // A phone book's A–Z down the side of the whole list: alphabetical order,
    // nothing typed, and more applications than fit.
    readonly property bool indexed: root.order === "alphabetical"
        && root.query === "" && root.results.length > root.maxResults

    // The letter an application files under: its first letter without an
    // accent, or # for anything else.
    function letterOf(name: string): string {
        const first = (name ?? "").normalize("NFD").charAt(0).toUpperCase()
        return first >= "A" && first <= "Z" ? first : "#"
    }

    // Each letter present, once, with the row it starts at.
    readonly property var letters: {
        if (!root.indexed)
            return []
        const out = []
        root.results.forEach((entry, index) => {
            const letter = root.letterOf(entry.name)
            if (!out.some(known => known.letter === letter))
                out.push({ letter: letter, index: index })
        })
        return out
    }

    // Panel metrics, shared with the layout so the height math stays in sync.
    readonly property int fieldHeight: 34
    readonly property int rowHeight: 48
    readonly property int rowSpacing: 2
    readonly property int gap: 12

    // The emoji mode's row of groups, under the field.
    readonly property int stripHeight: 30
    readonly property bool showsStrip: root.modeFor(root.query).id === "emoji"

    // The emoji mode is a grid of glyphs rather than rows: square cells, as
    // many to a line as the panel holds.
    readonly property int emojiCell: 52
    readonly property int emojiColumns:
        Math.floor((root.panelWidth - 2 * Theme.panelPadding) / root.emojiCell)

    // Field, divider, and the gap on either side of the divider, plus the
    // strip and its gap when it shows.
    readonly property int chromeHeight: root.fieldHeight + 2 * root.gap + 1
        + (root.showsStrip ? root.stripHeight + root.gap : 0)

    // At least one row, for the "no results" line. The grid counts lines of
    // glyphs, capped at the same number as a list of rows.
    readonly property int rows: root.showsStrip
        ? Math.max(1, Math.min(Math.ceil(root.results.length / root.emojiColumns),
                               root.maxResults))
        : Math.max(1, Math.min(root.results.length, root.maxResults))

    function listHeight(rows: int): int {
        return rows * root.rowHeight + (rows - 1) * root.rowSpacing
    }

    // A full grid stops where a full list does, strip included, so the two
    // modes open to one height; the grid scrolls under its last partial line.
    function heightFor(rows: int): int {
        const list = root.showsStrip
            ? Math.min(rows * root.emojiCell,
                       root.listHeight(root.maxResults) - root.stripHeight - root.gap)
            : root.listHeight(rows)
        return root.chromeHeight + list + 2 * Theme.panelPadding
    }

    readonly property int panelWidth: 560

    // Fixed height with a scrolling list, or (`launcherFits`) sized to the
    // results up to `maxResults` rows.
    readonly property int panelHeight:
        SettingsService.launcherFits ? root.heightFor(root.rows) : 520

    // Whitelist: the expression is passed to a JavaScript evaluator.
    readonly property var arithmetic: /^[0-9+\-*/(). %]+$/

    property var applications: []

    // ── LAUNCH HISTORY ──────────────────────────────────────────────────────
    //
    // Results are ranked by a launch count with exponential decay (frecency),
    // stored in the state directory.
    readonly property string order: SettingsService.launcherOrder

    readonly property real halfLife: 30 * 24 * 3600 * 1000

    // Mirrors the adapter; reading a JsonAdapter back in the same turn as a
    // write returns the old value.
    property var launches: ({})

    readonly property FileView historyFile: FileView {
        path: `${SettingsService.stateDirectory}/launcher-history.json`
        watchChanges: true

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.launches = history.launches ?? ({})
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
        }

        JsonAdapter {
            id: history

            // Desktop id -> { count, last }. Decay is applied on read.
            property var launches: ({})
        }
    }

    function scoreOf(id: string): real {
        const row = root.launches[id]
        if (!row || !row.count)
            return 0
        const age = Date.now() - (row.last ?? 0)
        return row.count * Math.pow(0.5, age / root.halfLife)
    }

    function record(id: string): void {
        if (!id)
            return
        const next = Object.assign({}, root.launches)
        next[id] = { count: root.scoreOf(id) + 1, last: Date.now() }
        root.launches = next
        history.launches = next
    }

    // ── FAVOURITES ──────────────────────────────────────────────────────────
    //
    // The dock's pinned apps, read from the settings rather than `DockService`
    // (which depends on this service). They get a bonus of one launch.
    readonly property var favourites: SettingsService.dockPinned ?? []

    function weightOf(app: var): real {
        return root.scoreOf(app.id)
            + (root.favourites.indexOf(app.id) >= 0 ? 1 : 0)
    }

    readonly property Process applicationsProcess: Process {
        command: [Quickshell.shellPath("scripts/applications.py")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    root.applications = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the application list:", error)
                }
            }
        }
    }

    // Launches use execDetached, not Process: a Process child dies with a
    // config reload, and gtk-launch run that way exits 0 without launching.

    function refresh(): void {
        root.applicationsProcess.running = true
    }

    function search(query: string): var {
        const mode = root.modeFor(query)
        const raw = root.termFor(query)
        const term = raw.toLowerCase()

        switch (mode.id) {
        case "calculate":
            return root.calculate(raw)
        case "desk":
            return root.desk(term)
        case "windows":
            return root.windows(term)
        case "timer":
            return root.timer(raw)
        case "clipboard":
            return root.clipboard(term)
        case "emoji":
            return root.emoji(term)
        }

        // A sum typed without the calculator's prefix, first. It needs a
        // digit and an operator, so a bare number or a name is not taken for
        // one.
        const sum = /\d/.test(raw) && /[+\-*/%]/.test(raw)
            ? root.calculate(raw) : []
        // Every match: the panel caps its visible height at `maxResults`
        // rows and the rest scrolls, as the doors' list does.
        const applications = sum.concat(root.rank(term))
        return applications.concat(root.fallbacks(raw))
    }

    // ── FALLBACK ROWS ───────────────────────────────────────────────────────
    //
    // Under the applications: open what looks
    // like an address, search the web, or run the text as a command, in the
    // background or in a terminal that stays open. Each row carries its
    // `argv`, not a function, which a model would drop on the way to a click.
    readonly property string defaultSearchUrl: "https://www.google.com/search?q="

    // Optional scheme, a dotted host, optional port and path, no spaces.
    readonly property var addressPattern: /^(https?:\/\/)?[\w-]+(\.[\w-]+)+(:\d+)?(\/\S*)?$/

    function fallbacks(text: string): var {
        const query = text.trim()
        if (query === "")
            return []
        const searchUrl = SettingsService.launcherSearchUrl || root.defaultSearchUrl
        const searchHost = (searchUrl.match(/^https?:\/\/([^\/?#]+)/) ?? [])[1] ?? ""
        const rows = []
        if (root.addressPattern.test(query))
            rows.push({ kind: "command", id: "open", icon: "󰖟",
                        name: Tr.t("Open %1").arg(query), subtitle: Tr.t("In the browser"),
                        argv: ["xdg-open", /^https?:\/\//.test(query) ? query : `https://${query}`] })
        rows.push({ kind: "command", id: "web", icon: "󰜏",
                    name: Tr.t("Search the web for “%1”").arg(query),
                    subtitle: searchHost || Tr.t("Web search"),
                    argv: ["xdg-open", searchUrl + encodeURIComponent(query)] })
        rows.push({ kind: "command", id: "run", icon: "󰆍",
                    name: Tr.t("Run %1").arg(query), subtitle: Tr.t("As a command, in the background"),
                    argv: ["sh", "-c", query] })
        // The command is an argument, never part of the script; `--hold`
        // keeps the window and its output once it ends.
        rows.push({ kind: "command", id: "terminal", icon: "󰞷",
                    name: Tr.t("Run %1 in a terminal").arg(query), subtitle: Tr.t("Stays open at the end"),
                    argv: ["kitty", "--hold", "sh", "-c", query] })
        return rows
    }

    // All applications matching `term`, sorted by:
    //
    //   1. name starts with the term (applies in every order)
    //   2. weight: decayed launches plus the favourite bonus
    //   3. dock order, between two favourites of equal weight
    //   4. name
    //
    // With `order` set to alphabetical only 1 and 4 apply.
    function rank(term: string): var {
        const found = []
        for (const app of root.applications) {
            if (term !== "" && !app.name.toLowerCase().includes(term)
                    && !app.keywords.includes(term))
                continue
            found.push(app)
        }

        const byUse = root.order !== "alphabetical"
        found.sort((a, b) => {
            if (term !== "") {
                const leadA = a.name.toLowerCase().startsWith(term) ? 0 : 1
                const leadB = b.name.toLowerCase().startsWith(term) ? 0 : 1
                if (leadA !== leadB)
                    return leadA - leadB
            }
            if (byUse) {
                const weight = root.weightOf(b) - root.weightOf(a)
                if (Math.abs(weight) > 0.0001)
                    return weight
                const keptA = root.favourites.indexOf(a.id)
                const keptB = root.favourites.indexOf(b.id)
                if (keptA >= 0 && keptB >= 0 && keptA !== keptB)
                    return keptA - keptB
            }
            // Accents and case aside, so Á files under A as the index does.
            return a.name.localeCompare(b.name, undefined, { sensitivity: "base" })
        })
        return found
    }

    function calculate(expression: string): var {
        if (expression === "" || !root.arithmetic.test(expression))
            return []
        const value = root.evaluate(expression)
        if (value === null)
            return []
        return [{
            kind: "calculation", id: "", icon: "󰃬",
            name: `${value}`, subtitle: Tr.t("%1  ·  Enter copies it").arg(expression)
        }]
    }

    // ── DESK MODE ───────────────────────────────────────────────────────────
    //
    // The `>` list: the control centre's doors, the other launcher modes, and
    // the one-shot tiles (`closes`). Stateful toggles are left out since a
    // list row cannot show their state, as are the launcher itself and
    // anything unavailable. Matches on label and subtitle.
    function desk(term: string): var {
        const lead = []
        const rest = []

        function offer(entry) {
            if (term === "") {
                rest.push(entry)
                return
            }
            const name = entry.name.toLowerCase()
            if (name.startsWith(term))
                lead.push(entry)
            else if (name.includes(term) || entry.subtitle.toLowerCase().includes(term))
                rest.push(entry)
        }

        for (const door of ControlsService.doors) {
            if (door.id === "launcher")
                continue
            offer({
                kind: "panel", id: door.id, icon: door.icon,
                name: door.label, subtitle: door.detail, panel: door.panel
            })
        }

        for (const mode of root.modes) {
            // Skip the current mode and the plain-text one.
            if (mode.id === "desk" || mode.prefix === "")
                continue
            // Not advertised while history is off; the sigil still works.
            if (mode.id === "clipboard" && !SettingsService.clipboardHistory)
                continue
            offer({
                kind: "mode", id: mode.id, icon: mode.icon,
                name: mode.label, subtitle: mode.hint, sigil: mode.prefix
            })
        }

        // Indexed: `toggleCatalogue` is a QML list, not a JS array.
        for (let index = 0; index < ControlsService.toggleCatalogue.length; index++) {
            const tile = ControlsService.toggleCatalogue[index]
            if (!tile.closes || !tile.available)
                continue
            offer({
                kind: "action", id: tile.key, icon: tile.icon,
                name: tile.label, subtitle: tile.detail
            })
        }

        // Not truncated to `maxResults`: the list is short, and cutting it
        // would hide the actions behind the doors. The panel still caps its
        // visible height; the rest scrolls.
        return lead.concat(rest)
    }

    function timer(text: string): var {
        const milliseconds = TimerService.parse(text)
        if (milliseconds <= 0)
            return []
        return [{
            kind: "timer", id: "", icon: "󰔟",
            name: Tr.t("Start a %1 timer").arg(root.spell(milliseconds)),
            subtitle: Tr.t("Counts down on the island"),
            milliseconds: milliseconds
        }]
    }

    // Clipboard history, newest first (ordering is `ClipboardService`'s).
    function clipboard(term: string): var {
        const found = []
        for (const entry of ClipboardService.search(term, root.maxResults)) {
            found.push({
                kind: "clip", id: entry.key, icon: "󰅍",
                name: ClipboardService.title(entry),
                subtitle: ClipboardService.describe(entry),
                // Images show a thumbnail instead of a glyph, and can be
                // opened in imv.
                picture: entry.kind === "image" ? `file://${entry.file}` : "",
                file: entry.kind === "image" ? entry.file : ""
            })
        }
        return found
    }

    // Recent picks first when the term is empty; the glyph, in the chosen
    // skin tone, is the whole cell, and the name is only searched. Not cut to
    // `maxResults`: a group is browsed as much as searched, and the list only
    // builds the cells in view.
    function emoji(term: string): var {
        return EmojiService.search(term).map(item => ({
            kind: "emoji", id: item.glyph, icon: "", item: item,
            glyph: EmojiService.glyphOf(item), name: item.name, subtitle: ""
        }))
    }

    // Open windows filtered by title or class. The client list is loaded when
    // the launcher opens.
    function windows(term: string): var {
        const found = []
        for (const client of HyprlandService.clients) {
            if (found.length >= root.maxResults)
                break
            const title = (client.title ?? "").toLowerCase()
            const cls = (client.class ?? "").toLowerCase()
            if (term !== "" && !title.includes(term) && !cls.includes(term))
                continue
            found.push({
                kind: "window", id: client.address, icon: "󰖯",
                name: client.title || client.class,
                subtitle: Tr.t("%1  ·  workspace %2").arg(client.class).arg(client.workspace.id)
            })
        }
        return found
    }

    function spell(milliseconds: real): string {
        const total = Math.round(milliseconds / 1000)
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const seconds = total % 60
        const parts = []
        if (hours > 0) parts.push(`${hours}h`)
        if (minutes > 0) parts.push(`${minutes}m`)
        if (seconds > 0) parts.push(`${seconds}s`)
        return parts.join(" ") || "0s"
    }

    function evaluate(expression: string): var {
        try {
            const value = Function(`"use strict"; return (${expression})`)()
            return Number.isFinite(value) ? value : null
        } catch (error) {
            return null
        }
    }

    function activate(entry: var): void {
        if (!entry)
            return
        if (entry.kind === "app") {
            // Recorded here, not in `launchDesktop`, so dock launches do not
            // count towards the ranking.
            root.record(entry.id)
            root.launchDesktop(entry.id)
        }
        else if (entry.kind === "action") {
            const tile = ControlsService.tileOf(entry.id)
            if (tile)
                tile.activate()
        }
        else if (entry.kind === "timer")
            TimerService.start(entry.milliseconds, entry.subtitle ?? "")
        else if (entry.kind === "window")
            HyprlandService.focusWindow(entry.id)
        else if (entry.kind === "calculation")
            root.copy(entry.name)
        else if (entry.kind === "clip")
            ClipboardService.copy(entry.id)
        else if (entry.kind === "emoji")
            EmojiService.copy(entry.item)
        else if (entry.kind === "command")
            Quickshell.execDetached(entry.argv)
        // `panel` and `mode` entries are handled by the launcher panel: the
        // service does not know about the island, and a mode row keeps the
        // launcher open.
    }

    function copy(text: string): void {
        Quickshell.execDetached(["wl-copy", "--", text])
    }

    function launchDesktop(desktopId: string): void {
        if (!desktopId)
            return
        Quickshell.execDetached(["gtk-launch", desktopId])
    }
}
