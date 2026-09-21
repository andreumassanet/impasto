// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C L O C K                                                              │
// │   the date, then hours over minutes                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "."

// The lock screen's stacked clock, to the same numbers: the minutes softer
// than the hours, the two lines overlapping by their empty leading so the
// figures sit a gap apart rather than a line apart.
Item {
    id: root

    property date now: new Date()

    readonly property int gap: 18

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column

        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.gap

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSizeDate
            font.weight: Font.DemiBold
            color: Theme.text
            opacity: 0.92
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -Math.round(Theme.fontSizeClock * 0.48) + root.gap
            topPadding: -Math.round(Theme.fontSizeClock * 0.24)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "HH")
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSizeClock
                font.weight: Font.Bold
                font.letterSpacing: -Math.round(Theme.fontSizeClock * 0.04)
                font.features: { "tnum": 1 }
                color: Theme.text
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "mm")
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSizeClock
                font.weight: Font.Bold
                font.letterSpacing: -Math.round(Theme.fontSizeClock * 0.04)
                font.features: { "tnum": 1 }
                color: Theme.text
                opacity: 0.55
            }
        }
    }
}
