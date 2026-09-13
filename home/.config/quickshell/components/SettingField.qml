// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G   F I E L D                                              │
// │   a preference that is a piece of text                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// A setting row whose control is a text field, as wide as a slider's track
// and figure so the two line up. The placeholder is what applies while the
// field is empty.
Item {
    id: root

    property string label: ""
    property string reading: ""
    property bool alarm: false

    property string placeholder: ""
    property string value: ""

    signal edited(string value)

    Layout.fillWidth: true
    implicitHeight: Math.max(48, body.implicitHeight + 16)

    SettingDivider {}

    RowLayout {
        id: body

        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 16

        SettingLabel {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            label: root.label
            reading: root.reading
            alarm: root.alarm
        }

        Rectangle {
            Layout.preferredWidth: 300
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.radiusSmall
            color: Theme.island
            border.color: input.activeFocus ? Theme.accent : Theme.islandBorder
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                text: root.value
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.text
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                clip: true

                onTextEdited: root.edited(input.text)
                Keys.onEscapePressed: { input.text = ""; root.edited("") }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    visible: input.text === ""
                    text: root.placeholder
                    elide: Text.ElideRight
                    font: input.font
                    color: Theme.textMuted
                }
            }
        }
    }
}
