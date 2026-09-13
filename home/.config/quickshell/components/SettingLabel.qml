// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G   L A B E L                                              │
// │   settings · a row's name and reading                                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// The left half of every settings row: the name, and under it what the
// setting says now — or, locked, a padlock and why it cannot change.
ColumnLayout {
    id: root

    property string label: ""
    property string reading: ""
    property bool alarm: false
    property bool locked: false
    property string reason: ""

    spacing: 1

    Text {
        Layout.fillWidth: true
        text: root.label
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.text
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.locked ? root.reason !== "" : root.reading !== ""
        spacing: 5

        Text {
            visible: root.locked
            text: "󰌾"
            font.family: Theme.fontMono
            font.pixelSize: 9
            color: Theme.textMuted
        }

        Text {
            Layout.fillWidth: true
            text: root.locked ? root.reason : root.reading
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            color: root.alarm && !root.locked ? Theme.red : Theme.textMuted
        }
    }
}
