// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G R O U P   H E A D I N G                                              │
// │   settings group heading · with optional details                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// A settings group's name, in the sidebar's small capitals. `note` and `hint`
// open together behind the info glyph, by click rather than hover so the page
// does not shift under the pointer.
ColumnLayout {
    id: root

    property string title: ""
    property string note: ""
    property string hint: ""

    property bool opened: false

    readonly property string told:
        [root.note, root.hint].filter(text => text !== "").join(" ")

    Layout.fillWidth: true
    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 7

        Text {
            text: root.title
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
            font.capitalization: Font.AllUppercase
            color: Theme.textMuted
        }

        Text {
            visible: root.told !== ""
            text: "󰋼"
            font.family: Theme.fontMono
            font.pixelSize: 10
            color: root.opened ? Theme.accent : Theme.textMuted
            opacity: root.opened || hintMouse.containsMouse ? 1 : 0.5

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

            MouseArea {
                id: hintMouse
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.WhatsThisCursor
                onClicked: root.opened = !root.opened
            }
        }

        Item { Layout.fillWidth: true }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 20
        Layout.bottomMargin: 2
        visible: root.opened && root.told !== ""
        text: root.told
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        color: Theme.textMuted
    }
}
