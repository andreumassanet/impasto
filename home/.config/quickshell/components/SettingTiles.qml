// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G   T I L E S                                              │
// │   settings choice as preview tiles                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// A setting whose options are shapes: the name above, then a row of
// `PreviewTile`s sharing the card's width evenly. The one row in a group that
// needs more than a line.
Item {
    id: root

    property string label: ""

    // Only when it says more than the chosen tile's caption.
    property string reading: ""

    // Same meaning as in `SettingRow`.
    property bool locked: false
    property string reason: ""

    default property alias tiles: flow.data

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 28
    opacity: root.locked ? 0.55 : 1

    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

    SettingDivider {}

    ColumnLayout {
        id: body

        x: 14
        y: 14
        width: root.width - 28
        spacing: 0

        SettingLabel {
            Layout.fillWidth: true
            label: root.label
            reading: root.reading
            locked: root.locked
            reason: root.reason
        }

        RowLayout {
            id: flow

            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 10
            enabled: !root.locked
        }
    }
}
