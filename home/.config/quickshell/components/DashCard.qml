// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D A S H   C A R D                                                      │
// │   a titled card for the dashboard · small capitals over its rows         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"

// The surface of the dashboard's panels: the control centre's card, with a
// title in small capitals and the contents stacked under it.
Rectangle {
    id: root

    property string title: ""
    default property alias content: body.data
    // Controls in the card's top right corner, beside the title.
    property alias corner: cornerRow.data

    radius: Theme.radiusMedium
    color: Theme.surfaceIn(QsWindow.window)
    border.color: Theme.borderIn(QsWindow.window)
    border.width: 1
    implicitHeight: body.implicitHeight + 32

    Row {
        id: cornerRow

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        spacing: 8
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Text {
            visible: root.title !== ""
            text: root.title.toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
            color: Theme.textMuted
        }
    }
}
