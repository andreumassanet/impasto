// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D O C K   A P P S                                                      │
// │   what the dock drawer does to an application's windows                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../theme"

// The window side of the dock drawer. The apps themselves are
// `DockService.items` (pinned first, then what is running, windows matched to
// desktop entries); this adds what the drawer's popout does to one window:
// its preview, the workspace to send it to, pin, fullscreen. Float, focus and
// close are `HyprlandService`'s. Windows are named by their Hyprland address
// (`0x…`), as everywhere else in the shell.
Singleton {
    id: root

    // An item's icon, from the same lookup as the classic dock; empty when the
    // theme has none, and the caller draws the launcher mark.
    function iconOf(item: var): string {
        return item && item.icon ? Theme.appIcon(item.icon) : ""
    }

    // The window's full record from `hyprctl clients`: floating, pinned and
    // fullscreen are not in the dock's own summary.
    function clientOf(address: string): var {
        return HyprlandService.clients.find(client => client.address === address) ?? null
    }

    // The Wayland toplevel that has the pixels. Hyprland's address is not a
    // handle the Wayland side knows, so, as in the overview, it is matched on
    // application id and then title.
    function toplevelFor(client: var): var {
        if (!client)
            return null
        const entries = ToplevelManager.toplevels.values
        return entries.find(entry => entry.appId === client.class && entry.title === client.title)
            ?? entries.find(entry => entry.title === client.title)
            ?? null
    }

    function moveTo(address: string, workspaceId: int): void {
        HyprlandService.moveClient(address, workspaceId)
    }

    // Hyprland pins only a floating window, so a tiled one floats first.
    function togglePin(address: string): void {
        if (!(root.clientOf(address)?.floating ?? false))
            HyprlandService.toggleFloating(address)
        Hyprland.dispatch(`hl.dsp.window.pin({ action = "toggle", window = "address:${address}" })`)
        HyprlandService.loadClients()
    }

    function toggleFullscreen(address: string): void {
        HyprlandService.focusWindow(address)
        Hyprland.dispatch(`hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle", window = "address:${address}" })`)
        HyprlandService.loadClients()
    }

    // A new window on a given workspace: go there, then start it.
    function launchOn(item: var, workspaceId: int): void {
        HyprlandService.focus(workspaceId)
        DockService.launch(item)
    }
}
