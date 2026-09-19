// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E C O N D   B A R                                                    │
// │   bar for other screens · the two sides without the island               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"
import "../services"
import "./widgets"

// The bar on every screen without the island: the two sides in the corners,
// whatever the style. A click opens the detail in the island on the main
// screen (`origin: "elsewhere"`). Separate from `Bar.qml` because nearly all
// of that file is about the island.
PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    // Tall enough for the capsules and their shadow; nothing opens below.
    implicitHeight: root.collapsedHeight + Theme.shadowBarRange

    readonly property int collapsedHeight: Theme.barBand

    // The reserve is `BarReserve.qml`'s, as the main bar's is, and the zones
    // are ignored for the same reason: to stay against the edge.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    // Input only on the band, and none while the desktop is being arranged
    // (see `Bar.qml`).
    mask: Region {
        width: DesktopService.editing ? 0 : root.width
        height: DesktopService.editing ? 0 : root.collapsedHeight
    }

    readonly property int edgeMargin: SettingsService.barSideMargin

    BarZone {
        entries: SettingsService.barItems("left")
        origin: "elsewhere"
        x: root.edgeMargin
        y: Theme.barTopMargin
    }

    BarZone {
        id: right

        entries: SettingsService.barItems("right")
        origin: "elsewhere"
        x: root.width - root.edgeMargin - right.width
        y: Theme.barTopMargin
    }
}
