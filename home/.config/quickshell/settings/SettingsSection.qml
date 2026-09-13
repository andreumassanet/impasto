// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G S   S E C T I O N                                        │
// │   the frame every settings page shares                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// The column every settings page is laid out in, one `SettingGroup` after
// another. It must not scroll: `SettingsPanel` scrolls the hero and the page
// together.
ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 20
}
