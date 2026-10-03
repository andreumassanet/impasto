// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O M P O S I T O R   S E R V I C E                                    │
// │   hyprland options, for this session                                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import "../theme"

// Hyprland options set from the settings window.
//
// Nothing here writes to `hypr/*.lua`: rewriting a user-edited file would
// fight their edits and drop their comments. Changed options are kept in the
// shell's settings and pushed with `hyprctl` at startup and after every
// `configreloaded`. Options never touched are absent from the store, so the
// Lua config still decides them.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/compositor.py")

    property var options: ({})
    property bool loaded: false

    function value(option: string, fallback: var): var {
        const current = root.options[option]
        return (current === undefined || current === null) ? fallback : current
    }

    readonly property Process reader: Process {
        command: [root.script, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    root.options = JSON.parse(text)
                    root.loaded = true
                } catch (error) {
                    console.warn("Cannot parse the compositor options:", error)
                }
            }
        }
    }

    readonly property Process writer: Process {
        onExited: root.load()
    }

    function load(): void {
        root.reader.running = true
    }

    function set(option: string, value: var): void {
        root.writer.command = [root.script, "set", option, String(value)]
        root.writer.running = true
    }

    // ── STORE ───────────────────────────────────────────────────────────────
    //
    // `SettingsService.compositor`: option path → value, absent if untouched.
    // `compositor.py` owns the whitelist and rejects anything else, which
    // also keeps slider values from turning into arbitrary `hyprctl eval`.

    // A property, so the push fires when the store changes: on the first
    // load of the settings file and after every change.
    readonly property var store: SettingsService.compositor

    onStoreChanged: root.pushSoon.restart()

    // The keyboard's options are a machine setting, so a profile switch keeps
    // them; they are pushed after the profile's store and win over it.
    readonly property var keyboardOptions: [
        "input:kb_layout", "input:kb_variant", "input:kb_model",
        "input:kb_options", "input:kb_rules"
    ]
    readonly property var keyboard: SettingsService.keyboard

    onKeyboardChanged: root.pushSoon.restart()

    // Sliders report every step; debounce so a drag is one push.
    readonly property Timer pushSoon: Timer {
        interval: 120
        onTriggered: root.applyStore()
    }

    function applyStore(): void {
        const kept = Object.assign({}, root.store ?? ({}), root.keyboard ?? ({}))
        if (SettingsService.gameMode)
            kept["decoration:blur:enabled"] = "false"
        if (Object.keys(kept).length === 0) {
            root.load()
            return
        }
        root.applier.command = [root.script, "apply", JSON.stringify(kept)]
        root.applier.running = true
    }

    readonly property Process applier: Process {
        onExited: root.load()
    }

    // Controls only write the store; the push follows from the store change,
    // so live changes and reloads share one path.
    function remember(option: string, value: var): void {
        const key = root.keyboardOptions.indexOf(option) >= 0 ? "keyboard" : "compositor"
        const next = Object.assign({}, (key === "keyboard" ? root.keyboard : root.store) ?? ({}))
        next[option] = String(value)
        SettingsService.set(key, next)
    }

    // Emptying the store doesn't undo what Hyprland already holds, so the
    // config is reloaded to restore its own values.
    function restoreDefaults(): void {
        SettingsService.set("compositor", ({}))
        root.reloader.running = true
    }

    // After a profile switch Hyprland still holds the previous profile's
    // values, including options the new one never sets. A reload clears them,
    // and the reload handler pushes everything again (`reloads`).
    function reassert(): void {
        root.reloader.running = true
    }

    readonly property Process reloader: Process {
        command: ["hyprctl", "reload"]
        onExited: root.load()
    }

    // ── LAYOUT ──────────────────────────────────────────────────────────────
    //
    // How tiled windows are placed, for every workspace at once. It rides the
    // store like any other option; the key cycles it and says which it chose.
    readonly property var windowLayouts: [
        { id: "dwindle",   label: "Dwindle",   icon: "󰕴" },
        { id: "master",    label: "Master",    icon: "󰛾" },
        { id: "scrolling", label: "Scrolling", icon: "󰕬" }
    ]

    // The store first: Hyprland's answer lags a push, and a quick second
    // press would cycle from the old value.
    readonly property string windowLayout:
        root.store?.["general:layout"] ?? root.value("general:layout", "dwindle")

    function cycleLayout(): void {
        const ids = root.windowLayouts.map(entry => entry.id)
        const next = root.windowLayouts[(ids.indexOf(root.windowLayout) + 1) % ids.length]
        root.remember("general:layout", next.id)
        OsdService.requested(next.icon, `${Tr.t("Layout")} · ${Tr.t(next.label)}`, -1)
    }

    // ── GAME MODE ───────────────────────────────────────────────────────────
    //
    // No animations, blur, shadow or glass, each push reading it over its own
    // setting. Turning it off reloads instead: blur nobody has set lives in
    // look.lua, and only a reload reads it back.
    readonly property bool gameMode: SettingsService.gameMode

    onGameModeChanged: {
        if (!root.gameMode) {
            root.reloader.running = true
            return
        }
        root.applyAnimations()
        root.applyShadow()
        root.applyGlass()
        root.applyGround()
        root.applyStore()
    }

    // ── ANIMATIONS ──────────────────────────────────────────────────────────
    //
    // `animations.lua` only enables animations; the preset is pushed from
    // here. One `hyprctl eval` for the whole preset rather than one per leaf,
    // so no window animates on a mix of old and new curves.
    function applyAnimations(): void {
        root.animator.command = ["hyprctl", "eval",
            Motion.chunk(SettingsService.gameMode ? "off" : SettingsService.animationPreset)]
        root.animator.running = true
    }

    readonly property Process animator: Process {}

    onAnimationPresetChanged: root.applyAnimations()


    // ── SHADOW ──────────────────────────────────────────────────────────────
    //
    // Off in `look.lua`; enabled from here. Range and opacity come from
    // `Theme`, so windows and bar capsules cast the same shadow. `render_power`
    // shapes Hyprland's falloff and has no counterpart in the bar's Gaussian.
    //
    // hyprglass renders through the shadow decoration, and this chunk is
    // re-pushed after every reload, so disabling the shadow would also
    // disable the glass. While glass is on, the decoration stays enabled but
    // invisible (range 0, alpha 0).
    function shadowChunk(): string {
        const drawn = SettingsService.windowShadow && !SettingsService.gameMode
        const alpha = drawn ? Math.round(Theme.shadowOpacity * 255)
                                  .toString(16).padStart(2, "0") : "00"
        return `hl.config({ decoration = { shadow = { `
             + `enabled = ${drawn || root.glassOn()}, `
             + `range = ${drawn ? Theme.shadowRange : 0}, render_power = 3, `
             + `color = "rgba(000000${alpha})" } } })`
    }

    function applyShadow(): void {
        root.shadower.command = ["hyprctl", "eval", root.shadowChunk()]
        root.shadower.running = true
    }

    readonly property Process shadower: Process {}

    // Mirrored locally so a change triggers a push.
    readonly property bool windowShadow: SettingsService.windowShadow

    onWindowShadowChanged: root.applyShadow()


    readonly property string animationPreset: SettingsService.animationPreset

    // A reload drops everything pushed at runtime; push it all again.
    readonly property Connections reloads: Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "configreloaded") {
                root.applyAnimations()
                root.applyShadow()
                root.applyStore()
                root.applyCursor()
                root.applyShake()
                root.applyGlass()
                root.applyGround()
            }
        }
    }

    Component.onCompleted: {
        root.applyAnimations()
        root.applyShadow()
        // The settings file loads asynchronously, so the store is usually
        // still empty here and `onStoreChanged` does the real push; this
        // still reads the compositor's current values once.
        root.applyStore()
        // A shell-only restart fires no reload, so push plugin settings here.
        root.applyShake()
        root.applyGlass()
        root.applyGround()
    }

    // ── KEYBOARD LAYOUTS ────────────────────────────────────────────────────
    //
    // Every layout in the xkb rules list. Loaded on demand: only the input
    // page needs it, and the file is ~47 KB.
    property var layouts: []

    function loadLayouts(): void {
        if (root.layouts.length === 0)
            root.layoutReader.running = true
    }

    readonly property Process layoutReader: Process {
        command: [root.script, "layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    root.layouts = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the keyboard layouts:", error)
                }
            }
        }
    }

    function labelForLayout(id: string): string {
        const found = root.layouts.find(entry => entry.id === id)
        return found ? found.label : id
    }

    // xkb group-switch options, passed through by Hyprland. Without one, a
    // second layout is loaded but unreachable.
    readonly property var layoutSwitches: [
        { id: "", label: "None" },
        { id: "grp:alt_shift_toggle", label: "Alt + Shift" },
        { id: "grp:win_space_toggle", label: "Super + Space" },
        { id: "grp:caps_toggle", label: "Caps Lock" }
    ]

    // ── WINDOW RULES ────────────────────────────────────────────────────────
    //
    // Parsed from windowrules.lua for display only; never edited.
    property var windowRules: []

    function loadWindowRules(): void {
        root.rulesReader.running = true
    }

    readonly property Process rulesReader: Process {
        command: [root.script, "rules"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    root.windowRules = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the window rules:", error)
                }
            }
        }
    }

    // ── CURSOR ──────────────────────────────────────────────────────────────
    //
    // One vector cursor, recoloured and compiled by compositor.py and set with
    // `hyprctl setcursor`, which reaches clients as well as the compositor.
    // "palette" tracks the accent; anything else is a fixed `#rrggbb`.
    readonly property string cursorHex:
        SettingsService.cursorColor === "palette"
            ? String(Theme.accent) : SettingsService.cursorColor

    function applyCursor(): void {
        root.cursorSetter.command = [root.script, "cursor",
            root.cursorHex, String(SettingsService.cursorSize)]
        root.cursorSetter.running = true
    }

    readonly property Process cursorSetter: Process {}

    // The accent animates over `paletteTransition`; wait for it to settle
    // instead of recompiling the cursor on every frame.
    readonly property Timer cursorDebounce: Timer {
        interval: 450
        onTriggered: root.applyCursor()
    }

    // Includes the accent, so a palette change re-fires it.
    readonly property string cursorChoice:
        `${root.cursorHex}:${SettingsService.cursorSize}`

    onCursorChoiceChanged: root.cursorDebounce.restart()

    // ── SHAKE TO FIND ─────────────────────────────────────────────────────────
    //
    // hypr-dynamic-cursors' `shake.enabled`. `input.lua` turns it on, so it
    // is pushed on change and after every reload. `shakeAvailable` dims the
    // settings toggle when the plugin isn't loaded.
    property bool shakeAvailable: false

    function loadShake(): void {
        root.shakeReader.running = true
    }

    readonly property Process shakeReader: Process {
        command: [root.script, "available", "plugin:dynamic_cursors:shake:enabled"]
        stdout: StdioCollector {
            onStreamFinished: root.shakeAvailable = text.trim() === "true"
        }
    }

    function applyShake(): void {
        root.shakeSetter.command = ["hyprctl", "eval",
            `hl.config({ plugin = { dynamic_cursors = { shake = { enabled = ${
                SettingsService.shakeToFind ? "true" : "false"} } } } })`]
        root.shakeSetter.running = true
    }

    readonly property Process shakeSetter: Process {}

    onShakeToFindChanged: root.applyShake()

    readonly property bool shakeToFind: SettingsService.shakeToFind


    // ── GLASS ───────────────────────────────────────────────────────────────
    //
    // hyprglass `enabled`: off in `look.lua`, pushed on change and after
    // every reload. The chunk carries its own `hl.plugin.hyprglass` guard,
    // since that table doesn't exist until the plugin loads; the eval is a
    // no-op without the plugin and on the parse before it loads.
    property bool glassAvailable: false

    function loadGlass(): void {
        root.glassReader.running = true
    }

    readonly property Process glassReader: Process {
        command: [root.script, "available", "plugin:hyprglass:enabled"]
        stdout: StdioCollector {
            onStreamFinished: root.glassAvailable = text.trim() === "true"
        }
    }

    function applyGlass(): void {
        root.glassSetter.command = ["hyprctl", "eval",
            `if hl.plugin.hyprglass ~= nil then hl.plugin.hyprglass.config({ enabled = ${
                root.glassOn() ? "true" : "false"} }) end`]
        root.glassSetter.running = true
    }

    readonly property Process glassSetter: Process {}

    readonly property bool windowGlass: SettingsService.windowGlass
    // A function, not a binding: the game mode's handler pushes before a
    // binding on the same change would have caught up.
    function glassOn(): bool {
        return SettingsService.windowGlass && !SettingsService.gameMode
    }

    // Glass depends on the shadow decoration (see `shadowChunk`).
    onWindowGlassChanged: {
        root.applyGlass()
        root.applyShadow()
    }

    // ── THE BAR'S AND THE DOCK'S GROUNDS ────────────────────────────────────
    //
    // A blur behind the bar's layer while its ground lets the screen through
    // (`Theme.islandGround`), and none while it is solid, where it would only
    // reach the shadow round the island. The dock's the same, and also under
    // a classic capsule below full opacity. Named, so a push replaces the
    // last. The alpha floor sits under the thinnest ground and over the empty
    // surface; the shadow's densest band, just outside a shape, is blurred
    // with it, as the edge of a pane blurs what is under it.
    function applyGround(): void {
        root.groundSetter.command = ["hyprctl", "eval",
            `hl.layer_rule({ name = "impasto-bar-blur", match = { namespace = "^(impasto-bar)$" }, blur = true, ignore_alpha = 0.12, enabled = ${
                Theme.solid || SettingsService.gameMode ? "false" : "true"} }) `
            + `hl.layer_rule({ name = "impasto-dock-blur", match = { namespace = "^(impasto-dock)$" }, blur = true, ignore_alpha = 0.12, enabled = ${
                root.dockSeeThrough && !SettingsService.gameMode ? "true" : "false"} })`]
        root.groundSetter.running = true
    }

    readonly property Process groundSetter: Process {}

    readonly property bool solidGround: Theme.solid
    readonly property bool dockSeeThrough: Theme.dockGlass || SettingsService.dockOpacity < 100

    onSolidGroundChanged: root.applyGround()
    onDockSeeThroughChanged: root.applyGround()
}
