// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L I N K   F I E L D                                                    │
// │   a text box for a calendar's name or link                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"

// One line of text with a hint while empty, for the calendar links in
// `ModulesSection`; Enter is `accepted`.
Rectangle {
    id: field

    property alias text: input.text
    property string placeholder: ""

    signal accepted()

    implicitHeight: 30
    radius: Theme.radiusSmall
    color: Theme.island
    border.color: input.activeFocus ? Theme.accent : Theme.borderIn(QsWindow.window)
    border.width: 1

    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.text
        selectByMouse: true
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        clip: true
        onAccepted: field.accepted()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: field.placeholder
            font: input.font
            color: Theme.textMuted
        }
    }
}
