// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G   G R O U P                                              │
// │   settings · a titled card of rows                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// Its heading, then one card holding the group's rows, divided by hairlines.
// `bare` leaves the card out, for a control that draws its own surface.
ColumnLayout {
    id: root

    property string title: ""

    // Both open behind the heading's info glyph.
    property string note: ""
    property string hint: ""

    property bool bare: false

    default property alias rows: list.data

    Layout.fillWidth: true
    spacing: 7

    GroupHeading {
        visible: root.title !== ""
        title: root.title
        note: root.note
        hint: root.hint
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: list.implicitHeight
        radius: Theme.radiusMedium
        color: root.bare ? "transparent" : Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: root.bare ? 0 : 1

        ColumnLayout {
            id: list

            width: parent.width
            spacing: root.bare ? 10 : 0
        }
    }
}
