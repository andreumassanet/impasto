// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F R A M E                                                              │
// │   frame · the room a thin border takes from the windows                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Wayland

import "../theme"
import "../services"

// The room the frame (`SettingsService.frameMode`) takes from the windows:
// one empty strip per side, reserving the frame's thickness. The border itself
// is drawn by the bar (`FrameRing`), in the island's own surface, and the top
// is the bar's own reserve (`BarReserve`). Built only while the frame is
// "always"; "open" draws over the windows and takes no room.
Scope {
    id: root

    required property var screen

    // Zen gives the windows the bar's band; the frame lets go with it.
    readonly property int reserved: SettingsService.barHidden ? 0 : SettingsService.frameThickness

    component Edge: PanelWindow {
        screen: root.screen
        color: "transparent"
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
        exclusiveZone: root.reserved
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "impasto-frame"
    }

    Edge { anchors { left: true; top: true; bottom: true } }
    Edge { anchors { right: true; top: true; bottom: true } }
    Edge { anchors { bottom: true; left: true; right: true } }
}
