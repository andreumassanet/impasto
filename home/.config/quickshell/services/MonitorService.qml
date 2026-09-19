// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O N I T O R   S E R V I C E                                          │
// │   monitors · saved layouts per set of connected screens                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Connected monitors, and the arrangement saved for each set of them.
//
// As with CompositorService, nothing writes to `hypr/*.lua`: the Lua config is
// the fallback, and the user's arrangement lives in the shell's settings and
// is pushed again whenever Hyprland loses it (see `scripts/monitors.py`).
//
// An arrangement is keyed by the set of monitors present, lit or not, so the
// right one comes back by itself on hotplug; a shut lid is the same profile
// with one screen disabled. Monitors are identified by description (make,
// model, serial), which is also what Hyprland's `desc:` matches; connector
// names change between ports.
//
// A profile with no saved arrangement is left to Hyprland's `auto`, so on a
// fresh install this service pushes nothing.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/monitors.py")

    // Every screen plugged in, lit or not, in the shape `monitors.py` returns.
    property var monitors: []
    property bool loaded: false

    readonly property Process reader: Process {
        command: [root.script, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    root.monitors = JSON.parse(text)
                    root.loaded = true
                } catch (error) {
                    console.warn("Cannot parse the monitors:", error)
                    return
                }
                if (root.recover())
                    return
                root.applyProfile()
                // Only after a change: an empty workspace at login is normal.
                if (root.disturbed) {
                    root.disturbed = false
                    root.rescue()
                }
            }
        }
    }

    function load(): void {
        root.reader.running = true
    }

    function monitorFor(description: string): var {
        return root.monitors.find(monitor => monitor.description === description) ?? null
    }

    // The other way round, for anything that starts from a `ShellScreen`.
    // Empty when the connector is not plugged in.
    function descriptionFor(name: string): string {
        return root.monitors.find(monitor => monitor.name === name)?.description ?? ""
    }


    // ── PROFILE KEY ─────────────────────────────────────────────────────────
    //
    // Descriptions sorted, so the key does not depend on enumeration order.

    readonly property string profile: root.monitors
        .map(monitor => monitor.description)
        .sort()
        .join(" · ")

    readonly property var store: SettingsService.displays

    readonly property var arrangement: (root.store ?? ({}))[root.profile] ?? null

    readonly property bool arranged: root.arrangement !== null

    // ── MIRRORING ───────────────────────────────────────────────────────────
    //
    // Stored per arrangement, not per monitor, and only as intent: the output
    // to mirror is resolved from the primary when the rule is built.
    readonly property bool mirroring: root.arrangement?.mirror === true


    // ── PRIMARY SCREEN ──────────────────────────────────────────────────────
    //
    // The shell's notion, not Hyprland's: the screen that carries the island,
    // the widgets and the note deck. Stored by description, matched to a
    // `ShellScreen` by connector name. Falls back to the first screen, which
    // also covers a primary that was just disabled, since disabled outputs
    // drop out of `Quickshell.screens`.

    readonly property string primaryDescription: root.arrangement?.primary ?? ""

    readonly property string primaryName: {
        const wanted = root.monitorFor(root.primaryDescription)
        return (wanted && !wanted.disabled) ? wanted.name : ""
    }

    readonly property var primaryScreen: {
        const screens = Quickshell.screens
        return screens.find(screen => screen.name === root.primaryName)
            ?? screens[0]
            ?? null
    }

    // For rules: unlike `primaryName`, set even when no primary was chosen.
    readonly property string effectivePrimaryName: root.primaryScreen?.name ?? ""

    // By name: a `ShellScreen` is recreated across a hotplug.
    function isPrimary(screen: var): bool {
        const chosen = root.primaryScreen
        return !!screen && !!chosen && screen.name === chosen.name
    }


    // ── STORE ───────────────────────────────────────────────────────────────
    //
    // `SettingsService.displays` maps profile key to arrangement. The field
    // whitelist lives in `monitors.py`, which rejects anything else before it
    // reaches `hyprctl eval`.

    function ruleFor(description: string): var {
        return (root.arrangement?.monitors ?? ({}))[description] ?? null
    }

    // The stored rule plus mirroring. A mirrored screen gets no position,
    // which Hyprland would ignore, so `differs` never compares one.
    function effectiveRule(description: string): var {
        const kept = root.ruleFor(description)
        if (!kept)
            return null
        const rule = Object.assign({}, kept)
        const found = root.monitorFor(description)
        const primary = root.effectivePrimaryName
        if (root.mirroring && primary && found && found.name !== primary) {
            rule.mirror = primary
            delete rule.position
        } else {
            rule.mirror = "none"
        }
        return rule
    }

    // Controls only write the store; `onStoreChanged` pushes, so there is a
    // single path to the compositor.
    function remember(description: string, fields: var): void {
        const kept = Object.assign({}, root.store ?? ({}))
        const profile = Object.assign({ primary: "", monitors: ({}) },
                                      kept[root.profile] ?? ({}))
        const screens = Object.assign({}, profile.monitors ?? ({}))
        screens[description] = Object.assign({}, screens[description] ?? ({}), fields)
        profile.monitors = screens
        kept[root.profile] = profile
        SettingsService.set("displays", kept)
    }

    function rememberMirror(on: bool): void {
        const kept = Object.assign({}, root.store ?? ({}))
        const profile = Object.assign({ primary: "", mirror: false, monitors: ({}) },
                                      kept[root.profile] ?? ({}))
        profile.mirror = on
        kept[root.profile] = profile
        SettingsService.set("displays", kept)
    }

    function rememberPrimary(description: string): void {
        const kept = Object.assign({}, root.store ?? ({}))
        const profile = Object.assign({ primary: "", monitors: ({}) },
                                      kept[root.profile] ?? ({}))
        profile.primary = description
        kept[root.profile] = profile
        SettingsService.set("displays", kept)
    }

    // Also reloads the config: Hyprland keeps whatever was last pushed.
    function forget(): void {
        const kept = Object.assign({}, root.store ?? ({}))
        delete kept[root.profile]
        SettingsService.set("displays", kept)
        root.reloader.running = true
    }

    readonly property Process reloader: Process {
        command: ["hyprctl", "reload"]
        onExited: root.load()
    }


    // ── APPLYING ────────────────────────────────────────────────────────────

    // Coalesces canvas drags and the settings file loading (one change per
    // key).
    onStoreChanged: root.pushSoon.restart()

    readonly property Timer pushSoon: Timer {
        interval: 120
        onTriggered: root.applyProfile()
    }

    // Only rules that disagree with the current state are sent. This is also
    // the loop guard: enabling a screen fires `monitoradded`, which re-reads
    // and then finds nothing left to change.
    function differs(description: string, rule: var): bool {
        const found = root.monitorFor(description)
        if (!found)
            return false
        // Only when the rule sets it. A rule without `disabled` must not force
        // the laptop panel back on right after the lid closes.
        if (rule.disabled !== undefined && rule.disabled !== found.disabled)
            return true
        if (found.disabled)
            return false
        return (rule.mode !== undefined && rule.mode !== found.mode)
            || (rule.position !== undefined && rule.position !== found.position)
            || (rule.scale !== undefined && Number(rule.scale) !== Number(found.scale))
            || (rule.transform !== undefined && Number(rule.transform) !== Number(found.transform))
            || (rule.mirror !== undefined && rule.mirror !== found.mirror)
            || (rule.vrr !== undefined && Number(rule.vrr) !== Number(found.vrr))
    }

    function applyProfile(): void {
        if (!root.loaded || root.settling.running)
            return
        const screens = root.arrangement?.monitors ?? ({})
        const rules = []
        for (const description in screens) {
            const rule = root.effectiveRule(description)
            if (!rule || !root.differs(description, rule))
                continue
            rules.push(Object.assign({}, rule, { output: `desc:${description}` }))
        }
        if (rules.length === 0)
            return
        root.settling.restart()
        root.applier.command = [root.script, "apply", JSON.stringify(rules)]
        root.applier.running = true
    }

    // ── RECOVERY ────────────────────────────────────────────────────────────
    //
    // Never leave the machine with no lit screen. Unplugging lands on a
    // different profile key, possibly one never arranged, so a panel disabled
    // under the previous profile stays off. Hyprland only falls back to
    // enabled monitors, and with no output there is no shell to fix it from.
    //
    // Runs after every read, and is deliberately narrow: if nothing present
    // is lit, light everything. A dark screen beside a lit one is left alone,
    // since the lid does exactly that.
    function recover(): bool {
        if (!root.loaded || root.monitors.length === 0)
            return false
        if (root.monitors.some(monitor => !monitor.disabled))
            return false
        const rules = root.monitors.map(monitor => ({
            output: `desc:${monitor.description}`,
            disabled: false,
            mode: "preferred",
            position: "auto",
            scale: 1
        }))
        console.warn("No screen is lit — putting them all back on.")
        root.settling.restart()
        root.applier.command = [root.script, "apply", JSON.stringify(rules)]
        root.applier.running = true
        return true
    }


    // ── WORKSPACES ──────────────────────────────────────────────────────────
    //
    // Hyprland moves workspaces off a removed screen but never moves them
    // back (upstream's choice). This fixes two cases: workspaces with windows
    // stranded on a dark or missing output, and a lit screen showing an empty
    // workspace while its windows sit on another one, e.g. after unplugging
    // breaks a mirror.
    //
    // `hl.dsp.workspace.move`, not `hyprctl dispatch moveworkspacetomonitor`:
    // plain dispatcher names do not resolve with a Lua config.
    readonly property Process workspaces: Process {
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let rows = []
                try {
                    rows = JSON.parse(text)
                } catch (error) {
                    return
                }
                if (!Array.isArray(rows))
                    return
                root.rehome(rows)
            }
        }
    }

    function rehome(rows: var): void {
        const lit = root.monitors.filter(monitor => !monitor.disabled)
        if (lit.length === 0)
            return

        // Back to the primary, where the bar and the widgets are.
        const home = root.effectivePrimaryName !== ""
            ? root.effectivePrimaryName : lit[0].name
        const names = lit.map(monitor => monitor.name)

        // Skip special workspaces: negative ids, owned by whichever monitor
        // shows them, and moving one is an error.
        const real = rows.filter(row => row.id > 0)

        const calls = []
        const stranded = real
            .filter(row => row.windows > 0 && names.indexOf(row.monitor) < 0)
            .sort((a, b) => a.id - b.id)
        for (const row of stranded)
            calls.push(`hl.dispatch(hl.dsp.workspace.move({ workspace = ${row.id}, `
                       + `monitor = "${home}" }))`)

        // Bring forward windows that landed behind another workspace, but
        // only on screens currently showing an empty one.
        for (const monitor of lit) {
            const here = real.filter(row => row.monitor === monitor.name)
            const active = here.find(row => row.id === monitor.workspace)
            if (active && active.windows > 0)
                continue
            const carrying = here.filter(row => row.windows > 0)
                .sort((a, b) => a.id - b.id)
            const wanted = monitor.name === home && stranded.length > 0
                ? stranded[0] : carrying[0]
            // Two calls: `focus` with both a monitor and a workspace reports
            // ok but ignores the workspace. `focus({ workspace })` acts on the
            // focused monitor, so focus that first.
            if (wanted) {
                calls.push(`hl.dispatch(hl.dsp.focus({ monitor = "${monitor.name}" }))`)
                calls.push(`hl.dispatch(hl.dsp.focus({ workspace = ${wanted.id} }))`)
            }
        }

        if (calls.length === 0)
            return
        root.mover.command = ["hyprctl", "eval", calls.join(" ")]
        root.mover.running = true
    }

    readonly property Process mover: Process {}

    // Set when the screens change; cleared by the next read.
    property bool disturbed: false

    function rescue(): void {
        root.workspaces.running = true
    }


    // ── LID ─────────────────────────────────────────────────────────────────
    //
    // The lid bind calls into the shell, which records the panel's state in
    // the current profile, so later pushes agree with the lid instead of
    // undoing it. With no other screen connected nothing is done; logind
    // handles that case.
    readonly property string internalName: {
        const found = root.monitors.find(monitor =>
            monitor.name.startsWith("eDP") || monitor.name.startsWith("LVDS")
            || monitor.name.startsWith("DSI"))
        return found ? found.name : ""
    }

    readonly property var internal: root.monitors.find(
        monitor => monitor.name === root.internalName) ?? null

    function lid(closed: bool): void {
        if (!root.loaded || !root.internal)
            return
        if (SettingsService.lidPolicy === "system")
            return
        const others = root.monitors.filter(
            monitor => monitor.name !== root.internalName)
        if (others.length === 0)
            return
        if (closed && SettingsService.lidPolicy !== "off")
            return
        // Opening always lights the panel, whatever the policy.
        root.remember(root.internal.description, { disabled: closed })
    }

    // Bringing an output up emits a burst of events. Nothing is pushed while
    // this runs; the read at the end sees the settled state.
    readonly property Timer settling: Timer {
        interval: 600
        onTriggered: {
            root.disturbed = true
            root.load()
        }
    }

    readonly property Process applier: Process {}

    // A reload resets monitors to the Lua config and a hotplug may change the
    // profile; either way, re-read and reconcile.
    readonly property Connections events: Connections {
        target: Hyprland

        function onRawEvent(event): void {
            switch (event.name) {
            case "configreloaded":
            case "monitoradded":
            case "monitoraddedv2":
            case "monitorremoved":
            case "monitorremovedv2":
                root.hotplug.restart()
                break
            }
        }
    }

    // One read per burst of events.
    readonly property Timer hotplug: Timer {
        interval: 250
        onTriggered: {
            root.disturbed = true
            root.load()
        }
    }

    Component.onCompleted: root.load()
}
