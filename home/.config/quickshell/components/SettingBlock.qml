// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G   B L O C K                                              │
// │   settings · free content in a group                                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// Anything in a `SettingGroup` that is not a row — a preview, a list, a
// canvas — padded like a row and ruled off from the one above. Children lay
// themselves out in a column and fill its width with `Layout.fillWidth`.
Item {
    id: root

    property int padding: 14

    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 2 * root.padding

    SettingDivider {}

    ColumnLayout {
        id: body

        x: root.padding
        y: root.padding
        width: root.width - 2 * root.padding
        spacing: 10
    }
}
