// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L O C K   C L O C K                                                    │
// │   the lock's clock · stacked or inline, the date above it                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"
import "../services"

// The date above, then the time: hours over minutes with the minutes softer,
// or the two on one line. The login screen draws the stacked one to the same
// numbers. Shared with the setting's preview, which passes a fixed time.
Item {
    id: root

    // "stacked" or "inline".
    property string style: SettingsService.lockClock

    // Empty follows the clock; the preview sets one.
    property var at: null

    readonly property bool stacked: root.style !== "inline"

    readonly property int dateSize: 26
    readonly property int inlineSize: 212
    readonly property int stackedSize: 300

    // A figure's cap height is about 0.73 of its size in Inter, and a line is
    // about 1.21: stacked lines overlap by the difference, less a gap.
    readonly property int stackedGap: 18

    readonly property date now: root.at !== null ? root.at : clock.date
    // The clock's own format, split on its separator for the stacked form.
    readonly property string time: Qt.formatDateTime(root.now, SettingsService.clockFormat)
    readonly property var parts: root.time.split(":")

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.at === null
    }

    Column {
        id: column

        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.stacked ? root.stackedGap : -Math.round(root.inlineSize * 0.07)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            font.family: Theme.fontDisplay
            font.pixelSize: root.dateSize
            font.weight: Font.DemiBold
            color: Theme.text
            opacity: 0.92
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.stacked
            text: root.time
            font.family: Theme.fontDisplay
            font.pixelSize: root.inlineSize
            font.weight: Font.DemiBold
            font.letterSpacing: -Math.round(root.inlineSize * 0.033)
            font.features: { "tnum": 1 }
            color: Theme.text
        }

        // The two lines overlap by their empty leading, so the figures sit a
        // gap apart rather than a line apart.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.stacked
            spacing: -Math.round(root.stackedSize * 0.48) + root.stackedGap
            topPadding: -Math.round(root.stackedSize * 0.24)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.parts[0] ?? ""
                font.family: Theme.fontDisplay
                font.pixelSize: root.stackedSize
                font.weight: Font.Bold
                font.letterSpacing: -Math.round(root.stackedSize * 0.04)
                font.features: { "tnum": 1 }
                color: Theme.text
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.parts.slice(1).join(":")
                font.family: Theme.fontDisplay
                font.pixelSize: root.stackedSize
                font.weight: Font.Bold
                font.letterSpacing: -Math.round(root.stackedSize * 0.04)
                font.features: { "tnum": 1 }
                color: Theme.text
                opacity: 0.55
            }
        }
    }
}
