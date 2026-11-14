// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R A Y   S E R V I C E                                                │
// │   system tray · the items and the menu open in the island                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

import "../theme"

// The applications' tray icons (StatusNotifierItem), and the one whose menu
// the island is showing. The menu is drawn by the shell, not by the
// application's toolkit, so every menu looks like the rest of the island; a
// submenu replaces the list, and the header steps back out of it.
//
// A submenu is followed by its label, not held: an application can rebuild
// its menu at any moment (nm-applet does while it scans), which destroys the
// entry without the parent saying its children changed, so the path is
// looked up again whenever the entry goes.
Singleton {
    id: root

    // Every item that asks to be shown, for the page that hides some of them.
    // Passive ones ask not to be.
    readonly property var all: SystemTray.items.values
        .filter(item => item.status !== Status.Passive)

    // What the tray draws: all of them but those hidden in the settings
    // (`trayHidden`, by item id).
    readonly property var items: root.all
        .filter(item => Array.from(SettingsService.trayHidden ?? []).indexOf(item.id) < 0)

    // ── THE OPEN MENU ───────────────────────────────────────────────────────

    property var item: null

    // Labels from the item's root menu to the submenu on screen, two deep at
    // most, which is as far as tray menus go.
    property var stack: []

    // Bumped to look the path up again after an entry was destroyed.
    property int revision: 0

    function find(opener: var, label: string): var {
        void root.revision
        const children = opener.children ? opener.children.values : []
        return children.find(entry => entry.text === label && entry.hasChildren) ?? null
    }

    function lost(menu: var, depth: int): void {
        if (menu === null && root.stack.length >= depth)
            Qt.callLater(() => root.revision++)
    }

    readonly property QsMenuOpener top: QsMenuOpener {
        menu: root.item ? root.item.menu : null
    }

    readonly property QsMenuOpener first: QsMenuOpener {
        menu: root.stack.length >= 1 ? root.find(root.top, root.stack[0]) : null
        onMenuChanged: root.lost(menu, 1)
    }

    readonly property QsMenuOpener second: QsMenuOpener {
        menu: root.stack.length >= 2 ? root.find(root.first, root.stack[1]) : null
        onMenuChanged: root.lost(menu, 2)
    }

    readonly property QsMenuOpener opener:
        root.stack.length >= 2 ? root.second : root.stack.length === 1 ? root.first : root.top

    // Separators only between entries: none leading, trailing or doubled.
    readonly property var entries: {
        const raw = root.opener.children ? root.opener.children.values : []
        const out = []
        for (const entry of raw) {
            if (entry.isSeparator && (out.length === 0 || out[out.length - 1].isSeparator))
                continue
            out.push(entry)
        }
        while (out.length > 0 && out[out.length - 1].isSeparator)
            out.pop()
        return out
    }

    // An item that goes away takes its menu with it.
    readonly property bool gone: root.item !== null && root.items.indexOf(root.item) < 0
    onGoneChanged: {
        if (root.gone)
            root.release()
    }

    // The island shows the menu under the panel name `tray`: the same click
    // closes it, another item's click swaps the menu in place.
    function open(item: var): void {
        if (!item || !item.hasMenu)
            return
        const showing = ModuleService.shownPanel === "tray"
        if (showing && root.item === item) {
            ModuleService.togglePanel("tray")
            return
        }
        root.item = item
        root.stack = []
        if (!showing)
            ModuleService.togglePanel("tray")
    }

    function enter(entry: var): void {
        if (entry && entry.hasChildren && root.stack.length < 2)
            root.stack = root.stack.concat([entry.text])
    }

    function back(): void {
        root.stack = root.stack.slice(0, -1)
    }

    function release(): void {
        root.item = null
        root.stack = []
        if (ModuleService.shownPanel === "tray")
            ModuleService.togglePanel("tray")
    }

    // A left click: the menu for an item that is only a menu, else the
    // item's own action.
    function activate(item: var): void {
        if (item.onlyMenu)
            root.open(item)
        else
            item.activate()
    }

    // ── SIZE ────────────────────────────────────────────────────────────────
    //
    // Declared, since the island takes its size before the panel exists.
    readonly property int menuWidth: 300
    readonly property int rowHeight: 34
    readonly property int separatorHeight: 9
    readonly property int rowSpacing: 2
    readonly property int headerHeight: 34
    readonly property int maxHeight: 560

    readonly property int listHeight: {
        let height = 0
        for (const entry of root.entries)
            height += (entry.isSeparator ? root.separatorHeight : root.rowHeight) + root.rowSpacing
        return Math.max(0, height - root.rowSpacing)
    }

    // Header, its rule and the gap either side of it, then the list.
    readonly property int menuHeight: Math.min(root.maxHeight,
        2 * Theme.panelPadding + root.headerHeight + 1 + 2 * root.rowSpacing + root.listHeight)
}
