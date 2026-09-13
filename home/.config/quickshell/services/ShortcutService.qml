// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S H O R T C U T   S E R V I C E                                        │
// │   keybindings per profile · reading and rebinding                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Keys belong to the profile: the `keys` setting maps each bind description
// in `hypr/keybinds.lua` to a combination, so switching profile switches the
// compositor's binds as well as the shell's.
//
// The Lua config cannot read the settings, so the active profile's keys are
// written to `keys.tsv` in the state directory and Hyprland is reloaded.
// Rebinding over `hyprctl eval` is not an option: Lua binds show up in
// `hyprctl binds` as `__lua`, so their actions cannot be read back.
//
// The description is the only field that survives into `hyprctl binds`, so it
// is the key on both sides.
Singleton {
    id: root

    // The shell's shortcuts, in settings order.
    //
    //   name         what shell.qml registers and the dispatcher names
    //   label        display name
    //   description  as written in keybinds.lua; must match exactly
    readonly property var catalogue: [
        { name: "launcher",       label: "Launcher",             description: "Shell · Open the launcher" },
        { name: "controls",       label: "Control centre",       description: "Shell · Open the control centre" },
        { name: "overview",       label: "Workspace overview",   description: "Shell · Open the workspace overview" },
        { name: "settings",       label: "Settings",             description: "Shell · Open settings" },
        { name: "appearance",     label: "Appearance",           description: "Shell · Open appearance" },
        { name: "palette",        label: "Palette",              description: "Shell · Open the palette" },
        { name: "stats",          label: "System statistics",    description: "Shell · Open system statistics" },
        { name: "session",        label: "Session menu",         description: "Session · Session menu" },
        { name: "lock",           label: "Lock the screen",      description: "Session · Lock the screen" },
        { name: "pet",            label: "Pet",                  description: "Shell · Open the pet" },
        { name: "games",          label: "Games",                description: "Shell · Open the games" },
        { name: "notes",          label: "Notes",                description: "Shell · Open the notes" },
        { name: "board",          label: "Task board",           description: "Shell · Open the task board" },
        { name: "keys",           label: "Keys",                 description: "Shell · Show every key" },
        { name: "packages",       label: "Packages",             description: "Shell · Open the packages" },
        { name: "clipboard",      label: "Clipboard history",    description: "Shell · Open the clipboard history" },
        { name: "picker",         label: "Colour picker",        description: "Shell · Pick a colour off the screen" },
        { name: "capture",        label: "Capture",              description: "Shell · Open the capture surface" },
        { name: "captureRegion",  label: "Capture a region",     description: "Shell · Capture a region" },
        { name: "captureWindow",  label: "Capture a window",     description: "Shell · Capture a window" },
        { name: "captureScreen",  label: "Capture the screen",   description: "Shell · Capture the whole screen" },
        { name: "captureEdit",    label: "Capture and annotate", description: "Shell · Capture a region and annotate it" },
        { name: "captureText",    label: "Read a region",        description: "Shell · Read a region as text" },
        { name: "record",         label: "Record the screen",    description: "Shell · Start or stop recording the screen" }
    ]

    readonly property var keys: SettingsService.keys

    // ── TABLE ───────────────────────────────────────────────────────────────
    //
    // Every bind with the profile's combination: the compositor's in config
    // order, then unbound shell shortcuts, then any other unbound keys the
    // profile names (Hyprland does not list unbound binds). Switches are left
    // out. The profile's value wins, so a row updates before the reload lands.
    readonly property var table: {
        const kept = root.keys ?? ({})
        const rows = []
        const seen = ({})
        const add = (description, bound) => {
            if (description === "" || seen[description])
                return
            seen[description] = true
            const own = kept[description]
            rows.push({
                description: description,
                combination: typeof own === "string" ? own : bound
            })
        }
        for (const bind of HyprlandService.binds) {
            if (!(bind.key || "").startsWith("switch:"))
                add(bind.description ?? "", HyprlandService.spell(bind))
        }
        for (const item of root.catalogue)
            add(item.description, "")
        for (const description in kept)
            add(description, "")
        return rows
    }

    readonly property var index: {
        const out = ({})
        for (const row of root.table)
            out[row.description] = row
        return out
    }

    // In `hl.bind` syntax. Empty when unbound or before the bind list is read.
    function current(description: string): string {
        return root.index[description]?.combination ?? ""
    }

    // Mouse binds are shown but not editable; the editor records key presses.
    function fixed(description: string): bool {
        return root.current(description).includes("mouse")
    }

    // Hyprland accepts duplicate binds (both fire), so check beforehand.
    function clash(combination: string, exclude: string): string {
        const wanted = combination.toUpperCase()
        const other = root.table.find(row => row.description !== exclude
            && row.combination !== "" && row.combination.toUpperCase() === wanted)
        if (!other)
            return ""
        const split = other.description.indexOf(" · ")
        return split < 0 ? other.description : other.description.slice(split + 3)
    }

    // Writes the whole table, since a profile built from defaults has no keys
    // stored yet. Refused until the bind list has been read.
    function rebind(description: string, combination: string): void {
        if (combination === "" || !root.index[description]
                || HyprlandService.binds.length === 0)
            return
        const next = ({})
        for (const row of root.table)
            next[row.description] = row.description === description
                ? combination : row.combination
        SettingsService.set("keys", next)
    }

    // ── KEYS.TSV ────────────────────────────────────────────────────────────
    //
    // `description<TAB>combination` per line, since the Lua config cannot
    // parse JSON. Empty for a profile with no keys of its own.
    readonly property string keysHeader:
        "# The keys of the profile in use: a bind's description, a tab, and its\n"
        + "# combination, empty for none. Written by the shell from Settings → Keys\n"
        + "# and read by hypr/modules/keybinds.lua, so an edit here is overwritten.\n"

    function flat(text: string): string {
        return String(text).replace(/[\t\r\n]+/g, " ").trim()
    }

    readonly property string keysText: {
        const kept = root.keys ?? ({})
        const lines = []
        for (const description in kept) {
            if (typeof kept[description] === "string")
                lines.push(`${root.flat(description)}\t${root.flat(kept[description])}`)
        }
        return lines.length === 0 ? "" : root.keysHeader + lines.join("\n") + "\n"
    }

    onKeysTextChanged: root.writeKeys()

    // Only once both files are read and they differ, so a normal login
    // writes and reloads nothing.
    function writeKeys(): void {
        if (!SettingsService.arrived || !root.keysFile.known)
            return
        if (root.keysFile.says === root.keysText)
            return
        root.keysFile.says = root.keysText
        root.keysFile.setText(root.keysText)
    }

    readonly property FileView keysFile: FileView {
        property bool known: false
        property string says: ""

        path: `${SettingsService.stateDirectory}/keys.tsv`
        printErrors: false

        // Deferred: a save started from inside the load handler writes the
        // file but never emits `saved`, so Hyprland would not reload.
        onLoaded: {
            says = text()
            known = true
            Qt.callLater(root.writeKeys)
        }
        onLoadFailed: {
            says = ""
            known = true
            Qt.callLater(root.writeKeys)
        }
        onSaved: root.reloader.running = true
        onSaveFailed: error => console.warn("The keys could not be written:", error)
    }

    readonly property Process reloader: Process {
        command: ["hyprctl", "reload"]
        onExited: HyprlandService.loadBinds()
    }

    readonly property Connections settingsArrive: Connections {
        target: SettingsService

        function onArrivedChanged(): void {
            root.writeKeys()
        }
    }

    // ── KEY NAMES ───────────────────────────────────────────────────────────
    //
    // Qt key codes to xkb names, written out because xkb's punctuation names
    // (`comma`, `bracketleft`) cannot be derived. Modifiers map to "": they
    // are picked as chips, and one held on the way to the real key is ignored.
    readonly property var keyNames: ({
        [Qt.Key_Space]: "space",
        [Qt.Key_Tab]: "TAB",
        [Qt.Key_Return]: "Return",
        [Qt.Key_Enter]: "Return",
        [Qt.Key_Escape]: "Escape",
        [Qt.Key_Backspace]: "BackSpace",
        [Qt.Key_Delete]: "Delete",
        [Qt.Key_Insert]: "Insert",
        [Qt.Key_Home]: "Home",
        [Qt.Key_End]: "End",
        [Qt.Key_PageUp]: "Prior",
        [Qt.Key_PageDown]: "Next",
        [Qt.Key_Left]: "Left",
        [Qt.Key_Right]: "Right",
        [Qt.Key_Up]: "Up",
        [Qt.Key_Down]: "Down",
        [Qt.Key_Print]: "Print",
        [Qt.Key_Comma]: "comma",
        [Qt.Key_Period]: "period",
        [Qt.Key_Slash]: "slash",
        [Qt.Key_Backslash]: "backslash",
        [Qt.Key_Minus]: "minus",
        [Qt.Key_Equal]: "equal",
        [Qt.Key_Semicolon]: "semicolon",
        [Qt.Key_Apostrophe]: "apostrophe",
        [Qt.Key_QuoteLeft]: "grave",
        [Qt.Key_BracketLeft]: "bracketleft",
        [Qt.Key_BracketRight]: "bracketright"
    })

    function keyName(code: int): string {
        if (code >= Qt.Key_A && code <= Qt.Key_Z)
            return String.fromCharCode(65 + code - Qt.Key_A)
        if (code >= Qt.Key_0 && code <= Qt.Key_9)
            return String.fromCharCode(48 + code - Qt.Key_0)
        if (code >= Qt.Key_F1 && code <= Qt.Key_F12)
            return `F${code - Qt.Key_F1 + 1}`
        return root.keyNames[code] ?? ""
    }

    // ── KEY SHEET ───────────────────────────────────────────────────────────
    //
    // The keys panel: everything bound right now, from `hyprctl binds`.
    // Binds sharing a category, modifiers and description up to a trailing
    // number or direction are folded into one row. Switches are left out.

    // Unlisted categories follow, in config order.
    readonly property var sheetOrder: ["Shell", "Applications", "Windows", "Workspaces",
                                       "Session", "Utilities", "Media"]

    readonly property var modifierCaps: [
        { bit: 64, cap: "Super" },
        { bit: 4,  cap: "Ctrl" },
        { bit: 8,  cap: "Alt" },
        { bit: 1,  cap: "Shift" }
    ]

    // Keycap labels where the xkb name will not do. Arrows come from the icon
    // font: the interface font lacks them and falls back to colour emoji.
    readonly property var keyCaps: ({
        left: "󰁍", right: "󰁔", up: "󰁝", down: "󰁅",
        TAB: "Tab", Return: "Enter", space: "Space", Escape: "Esc",
        comma: ",", period: ".", slash: "/", minus: "-", equal: "=",
        "mouse:272": "Left button", "mouse:273": "Right button",
        mouse_down: "Wheel down", mouse_up: "Wheel up",
        XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −",
        XF86AudioMute: "Mute", XF86AudioMicMute: "Mic mute",
        XF86MonBrightnessUp: "Bright +", XF86MonBrightnessDown: "Bright −",
        XF86AudioPlay: "Play", XF86AudioNext: "Next", XF86AudioPrev: "Previous"
    })

    function capOf(key: string): string {
        if (root.keyCaps[key] !== undefined)
            return root.keyCaps[key]
        return key.startsWith("XF86") ? key.slice(4) : key
    }

    readonly property var sheet: {
        const groups = ({})
        const order = []
        for (const bind of HyprlandService.binds) {
            const key = bind.key || ""
            if (key === "" || key.startsWith("switch:"))
                continue
            const text = bind.description ?? ""
            const split = text.indexOf(" · ")
            const category = split < 0 ? "Other" : text.slice(0, split)
            const action = split < 0 ? (text || key) : text.slice(split + 3)

            // A trailing number or direction, which varies within a fold.
            const folded = action.match(/^(.*) (\d+|left|right|up|down)$/)
            const base = folded ? folded[1] : action
            const kind = !folded ? "" : (/^\d+$/.test(folded[2]) ? "digits" : "words")

            if (!groups[category]) {
                groups[category] = []
                order.push(category)
            }
            const rows = groups[category]
            const same = kind === "" ? null : rows.find(row => row.base === base
                && row.kind === kind && row.modmask === bind.modmask)
            if (same) {
                same.keys.push(key)
                continue
            }
            rows.push({ base: base, action: action, kind: kind,
                        modmask: bind.modmask, keys: [key] })
        }

        const ranked = order.slice().sort((a, b) => {
            const ia = root.sheetOrder.indexOf(a)
            const ib = root.sheetOrder.indexOf(b)
            return (ia < 0 ? 99 + order.indexOf(a) : ia) - (ib < 0 ? 99 + order.indexOf(b) : ib)
        })

        return ranked.map(category => ({
            name: category,
            rows: groups[category].map(row => {
                const caps = root.modifierCaps
                    .filter(modifier => row.modmask & modifier.bit)
                    .map(modifier => modifier.cap)
                const many = row.keys.length > 1
                if (many && row.kind === "digits")
                    caps.push(`${row.keys[0]}…${row.keys[row.keys.length - 1]}`)
                else
                    for (const key of row.keys)
                        caps.push(root.capOf(key))
                return { action: many ? row.base : row.action, caps: caps, keys: row.keys }
            })
        }))
    }

    readonly property int sheetCount: root.sheet.reduce((sum, group) => sum + group.rows.length, 0)

    // What a search term can start with: the words of the action and its
    // group, the caps, and the xkb names behind them (Return for Enter, each
    // digit of a folded run).
    function sheetWords(group: var, row: var): var {
        const words = `${group.name} ${row.action} ${row.caps.join(" ")} ${row.keys.join(" ")}`
            .toLowerCase().split(/[^a-z0-9]+/)
        for (const key of row.keys)
            words.push(key.toLowerCase())
        return words.filter(word => word !== "")
    }

    // The sheet as one list, headings between groups, keeping the rows every
    // term of `query` begins a word of. Terms split on spaces and on `+`.
    function sheetFind(query: string): var {
        const terms = query.toLowerCase().split(/[\s+]+/).filter(term => term !== "")
        const out = []
        for (const group of root.sheet) {
            const rows = group.rows.filter(row => {
                const words = root.sheetWords(group, row)
                return terms.every(term => words.some(word => word.startsWith(term)))
            })
            if (rows.length === 0)
                continue
            out.push({ heading: true, name: group.name })
            for (const row of rows)
                out.push({ heading: false, action: row.action, caps: row.caps })
        }
        return out
    }

    // Declared for the island: a field over a list that scrolls.
    readonly property int sheetWidth: 620
    readonly property int sheetHeight: 600
    readonly property int sheetFieldHeight: 36
    readonly property int sheetRowHeight: 36
    readonly property int sheetHeadingHeight: 32

    // ── RELOAD ──────────────────────────────────────────────────────────────

    // Touched from `shell.qml` so it exists from boot and can write the keys
    // of a profile switched to before settings is opened.
    Component.onCompleted: HyprlandService.loadBinds()

    // Every reload rebinds (this service, a profile switch, Reset).
    readonly property Connections reloads: Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "configreloaded")
                root.settle.restart()
        }
    }

    // The bind list is stale immediately after a reload.
    readonly property Timer settle: Timer {
        interval: 400
        onTriggered: HyprlandService.loadBinds()
    }
}
