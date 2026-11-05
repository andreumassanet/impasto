// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O N N E C T I V I T Y   T A B S                                      │
// │   Bluetooth, Wi-Fi and Sound as the tabs of one island panel             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The strip at the top of the Bluetooth, Wi-Fi and Sound pages when
// `connectivityTabs` is on. Each page puts one on top of itself and says which
// it is; picking another asks the island for that panel, so every tab keeps
// its own size.
PanelTabs {
    id: root

    // "bluetooth", "wifi" or "sound": the island panel this strip is on.
    required property string page

    signal pageRequested(string panel)

    readonly property var pages: ["bluetooth", "wifi", "sound"]

    visible: SettingsService.connectivityTabs

    // For the page's own Keys handler: true when the key was used. Tab and
    // Shift+Tab change page; with `activate`, the keys 1 to 9 call it with the
    // row's index (0 to 8): the page's Nth network, device or output.
    function handle(event: var, activate: var): bool {
        if (!root.visible)
            return false
        if (event.key === Qt.Key_Tab)
            root.step(1)
        else if (event.key === Qt.Key_Backtab)
            root.step(-1)
        else if (activate && event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
            activate(event.key - Qt.Key_1)
        else
            return false
        return true
    }

    tabs: [
        { label: "Bluetooth", glyph: "󰂯" },
        { label: "Wi-Fi", glyph: "󰖩" },
        { label: Tr.t("Sound"), glyph: "󰕾" }
    ]
    current: Math.max(0, root.pages.indexOf(root.page))
    onPicked: index => root.pageRequested(root.pages[index])
}
