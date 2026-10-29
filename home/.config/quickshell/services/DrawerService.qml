// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D R A W E R   S E R V I C E                                            │
// │   which edge drawer is open, and on which screen                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell

// Shared state of the edge drawers (`frame/EdgeDrawer.qml`). Each drawer
// reports here while it is out, so the frame can show itself in its "open"
// mode and the island can step aside.
Singleton {
    id: root

    // Drawers out right now, over every screen.
    property int framedCount: 0
    readonly property bool anyFramed: root.framedCount > 0

    // ── LAUNCHER ────────────────────────────────────────────────────────────
    //
    // The launcher grows from the bottom edge in one of two modes: "search"
    // (the island's launcher panel) or "apps" (the application grid). Which
    // one the launcher key opens is `SettingsService.launcherDesign`.
    property bool launcherOpen: false
    property string launcherMode: "search"
    // The screen it opens on; "" is the one being worked on.
    property string screenName: ""

    readonly property string designMode: SettingsService.launcherDesign === "grid" ? "apps" : "search"

    // Asked for again in the mode it is already showing, it closes.
    function openLauncher(mode: string, screenName: string): void {
        if (root.launcherOpen && root.launcherMode === mode) {
            root.closeLauncher()
            return
        }
        root.launcherMode = mode
        root.screenName = screenName
        root.launcherOpen = true
    }

    function closeLauncher(): void {
        root.launcherOpen = false
        root.screenName = ""
    }

    // Opening anything else (a panel of the island, another drawer) calls
    // this first, so only one thing holds the keyboard.
    function closeAll(): void {
        root.closeLauncher()
    }

    // A drawer that is no longer built cannot be left open.
    readonly property Connections designChanged: Connections {
        target: SettingsService

        function onLauncherDesignChanged(): void {
            root.closeLauncher()
        }
    }

    function noteFramed(framed: bool): void {
        root.framedCount = Math.max(0, root.framedCount + (framed ? 1 : -1))
    }
}
