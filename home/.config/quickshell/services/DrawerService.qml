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

    function noteFramed(framed: bool): void {
        root.framedCount = Math.max(0, root.framedCount + (framed ? 1 : -1))
    }
}
