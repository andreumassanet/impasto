// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   U S E R   P A N E L S                                                  │
// │   island panels added by the user · register, size, open by name         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell

// The island's own panels are a fixed list in DynamicIsland. A panel the user
// adds lives in ~/.config/quickshell/user/, which `setup` never installs into,
// so an update leaves it alone. user/Main.qml, when it exists, is loaded at
// boot and calls `register` once per panel:
//
//     Component.onCompleted: UserPanels.register("mine", minePanel,
//                                                { width: 420, height: 300 })
//
// then `qs ipc call panel open mine` (or a key bound to it) opens it. A panel
// that declares `signal back()` returns to the control centre when it fires.
Singleton {
    id: root

    // name → { component, size }. Replaced on each register, so the island's
    // bindings on it re-evaluate.
    property var entries: ({})

    readonly property var names: Object.keys(root.entries)

    function register(name: string, component: Component, size: var): void {
        const next = Object.assign({}, root.entries)
        next[name] = { component: component, size: size }
        root.entries = next
    }

    function unregister(name: string): void {
        const next = Object.assign({}, root.entries)
        delete next[name]
        root.entries = next
    }
}
