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
                   ...root.named.map(workspace => workspace.id))
        : root.maximum

    property int activeId: 1
    property var occupiedIds: []

    // Every workspace as hyprctl lists it, for the name an event carries.
    property var named: []

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

    // The special workspace open on a screen (`special:name`), or "" when none
    // is, or the screen is unknown. From the monitor list the events keep.
    function specialOn(monitorName: string): string {
        const monitor = root.monitors.find(candidate => candidate.name === monitorName)
        return monitor?.specialWorkspace?.name ?? ""
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

    // Keep the client list refreshed on every window event, even when it is
    // empty. Without it, refreshes only happen while the list is non-empty,
    // which is fine for the overview but freezes the dock once the last
    // window closes.
    property bool watchClients: false

    // The same for the workspace strip's app icons, kept apart because the
    // dock binds `watchClients` and a second binding would undo its own.
    property bool watchIcons: false
    readonly property bool clientsWanted: root.watchClients || root.watchIcons
    onWatchIconsChanged: {
        if (root.watchIcons)
            root.loadClients()
    }

    // The windows on special workspaces, which `clients` leaves out.
    property var specialClients: []

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
                root.specialClients = list.filter(client => client.mapped
                    && String(client.workspace?.name ?? "").startsWith("special:"))
            }
        }
    }

    function loadClients(): void { root.clientsProcess.running = true }

    readonly property Timer refreshSoon: Timer {
        interval: 30
        onTriggered: {
            root.refresh()
            if (root.clientsWanted || root.clients.length > 0)
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
            // `WORKSPACEID,WORKSPACENAME,MONITORNAME`: a whole workspace has
            // gone to another screen, so both screens are showing something
            // else now. A screen plugged in is showing one from the start.
            // `activespecial` (`NAME,MONITOR`, the name empty when it closes)
            // changes what a screen shows in the same way.
            case "moveworkspace":
            case "moveworkspacev2":
            case "activespecial":
            case "monitoradded":
            case "monitoraddedv2":
                root.loadMonitors()
                root.refresh()
                break
            // Focus changes only affect the client list, and only watchers
            // need it; skipping it otherwise saves a process per alt-tab.
            case "activewindow":
                root.focusedClass = event.data.split(",")[0]
                break
            case "activewindowv2":
                root.focusedAddress = event.data === "" ? "" : `0x${event.data}`
                if (root.clientsWanted)
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
