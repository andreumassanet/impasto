// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R A Y   F A C E                                                      │
// │   the system tray as a widget on the grid                                │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../theme"
import "../../services"
import "../../bar/modules"

// The status notifier icons centred in the widget's capsule, grown from the
// bar's row to the desktop cell and clipped at the edges. The same module the
// bar uses, so menus and hover work unchanged.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property var row: null
    property string family: "4x2"

    // The screen the widget sits on, so an item's menu opens there. A row
    // without one — the primary's, or a settings preview — uses the primary.
    readonly property var screen: {
        const name = root.row?.screen ?? ""
        const found = name === "" ? null : Quickshell.screens.find(s => s.name === name)
        return found ?? MonitorService.primaryScreen ?? Quickshell.screens[0] ?? null
    }

    // Fits a handful of icons with room to breathe; the row stays centred
    // while it is narrower than the cell. The widget has no height on the
    // first frame (it animates to its box), so the bar row is the stand-in.
    property int iconSpace: {
        const h = root.height > 0 ? root.height : Theme.capsuleHeight
        return Math.min(Theme.desktopCellLargest,
            Math.max(Theme.capsuleHeight, Math.round(h * 0.24)))
    }

    clip: true

    TrayModule {
        anchors.centerIn: parent
        iconSpace: root.iconSpace
        hostScreen: root.screen
    }
}