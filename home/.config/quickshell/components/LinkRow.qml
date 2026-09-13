// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L I N K   R O W                                                        │
// │   a row linking to another settings page                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// A row pointing at a setting that lives on another page, for settings
// shared by two subjects (module data, kept applications). `reading`
// summarises what is there.
Item {
    id: root

    property string label: ""
    property string reading: ""

    signal followed()

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
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "󰅂"
            font.family: Theme.fontMono
            font.pixelSize: 13
            color: linkMouse.containsMouse ? Theme.accent : Theme.textMuted

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
    }

    MouseArea {
        id: linkMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.followed()
    }
}
