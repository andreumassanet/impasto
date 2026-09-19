// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D O C K   S E R V I C E                                                │
// │   dock · pinned and running applications                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQml
import QtQuick
import Quickshell

import "../theme"

// Dock state: pinned applications, running windows, and the geometry.
//
// Pinned entries come first in their saved order, then other running
// applications. A pinned application that is running is a single item, which
// means matching Wayland window classes to desktop entries (below).
//
// ── MATCHING WINDOWS TO DESKTOP ENTRIES ─────────────────────────────────────
//
// `StartupWMClass` is the intended field but many entries lack it, so the
// entry's file id, its last dotted segment, its `Exec` binary and its name
// are also scored, and the highest claim on a class wins. When several entries
// share a `StartupWMClass` (a browser and its web apps), the one whose id
// matches it wins. Unmatched windows are still shown under their class.
Singleton {
    id: root

    // ── SETTINGS ────────────────────────────────────────────────────────────

    readonly property bool enabled: SettingsService.dockEnabled
    readonly property string edge: SettingsService.dockEdge
    readonly property string alignment: SettingsService.dockAlignment
    readonly property bool showsRunning: SettingsService.dockRunning
    readonly property bool autohide: SettingsService.dockAutohide

    // Optional launcher button at the start of the dock, outside the
    // draggable row. It opens the island's launcher.
    readonly property bool hasLauncher: SettingsService.dockLauncher

    // Space the launcher button takes, including its divider.
    readonly property real lead:
        root.hasLauncher ? Theme.dockIcon + 2 * Theme.dockGap : 0

    // Hover index for the launcher button; negative because it is not in
    // `items`.
    readonly property int launcherIndex: -2

    readonly property bool vertical: root.edge !== "bottom"

    // On every screen, or only on the one being worked on. The surface is on
    // every screen either way (`Dock.qml`).
    readonly property bool everywhere: SettingsService.dockEverywhere

    // Whether it is painted on a screen: away under a fullscreen window on
    // that screen alone.
    function shownOn(name: string): bool {
        return root.enabled && (root.count > 0 || root.hasLauncher)
            && root.coveredScreens.indexOf(" " + name + " ") < 0
    }

    // The band the desktop keeps clear of it, since its surface ignores
    // exclusive zones (see `Desktop`). It does not ask where the dock is
    // painting right now — under a fullscreen window, or on a screen the
    // pointer has left — because a grid worked out again would move every
    // widget on it. Windows pass under the dock; widgets never do.
    readonly property int zone: root.enabled && !root.autohide
        && (root.count > 0 || root.hasLauncher)
        ? Theme.dockMargin + Theme.dockThickness : 0

    // ── PINNED ──────────────────────────────────────────────────────────────
    //
    // Kept locally and written to the settings on a debounce. Reading back
    // from the JsonAdapter mid-edit returns a stale value, so consecutive
    // reorders would build on the wrong list.
    property var pinned: SettingsService.dockPinned ?? []

    Connections {
        target: SettingsService

        function onDockPinnedChanged(): void {
            if (saver.running)
                return
            root.pinned = SettingsService.dockPinned ?? []
        }
    }

    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: SettingsService.set("dockPinned", root.pinned)
    }

    function write(next: var): void {
        root.pinned = next
        saver.restart()
    }

    function isPinned(id: string): bool {
        return id !== "" && root.pinned.indexOf(id) >= 0
    }

    function pin(id: string): void {
        if (id === "" || root.isPinned(id))
            return
        root.write(root.pinned.concat([id]))
    }

    function unpin(id: string): void {
        root.write(root.pinned.filter(entry => entry !== id))
    }

    function togglePin(id: string): void {
        if (root.isPinned(id))
            root.unpin(id)
        else
            root.pin(id)
    }

    // `from` and `to` are positions in the pinned list.
    function reorder(from: int, to: int): void {
        if (from < 0 || from >= root.pinned.length || to < 0 || to >= root.pinned.length
                || from === to)
            return
        const next = root.pinned.slice()
        next.splice(to, 0, next.splice(from, 1)[0])
        root.write(next)
    }

    // ── APPLICATION INDEX ───────────────────────────────────────────────────

    readonly property var applications: LauncherService.applications

    function entryOf(id: string): var {
        return root.applications.find(app => app.id === id) ?? null
    }

    // `/usr/bin/foo %U` -> `foo`.
    function binaryOf(exec: string): string {
        const first = (exec ?? "").trim().split(/\s+/)[0] ?? ""
        return first.replace(/"/g, "").split("/").pop()
    }

    // Window class -> best-scoring entry id. Built once from the application
    // list instead of searched on every focus change.
    readonly property var classIndex: {
        const best = ({})
        const claim = (key, id, score) => {
            const normalised = (key ?? "").trim().toLowerCase()
            if (normalised === "")
                return
            const held = best[normalised]
            if (!held || score > held.score)
                best[normalised] = { id: id, score: score }
        }
        for (const app of root.applications) {
            const base = app.id.replace(/\.desktop$/, "")
            const wmclass = app.wmclass ?? ""
            claim(app.name, app.id, 1)
            claim(root.binaryOf(app.exec), app.id, 2)
            // `org.kde.okular` often has the window class `okular`.
            claim(base.split(".").pop(), app.id, 3)
            claim(base, app.id, 4)
            // Bonus when the id matches too: breaks ties between a browser
            // and its web apps.
            claim(wmclass, app.id,
                  wmclass.toLowerCase() === base.toLowerCase() ? 6 : 5)
        }
        return best
    }

    function idFor(windowClass: string): string {
        const key = (windowClass ?? "").trim().toLowerCase()
        const found = key === "" ? null : root.classIndex[key]
        return found ? found.id : ""
    }

    // ── RUNNING ─────────────────────────────────────────────────────────────
    //
    // Keeps `HyprlandService.clients` live while the dock or any note deck
    // needs it (both test for fullscreen windows). Decks are read from the
    // settings, not `DesktopService`, which depends on this service's zone.
    readonly property bool decksExist: {
        const list = SettingsService.desktopWidgets
        const length = list && typeof list.length === "number" ? list.length : 0
        for (let index = 0; index < length; index++) {
            if (list[index] && list[index].edge)
                return true
        }
        return false
    }

    readonly property Binding watching: Binding {
        target: HyprlandService
        property: "watchClients"
        value: root.enabled || root.decksExist
    }

    onEnabledChanged: {
        if (root.enabled)
            HyprlandService.loadClients()
    }

    Component.onCompleted: {
        if (root.enabled)
            HyprlandService.loadClients()
    }

    // One group per application in first-opened order. Windows without a
    // class are skipped.
    readonly property var groups: {
        const order = []
        const seen = ({})
        for (const client of HyprlandService.clients) {
            const cls = (client.class ?? "").trim()
            if (cls === "")
                continue
            const id = root.idFor(cls)
            const key = id !== "" ? id : `class:${cls.toLowerCase()}`
            if (!seen[key]) {
                seen[key] = { key: key, id: id, cls: cls, windows: [] }
                order.push(seen[key])
            }
            seen[key].windows.push(client)
        }
        return order
    }

    function groupFor(key: string): var {
        return root.groups.find(group => group.key === key) ?? null
    }

    // A fullscreen window on the workspace a screen is showing. Hyprland
    // reports maximised as 1 and fullscreen as 2; only the latter hides the
    // dock — and only on its own screen.
    function coveredOn(name: string): bool {
        const workspace = HyprlandService.activeOn(name)
        return workspace > 0 && HyprlandService.clients.some(
            client => (client.fullscreen ?? 0) >= 2
                && client.workspace && client.workspace.id === workspace)
    }

    // The screens it is away from, as one padded string. A plain value rather
    // than a list, so the desktop's insets are worked out again when the
    // answer changes and not every time a window changes its title: the client
    // list is read here, once, instead of by a board's every binding.
    readonly property string coveredScreens: {
        let out = " "
        for (const screen of Quickshell.screens)
            if (root.coveredOn(screen.name))
                out += screen.name + " "
        return out
    }

    // ── ITEMS ───────────────────────────────────────────────────────────────
    //
    // Pinned in their order, then other running applications in the order
    // they were opened. A running pinned app stays in its pinned slot.
    readonly property var items: {
        const list = []
        for (const id of root.pinned)
            list.push(root.describe(id, "", root.groupFor(id)))
        if (!root.showsRunning)
            return list
        for (const group of root.groups) {
            if (group.id !== "" && root.isPinned(group.id))
                continue
            list.push(root.describe(group.id, group.cls, group))
        }
        return list
    }

    // A pinned entry whose desktop file is gone keeps its slot under its id,
    // so it can still be unpinned.
    function describe(id: string, cls: string, group: var): var {
        const entry = id !== "" ? root.entryOf(id) : null
        const windows = group ? group.windows : []
        return {
            key: id !== "" ? id : `class:${cls.toLowerCase()}`,
            id: id,
            name: entry ? entry.name : (cls !== "" ? cls : id.replace(/\.desktop$/, "")),
            icon: entry ? entry.icon : cls.toLowerCase(),
            pinned: root.isPinned(id),
            // Listed individually for the context menu.
            windows: windows.map(client => ({
                address: client.address,
                title: client.title || client.class,
                workspace: client.workspace ? client.workspace.id : 0,
                // The focused window, so a repeat click can cycle to the next
                // one. Uses the focused address rather than `focusHistoryID`,
                // which is stale after focusing an empty workspace.
                front: client.address === HyprlandService.focusedAddress
            })),
            running: windows.length > 0,
            active: windows.some(client => client.address === HyprlandService.focusedAddress)
        }
    }

    readonly property int count: root.items.length

    // A divider is drawn only when there are both pinned and unpinned items.
    readonly property int pinnedCount: root.pinned.length
    readonly property bool divides:
        root.pinnedCount > 0 && root.count > root.pinnedCount

    // ── GEOMETRY ────────────────────────────────────────────────────────────
    //
    // Computed rather than measured: the input mask is cut from these numbers
    // and would lag a frame behind a layout pass.

    // Offsets from the start of the capsule.
    readonly property real launcherOffset: Theme.dockPadding

    function offsetOf(index: int): real {
        return Theme.dockPadding + root.lead
            + index * (Theme.dockIcon + Theme.dockGap)
            + (root.divides && index >= root.pinnedCount ? Theme.dockGap : 0)
    }

    readonly property real length: {
        if (root.count === 0)
            return root.hasLauncher ? 2 * Theme.dockPadding + Theme.dockIcon : 0
        return root.offsetOf(root.count - 1) + Theme.dockIcon + Theme.dockPadding
    }

    // The capsule's rectangle inside the full-screen surface. The surface
    // never resizes (resizing a layer surface flickers), which also leaves
    // room for menus larger than the dock.
    function box(surfaceWidth: real, surfaceHeight: real): var {
        const along = root.vertical ? surfaceHeight : surfaceWidth
        const across = root.vertical ? surfaceWidth : surfaceHeight
        const start = root.alignment === "start"
            ? Theme.dockMargin
            : (root.alignment === "end"
                ? along - root.length - Theme.dockMargin
                : (along - root.length) / 2)
        const away = root.edge === "left"
            ? Theme.dockMargin
            : across - Theme.dockMargin - Theme.dockThickness
        return root.vertical
            ? { x: away, y: start, width: Theme.dockThickness, height: root.length }
            : { x: start, y: away, width: root.length, height: Theme.dockThickness }
    }

    // Offset that moves a hidden dock and its shadow fully off screen.
    readonly property real retreat: Theme.dockThickness + Theme.dockMargin

    readonly property real hiddenX: root.edge === "left"
        ? -root.retreat : (root.edge === "right" ? root.retreat : 0)
    readonly property real hiddenY: root.edge === "bottom" ? root.retreat : 0

    // ── DRAG ────────────────────────────────────────────────────────────────
    //
    // Only pinned items reorder. During a drag the list is untouched and
    // delegates shift by binding to these values, so no delegate is recreated
    // and the pointer grab survives. The list is written once, on drop.
    property string dragging: ""
    property int dragFrom: -1
    property int dropAt: -1

    // Display index of `index` while a drag is in progress.
    function shifted(index: int): int {
        if (root.dragging === "" || root.dragFrom < 0 || root.dropAt < 0
                || index === root.dragFrom)
            return index
        if (root.dragFrom < root.dropAt)
            return (index > root.dragFrom && index <= root.dropAt) ? index - 1 : index
        return (index >= root.dropAt && index < root.dragFrom) ? index + 1 : index
    }

    // Drop slot for an offset along the capsule, clamped to the pinned run.
    function slotAt(offset: real): int {
        const step = Theme.dockIcon + Theme.dockGap
        const raw = Math.round((offset - Theme.dockPadding - root.lead) / step)
        return Math.max(0, Math.min(root.pinnedCount - 1, raw))
    }

    function beginDrag(key: string, index: int): void {
        root.dragging = key
        root.dragFrom = index
        root.dropAt = index
    }

    function endDrag(): void {
        if (root.dragging !== "")
            root.reorder(root.dragFrom, root.dropAt)
        root.dragging = ""
        root.dragFrom = -1
        root.dropAt = -1
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────
    //
    // Click: launch if not running, focus if not focused, otherwise cycle to
    // the application's next window.
    function activate(item: var): void {
        if (!item)
            return
        if (!item.running) {
            root.launch(item)
            return
        }
        if (!item.active) {
            HyprlandService.focusWindow(item.windows[0].address)
            return
        }
        if (item.windows.length < 2)
            return
        const at = item.windows.findIndex(window => window.front)
        HyprlandService.focusWindow(
            item.windows[(at + 1) % item.windows.length].address)
    }

    // New instance. Unmatched windows have no entry to launch from.
    function launch(item: var): void {
        if (!item || item.id === "")
            return
        LauncherService.launchDesktop(item.id)
    }

    function closeAll(item: var): void {
        if (!item)
            return
        for (const window of item.windows)
            HyprlandService.closeWindow(window.address)
    }
}
