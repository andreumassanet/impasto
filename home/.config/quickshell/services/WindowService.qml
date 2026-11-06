// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W I N D O W   S E R V I C E                                            │
// │   the apps on a workspace · their classes and icons                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell

// What the workspace strip shows of the windows on a workspace: one icon per
// application class, by `SettingsService.workspaceIcons`. The windows come
// from `HyprlandService`, not from Quickshell's own Hyprland objects, which
// that service documents as unreliable here.
//
// The list is only kept fresh while something subscribes: the strip does,
// while it is on a bar.
Singleton {
    id: root

    property int watchers: 0

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    readonly property Binding watching: Binding {
        target: HyprlandService
        property: "watchIcons"
        value: root.watchers > 0
    }

    function classOf(client: var): string {
        return client?.class || client?.initialClass || ""
    }

    // Each class once, in the compositor's order.
    function distinctClasses(clients: var): var {
        const found = []
        for (const client of clients) {
            const windowClass = root.classOf(client)
            if (windowClass !== "" && found.indexOf(windowClass) < 0)
                found.push(windowClass)
        }
        return found
    }

    function classesOn(workspaceId: int): var {
        return root.distinctClasses(HyprlandService.clientsOn(workspaceId))
    }

    // The class of the workspace's last focused window, else its first.
    function leadClassOn(workspaceId: int): string {
        const workspace = HyprlandService.named.find(candidate => candidate.id === workspaceId)
        const address = workspace?.lastwindow ?? ""
        const lead = address === "" ? null
            : HyprlandService.clients.find(client => client.address === address) ?? null
        return lead ? root.classOf(lead) : (root.classesOn(workspaceId)[0] ?? "")
    }

    // The classes to draw, by the setting: up to four, one, or none.
    function pick(classes: var, lead: string): var {
        switch (SettingsService.workspaceIcons) {
        case "none":
            return []
        case "single":
            return lead !== "" ? [lead] : []
        }
        return classes.slice(0, 4)
    }

    function iconClassesOn(workspaceId: int): var {
        return root.pick(root.classesOn(workspaceId), root.leadClassOn(workspaceId))
    }

    // The same for whichever special workspace is open on a screen.
    function specialIconClasses(monitorName: string): var {
        const name = HyprlandService.specialOn(monitorName)
        if (name === "")
            return []
        const classes = root.distinctClasses(HyprlandService.specialClients
            .filter(client => client.workspace.name === name))
        return root.pick(classes, classes[0] ?? "")
    }

    // Never empty: the rules the user added (Settings › Bar) come first, then
    // the class's desktop entry, then the generic icon.
    function iconFor(windowClass: string): string {
        const lowered = windowClass.toLowerCase()
        const known = Array.from(SettingsService.workspaceIconRules ?? []).find(
            rule => rule.windowClass !== "" && lowered.includes(String(rule.windowClass).toLowerCase()))
        if (known)
            return Quickshell.iconPath(known.icon, "application-x-executable")
        const entry = DesktopEntries.heuristicLookup(windowClass)
        return Quickshell.iconPath(entry?.icon ?? windowClass.toLowerCase(), "application-x-executable")
    }
}
