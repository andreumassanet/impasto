// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O N N E C T I V I T Y   T A B S                                      │
// │   bluetooth, wi-fi and sound as tabs of one panel                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The strip at the top of the Bluetooth, Wi-Fi and Sound pages, the shell's
// own segmented control. Each page puts
// one on top of itself and says which it is; picking another asks the island
// for that panel, so every tab keeps its own size. Tab and Shift+Tab step
// through them from the page's own key handler (`handle`).
SegmentedControl {
    id: root

    // "bluetooth", "wifi" or "sound": the island panel this strip is on.
    required property string page

    signal pageRequested(string panel)

    readonly property var pages: ["bluetooth", "wifi", "sound"]

    Layout.fillWidth: true
    stretch: true
    labelled: true
    options: [
        { id: "bluetooth", label: "Bluetooth", icon: "󰂯" },
        { id: "wifi", label: "Wi-Fi", icon: "󰖩" },
        { id: "sound", label: Tr.t("Sound"), icon: "󰕾" }
    ]
    current: root.page
    onSelected: id => {
        if (id !== root.page)
            root.pageRequested(id)
    }

    // For the page's own Keys handler: true when the key was used.
    function handle(event: var): bool {
        if (!root.visible)
            return false
        const step = event.key === Qt.Key_Tab ? 1 : event.key === Qt.Key_Backtab ? -1 : 0
        if (step === 0)
            return false
        const count = root.pages.length
        root.pageRequested(root.pages[(root.pages.indexOf(root.page) + step + count) % count])
        return true
    }
}
