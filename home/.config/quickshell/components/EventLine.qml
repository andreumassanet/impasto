// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   E V E N T   L I N E                                                    │
// │   one calendar event as a line, its time and its title                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"

// An event from `AgendaService`, the height of a `TaskRow` and in the same
// `ink`, so the two can share a list on a widget.
Item {
    id: root

    property var event: null
    property var ink: ({
        text: Theme.text, muted: Theme.textMuted, accent: Theme.accent
    })

    implicitHeight: 24

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 3
            Layout.preferredHeight: 14
            radius: 1.5
            color: root.ink.accent
        }

        Text {
            text: !root.event ? "" : root.event.allDay ? Tr.t("All day") : root.event.time
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            font.features: { "tnum": 1 }
            color: root.ink.muted
        }

        Text {
            Layout.fillWidth: true
            text: root.event ? root.event.title : ""
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: root.ink.text
        }
    }
}
