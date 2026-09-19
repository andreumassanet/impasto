// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A R   R E S E R V E                                                  │
// │   the space the bar keeps · held by the screen, not by the bar           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Wayland

import "../theme"

// One strip per screen, a pixel tall and painting nothing, whose only job is
// the exclusive zone. The bars reserve nothing themselves, so a bar replaced
// by another kind never lets the space go: tiled windows hold still while the
// island changes screens.
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 1
    color: "transparent"
    exclusiveZone: Theme.barReserve

    // Under everything, and deaf.
    WlrLayershell.layer: WlrLayer.Background
    mask: Region {}
}
