// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O S D   L A Y E R                                                      │
// │   transient events · icon, level bar and reading                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Layouts

import "../../theme"

// One layer for every ephemeral event. Volume, brightness and battery differ
// only in the icon, the reading and whether there is a level to draw.
//
// Centred as a group with a fixed-width track rather than stretched edge to
// edge, which would push the icon and the reading out to the ends.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property real progress: -1

    readonly property bool hasLevel: root.progress >= 0

    Row {
        anchors.centerIn: parent
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: Theme.fontMono
            font.pixelSize: 15
            // The glyph identifies the control; the level carries the palette.
            color: Theme.indicator
        }

        // The bar carries the magnitude; the number is only for confirming it.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasLevel
            width: 130
            height: 6
            radius: height / 2
            color: Theme.surfaceHoverIn(QsWindow.window)

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.min(1, Math.max(0, root.progress)))
                height: parent.height
                radius: height / 2
                color: Theme.accent

                Behavior on width {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // Fixed width so the group does not shift as the reading goes from
            // one digit to three, but never narrower than the text: some
            // readings are not percentages (a picked colour, a new best).
            width: Math.max(34, implicitWidth)
            horizontalAlignment: Text.AlignRight
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.text
        }
    }
}
