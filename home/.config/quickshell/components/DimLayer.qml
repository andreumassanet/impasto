// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D I M   L A Y E R                                                      │
// │   a screen dimmed past its backlight · black over it, never in the way   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Wayland

import "../services"

// Black over everything on one screen, at the darkness `BrightnessService`
// gives that screen once the backlight cannot go lower. Over the bar too, so
// the whole screen dims; the lock is above it. Deaf: clicks land on what is
// under it. Gone at zero.
PanelWindow {
    id: root

    readonly property real darkness: BrightnessService.displayNamed(root.screen?.name ?? "")?.dim ?? 0

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: root.darkness > 0
    color: Qt.rgba(0, 0, 0, root.darkness)
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "impasto-dim"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
}
