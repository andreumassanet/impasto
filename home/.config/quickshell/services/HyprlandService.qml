// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   H Y P R L A N D   S E R V I C E                                        │
// │   workspace state · read from hyprctl, refreshed on events               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Workspace state for the bar.
//
// Quickshell 0.3.0 ships an object model for this, but against Hyprland 0.55
// it reports every workspace with id -1 and no monitors at all, so the widget
// built on it can only ever highlight workspace 1. The event socket and
// dispatch do work, so the state is read from hyprctl and refreshed on the
// events that change it — no polling.
QtObject {
    id: root

    // Each screen its own ten, or every screen the same ones.
    readonly property bool perScreen: SettingsService.workspaceMode === "screen"

    // Slots always drawn, so the bar keeps a stable width. Per screen, a
    // screen never reaches into the next one's ten.
    readonly property int slots: Math.min(SettingsService.workspaceCount, root.maximum)
    readonly property int maximum: root.perScreen
        ? Math.min(SettingsService.workspaceMax, 10) : SettingsService.workspaceMax

    // Per screen, the order the tens are dealt in: the main screen first, so
    // it keeps 1–10 whatever else is plugged in, then the rest left to right.
    readonly property var screenOrder: {
        const main = MonitorService.effectivePrimaryName
        const rest = Quickshell.screens
            .filter(screen => screen.name !== main)
            .sort((a, b) => a.x - b.x || a.y - b.y)
            .map(screen => screen.name)
        return main !== "" ? [main].concat(rest) : rest
    }

    // The workspace before a screen's first; 0 when they are shared.
    function baseOn(monitor: string): int {
        return root.perScreen ? Math.max(0, root.screenOrder.indexOf(monitor)) * 10 : 0
    }

    // The number a screen shows a workspace as: its own are numbered from 1,
    // and another screen's keep their id.
    function numberOn(workspaceId: int, monitor: string): int {
        const own = workspaceId - root.baseOn(monitor)
        return own >= 1 && own <= 10 ? own : workspaceId
    }

    // Every workspace a strip may draw on any screen: per screen, every
    // screen's ten, and past them any that outlived its screen.
    readonly property int span: root.perScreen
        ? Math.max(10 * Math.max(1, root.screenOrder.length),
                   ...root.namedIds)
        : root.maximum

    // ── OVERVIEW ────────────────────────────────────────────────────────────
    //
    // The workspaces the overview draws: every screen's ten, one screen after
    // another, so a screen's overview shows the whole desk and a window can be
    // dropped on a workspace of another screen. Shared, the one set.
    readonly property bool manyScreens: root.perScreen && root.screenOrder.length > 1

    // The overview's rows, each a ten: every screen's own, then a further ten
    // for each other block of ten the screen holds a workspace in, occupied or
    // active (a screen on 23, or with windows on 31). Shared, one block of
    // everything.
    //   { screen, base, label }
    readonly property var overviewBlocks: {
        if (!root.perScreen)
            return [{ screen: "", base: 0, label: "" }]
        const screens = root.screenOrder.length > 0 ? root.screenOrder : [""]
        const owned = screens.map((name, at) => at * 10)
        const blocks = []
        for (let at = 0; at < screens.length; at++) {
            const name = screens[at]
            blocks.push({ screen: name, base: owned[at], label: name })
            const extra = []
            const note = id => {
                if (!(id > 0))
                    return
                const base = Math.floor((id - 1) / 10) * 10
                if (owned.indexOf(base) < 0 && extra.indexOf(base) < 0)
                    extra.push(base)
            }
            for (const id of root.occupiedIds) {
                if (root.monitorOf(id) === name)
                    note(id)
            }
            note(root.activeOn(name))
            extra.sort((left, right) => left - right)
            for (const base of extra)
                blocks.push({ screen: name, base: base, label: `${name} · ${base + 1}–${base + 10}` })
        }
        return blocks
    }

    readonly property var overviewIds: {
        const ids = []
        if (!root.perScreen) {
            for (let own = 1; own <= root.maximum; own++)
                ids.push(own)
            return ids
        }
        for (const block of root.overviewBlocks) {
            for (let own = 1; own <= 10; own++)
                ids.push(block.base + own)
        }
        return ids
    }

    // A row to each block, ten wide, once there is more than one block: five
    // wide and two tall for each would not fit a screen.
    readonly property bool manyBlocks: root.perScreen && root.overviewBlocks.length > 1
    readonly property int overviewColumns: root.manyBlocks ? 10 : Math.min(5, root.maximum)
    readonly property int overviewRows: Math.ceil(root.overviewIds.length / Math.max(1, root.overviewColumns))
    readonly property int overviewRowHeight: root.manyBlocks ? 94 : 190
    // Past this many rows the overview scrolls.
    readonly property int overviewRowsShown: root.manyBlocks ? 5 : root.overviewRows
    // The scratchpad tiles: those of Settings → Scratchpads, then any other
    // special workspace that has a window in it.
    // The built-in one on SUPER + Z (`keybinds.lua`) comes first, and is
    // always there to drop a window on.
    readonly property var builtInPad: ({ name: "scratchpad", label: "Scratchpad", glyph: "",
                                         keys: "Super+Z", command: "" })
    readonly property var overviewPads: {
        const configured = [root.builtInPad].concat(Array.from(SettingsService.overviewScratchpads ?? [])
            .filter(pad => pad.name !== root.builtInPad.name))
        const known = configured.map(pad => pad.name)
        const extra = []
        for (const client of root.specialClients) {
            const name = String(client.workspace?.name ?? "").replace(/^special:/, "")
            if (name !== "" && known.indexOf(name) < 0 && extra.indexOf(name) < 0)
                extra.push(name)
        }
        return configured.concat(extra.map(name => ({ name: name, label: name, glyph: "", keys: "", command: "" })))
    }
    // Scratchpad tiles to a row under the workspaces; more go on a new row.
    readonly property int overviewPadsPerRow: 5
    readonly property int overviewPadHeight: 84

    // ── SUPER ───────────────────────────────────────────────────────────────
    //
    // Whether Super is down, and when it went down (0 when nothing is bound to
    // report it). Fed by the `workspaceNumber` shortcut; the workspace strip
    // can show its numbers while it is true, and a quick `superTap` after it
    // can open the launcher.
    property bool superHeld: false
    property real superAt: 0

    property int activeId: 1
    property var occupiedIds: []

    // Every workspace as hyprctl lists it, for the name an event carries.
    property var named: []
    // The ids of the numbered ones. Hyprland 0.57 lists a special workspace
    // with `"id": null` (older ones gave it a negative id), and one such id
    // turns a `Math.max` over them into NaN: the strips drew no slots at all.
    readonly property var namedIds: root.named
        .map(workspace => workspace.id)
        .filter(id => typeof id === "number" && id > 0)

    // The screen with the keyboard, by connector name. Quickshell's own
    // `Hyprland.focusedMonitor` is empty here for the reason its monitor list
    // is, so it comes from the active workspace and from `focusedmon`.
    property string focusedMonitor: ""

    // The workspace each screen is showing, by connector name, so the bar on a
    // screen is about that screen. Seeded from hyprctl and kept up by the
    // events that move a workspace or the keyboard.
    property var activeByMonitor: ({})

    function activeOn(monitor: string): int {
        return root.activeByMonitor[monitor] ?? 0
    }

    function noteActive(monitor: string, workspaceId: int): void {
        if (monitor === "" || workspaceId <= 0 || root.activeByMonitor[monitor] === workspaceId)
            return
        const next = Object.assign({}, root.activeByMonitor)
        next[monitor] = workspaceId
        root.activeByMonitor = next
    }

    function isOccupied(workspaceId: int): bool {
        return root.occupiedIds.indexOf(workspaceId) >= 0
    }

    // The fixed slots, plus any higher workspace that is occupied or active.
    readonly property var visibleIds: {
        const ids = []
        for (let id = 1; id <= root.slots; id++)
            ids.push(id)
        const extra = root.occupiedIds.concat([root.activeId])
        for (const id of extra) {
            if (id > root.slots && id <= root.maximum && ids.indexOf(id) < 0)
                ids.push(id)
        }
        return ids.sort((left, right) => left - right)
    }

    function isVisible(workspaceId: int): bool {
        return root.visibleIds.indexOf(workspaceId) >= 0
    }

    // The same on one screen. Per screen, its own slots, its own others while
    // occupied or active, and another screen's that ended up here, as one
    // does when its screen is unplugged.
    function isVisibleOn(workspaceId: int, monitor: string): bool {
        if (!root.perScreen)
            return root.isVisible(workspaceId)
        const own = workspaceId - root.baseOn(monitor)
        if (own >= 1 && own <= root.slots)
            return true
        const used = root.isOccupied(workspaceId) || root.activeOn(monitor) === workspaceId
        if (own >= 1 && own <= root.maximum)
            return used
        return used && root.monitorOf(workspaceId) === monitor
    }

    // Brings the workspace to the screen being worked on rather than taking
    // the keyboard to the screen it is on, which is what the number keys do
    // (`keybinds.lua`). A dot on a bar and a cell in the overview are both
    // drawn on one screen and mean it.
    function focus(workspaceId: int): void {
        Hyprland.dispatch(
            `hl.dsp.focus({ workspace = ${workspaceId}, on_current_monitor = true })`)
    }

    // The special workspace open over a screen (`special:name`), or "" when
    // none is; the dock's minimized windows are not one.
    function specialOn(monitorName: string): string {
        const monitor = root.monitors.find(candidate => candidate.name === monitorName)
        const name = monitor?.specialWorkspace?.name ?? ""
        return name === root.minimizedWorkspace ? "" : name
    }

    // The windows in a special workspace, by its name.
    function specialClientsOf(name: string): var {
        return root.specialClients.filter(client => client.workspace?.name === name)
    }

    // Whether the overview has anything to show for the special workspaces:
    // one is open on this screen, or some window sits in one.
    function specialShown(monitorName: string): bool {
        return root.specialOn(monitorName) !== "" || root.specialClients.length > 0
    }

    // The screen a workspace is on, or "" for one nobody has made yet.
    function monitorOf(workspaceId: int): string {
        const found = root.named.find(workspace => workspace.id === workspaceId)
        return (found && typeof found.monitor === "string") ? found.monitor : ""
    }

    function refresh(): void {
        root.workspacesProcess.running = true
        root.activeProcess.running = true
    }

    // ── WORKSPACES FILE ─────────────────────────────────────────────────────
    //
    // The number keys are Hyprland's, so the mode and the order are written
    // where `keybinds.lua` reads them on every press: the mode on the first
    // line, then one connector name a line.
    readonly property string screensHeader:
        "# How the number keys reach workspaces: shared, or screen followed by\n"
        + "# the screens in order, ten each. Written by the shell from Settings →\n"
        + "# Displays and read by hypr/modules/keybinds.lua.\n"

    readonly property string screensText: root.screensHeader
        + (root.perScreen ? ["screen"].concat(root.screenOrder).join("\n") : "shared") + "\n"

    onScreensTextChanged: root.writeScreens()

    function writeScreens(): void {
        if (!SettingsService.arrived || !root.screensFile.known)
            return
        if (root.screensFile.says === root.screensText)
            return
        root.screensFile.says = root.screensText
        root.screensFile.setText(root.screensText)
    }

    readonly property FileView screensFile: FileView {
        property bool known: false
        property string says: ""

        path: `${SettingsService.stateDirectory}/workspaces`
        printErrors: false

        onLoaded: {
            says = text()
            known = true
            Qt.callLater(root.writeScreens)
        }
        onLoadFailed: {
            says = ""
            known = true
            Qt.callLater(root.writeScreens)
        }
        onSaveFailed: error => console.warn("The workspaces file could not be written:", error)
    }

    readonly property Connections settingsArrive: Connections {
        target: SettingsService

        function onArrivedChanged(): void {
            root.writeScreens()
        }
    }

    // ── ON DEMAND ───────────────────────────────────────────────────────────
    //
    // Keybindings only matter while the settings window is open, so they are
    // queried when asked for. Monitors are read at start, whenever a workspace
    // moves or a screen arrives, and when the settings window asks.

    property var monitors: []
    property var binds: []

    readonly property Process monitorsProcess: Process {
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.parseJson(text)
                if (!Array.isArray(list))
                    return
                root.monitors = list
                for (const monitor of list)
                    root.noteActive(monitor.name ?? "", monitor.activeWorkspace?.id ?? 0)
            }
        }
    }

    readonly property Process bindsProcess: Process {
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.parseJson(text)
                if (Array.isArray(list))
                    root.binds = list
            }
        }
    }

    // ── WINDOWS ─────────────────────────────────────────────────────────────
    //
    // Wayland toplevels do not carry a workspace, so the list comes from
    // hyprctl and thumbnails from the toplevel, matched on title.

    property var clients: []

    // Windows minimized from the dock wait here, off every strip and
    // overview, and the dock brings them back.
    readonly property string minimizedWorkspace: "special:minimized"
    property var minimizedClients: []

    // The windows on the other special workspaces — the scratchpad and any
    // a user adds — which `clients` leaves out.
    property var specialClients: []

    // Keep the client list refreshed on every window event, even when it is
    // empty. Without it, refreshes only happen while the list is non-empty,
    // which is fine for the overview but freezes the dock once the last
    // window closes.
    property bool watchClients: false

    // Address (`0x…`) of the window with keyboard focus, or "". Not
    // `focusHistoryID == 0`, which stays on the last window after focus moves
    // to an empty workspace. Updated from `activewindowv2`, which sends the
    // address without `0x` and an empty string for no window.
    property string focusedAddress: ""

    // Class of the window with keyboard focus, or "". From `activewindow`,
    // whose data is `class,title`.
    property string focusedClass: ""

    readonly property Process focusedProcess: Process {
        command: ["hyprctl", "activewindow", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const window = root.parseJson(text)
                root.focusedAddress = window && typeof window.address === "string"
                    ? window.address : ""
                root.focusedClass = window && typeof window.class === "string"
                    ? window.class : ""
            }
        }
    }

    readonly property Process clientsProcess: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.parseJson(text)
                if (!Array.isArray(list))
                    return
                root.clients = list.filter(client => client.mapped && client.workspace
                    && client.workspace.id > 0)
                root.minimizedClients = list.filter(client => client.mapped
                    && client.workspace?.name === root.minimizedWorkspace)
                root.specialClients = list.filter(client => {
                    const name = String(client.workspace?.name ?? "")
                    return client.mapped && name.startsWith("special:")
                        && name !== root.minimizedWorkspace
                })
            }
        }
    }

    function loadClients(): void { root.clientsProcess.running = true }

    readonly property Timer refreshSoon: Timer {
        interval: 30
        onTriggered: {
            root.refresh()
            if (root.watchClients || root.clients.length > 0)
                root.loadClients()
        }
    }

    readonly property Timer clientsSoon: Timer {
        interval: 30
        onTriggered: root.loadClients()
    }

    function retitle(data: string): void {
        const comma = data.indexOf(",")
        if (comma < 0)
            return
        const address = `0x${data.slice(0, comma)}`
        const title = data.slice(comma + 1)
        const index = root.clients.findIndex(client => client.address === address)
        if (index < 0 || root.clients[index].title === title)
            return
        const next = root.clients.slice()
        next[index] = Object.assign({}, next[index], { title: title })
        root.clients = next
    }

    function clientsOn(workspaceId: int): var {
        return root.clients.filter(client => client.workspace.id === workspaceId)
    }

    // Shows or hides a special workspace by its name without `special:`.
    function toggleSpecial(name: string): void {
        Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${name}")`)
    }

    // A scratchpad as its key opens it (`keybinds.lua`): its command started
    // on it first when it holds no window, then shown or hidden.
    function toggleScratchpad(name: string, command: string): void {
        if ((command ?? "") !== "" && root.specialClientsOf(`special:${name}`).length === 0)
            Hyprland.dispatch(`hl.dsp.exec_cmd(${JSON.stringify(command)}, { workspace = "special:${name}" })`)
        root.toggleSpecial(name)
    }

    function focusWindow(address: string): void {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${address}" })`)
    }

    function closeWindow(address: string): void {
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${address}" })`)
        root.refresh()
        root.loadClients()
    }

    function toggleFloating(address: string): void {
        Hyprland.dispatch(`hl.dsp.window.float({ window = "address:${address}" })`)
        root.refresh()
        root.loadClients()
    }

    // Swap two specific windows (`target` names the second; plain
    // `swapwindow` only takes a direction).
    //
    // The swap warps the pointer to the moved window, so this runs as a Lua
    // chunk that saves the cursor position, swaps and restores it within one
    // compositor iteration. `cursor:no_warps` is not an option: focus-on-click
    // relies on the warp elsewhere.
    function swapWindows(address: string, target: string): void {
        if (address === target)
            return
        const swap = `hl.dsp.window.swap({ window = "address:${address}", target = "address:${target}" })`
        Hyprland.dispatch(`function() local p = hl.get_cursor_pos() hl.dispatch(${swap})`
            + ` if p then hl.dispatch(hl.dsp.cursor.move({ x = p.x, y = p.y })) end end`)
        root.loadClients()
    }

    // Floating windows only; tiled ones are placed by the layout.
    function moveFloating(address: string, x: int, y: int): void {
        Hyprland.dispatch(`hl.dsp.window.move({ window = "address:${address}", x = ${x}, y = ${y} })`)
        root.loadClients()
    }

    // `follow = false` keeps the view in place. The Lua API accepts
    // `silent = true` but ignores it and switches workspace anyway.
    function moveClient(address: string, workspaceId: int): void {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${workspaceId}, window = "address:${address}", follow = false })`)
        root.refresh()
        root.loadClients()
    }

    // Away to the hidden workspace. Hyprland hands the focus to the next
    // window where it was; focusing that workspace by hand would be the
    // workspace already shown, which goes back to the previous one.
    function minimizeWindow(address: string): void {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${root.minimizedWorkspace}", window = "address:${address}", follow = false })`)
        root.refresh()
        root.loadClients()
    }

    // Back onto the workspace the focused screen is showing, focused.
    function restoreWindow(address: string): void {
        const workspace = root.activeOn(root.focusedMonitor) || root.activeId
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${workspace}, window = "address:${address}", follow = false })`)
        root.focusWindow(address)
        root.refresh()
        root.loadClients()
    }

    // Sends a window to a named workspace (`special:name` for a special one),
    // leaving the view where it is.
    function moveClientToNamed(address: string, workspaceName: string): void {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${workspaceName}", window = "address:${address}", follow = false })`)
        root.refresh()
        root.loadClients()
    }

    // ── BIND NAMES ──────────────────────────────────────────────────────────
    //
    // `hyprctl binds` returns a modifier mask and key; `hl.bind` wants
    // "SUPER + SHIFT + N". The keys page and `ShortcutService` share this so
    // the string passed to `hl.unbind` matches exactly.
    readonly property var modifierNames: [
        { bit: 64, name: "SUPER" },
        { bit: 4,  name: "CTRL" },
        { bit: 8,  name: "ALT" },
        { bit: 1,  name: "SHIFT" }
    ]

    function spell(bind: var): string {
        const parts = []
        for (const modifier of root.modifierNames) {
            if (bind.modmask & modifier.bit)
                parts.push(modifier.name)
        }
        parts.push(bind.key || `code ${bind.keycode}`)
        return parts.join(" + ")
    }

    function loadMonitors(): void { root.monitorsProcess.running = true }

    // The id of a workspace an event names. Hyprland sends the name, which is
    // the number for every workspace nobody has renamed.
    function idNamed(name: string): int {
        const found = root.named.find(workspace => workspace.name === name)
        if (found)
            return found.id
        const number = parseInt(name, 10)
        return isNaN(number) ? 0 : number
    }
    function loadBinds(): void { root.bindsProcess.running = true }

    // One read at start, for the workspace every screen is showing. After it
    // the events keep the map, and the settings window asks again when it
    // wants the full list.
    Component.onCompleted: root.loadMonitors()

    readonly property Process workspacesProcess: Process {
        command: ["hyprctl", "workspaces", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const workspaces = root.parseJson(text)
                if (!Array.isArray(workspaces))
                    return
                root.occupiedIds = workspaces
                    .filter(workspace => workspace.windows > 0)
                    .map(workspace => workspace.id)
                    .filter(id => typeof id === "number" && id > 0)
                root.named = workspaces
            }
        }
    }

    readonly property Process activeProcess: Process {
        command: ["hyprctl", "activeworkspace", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const workspace = root.parseJson(text)
                if (workspace && typeof workspace.id === "number")
                    root.activeId = workspace.id
                if (typeof workspace?.monitor === "string" && workspace.monitor !== "") {
                    root.focusedMonitor = workspace.monitor
                    root.noteActive(workspace.monitor, workspace.id ?? 0)
                }
            }
        }
    }

    readonly property Connections events: Connections {
        target: Hyprland

        function onRawEvent(event): void {
            // Hyprland sends most events twice, plain and v2; only one of
            // each pair is handled, and a burst becomes one query.
            switch (event.name) {
            case "workspacev2":
            case "createworkspacev2":
            case "destroyworkspacev2":
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
                root.refreshSoon.restart()
                break
            // `ADDRESS,TITLE`. A spinner in a terminal's title sends one a
            // second, so the title is written into the list already held
            // rather than asked for again.
            case "windowtitlev2":
                root.retitle(String(event.data))
                break
            // `MONITOR,WORKSPACE`, sent whenever the keyboard changes screen.
            case "focusedmon":
            case "focusedmonv2":
                const moved = String(event.data).split(",")
                root.focusedMonitor = moved[0]
                root.noteActive(moved[0], root.idNamed(moved[1] ?? ""))
                break
            // `NAME,MONITOR`, the name empty when it closes: a special
            // workspace opened over a screen or went away, with its windows.
            case "activespecial":
            case "activespecialv2":
                root.loadMonitors()
                root.loadClients()
                break
            // `WORKSPACEID,WORKSPACENAME,MONITORNAME`: a whole workspace has
            // gone to another screen, so both screens are showing something
            // else now. A screen plugged in is showing one from the start.
            case "moveworkspace":
            case "moveworkspacev2":
            case "monitoradded":
            case "monitoraddedv2":
                root.loadMonitors()
                root.refresh()
                break
            // `1` or `0`: a window went full-screen or came back. The bar
            // and the dock step aside for one, and only the client list
            // says which screen it is on.
            case "fullscreen":
                root.clientsSoon.restart()
                break
            // Focus changes only affect the client list, and only watchers
            // need it; skipping it otherwise saves a process per alt-tab.
            case "activewindow":
                root.focusedClass = event.data.split(",")[0]
                break
            case "activewindowv2":
                root.focusedAddress = event.data === "" ? "" : `0x${event.data}`
                if (root.watchClients)
                    root.clientsSoon.restart()
                break
            }
        }
    }

    function parseJson(text: string): var {
        if (!text || text.trim() === "")
            return null
        try {
            return JSON.parse(text)
        } catch (error) {
            console.warn("Cannot parse the hyprctl response:", error)
            return null
        }
    }
}
