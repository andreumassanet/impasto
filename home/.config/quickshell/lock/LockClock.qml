// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L O C K   C L O C K                                                    │
// │   the lock's clock · stacked, inline or flip, the date above it          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"
import "../services"

// The date above, then the time: hours over minutes with the minutes softer,
// the two on one line, or each on a card that folds over when it changes.
// The login screen draws the stacked one to the same numbers. Shared with
// the setting's preview, which passes a fixed time.
Item {
    id: root

    // "stacked", "inline" or "flip".
    property string style: SettingsService.lockClock

    // Empty follows the clock; the preview sets one.
    property var at: null

    readonly property bool stacked: root.style !== "inline" && root.style !== "flip"
    readonly property bool flip: root.style === "flip"

    readonly property int dateSize: 26
    readonly property int inlineSize: 212
    readonly property int stackedSize: 300
    readonly property int flipSize: 190

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
        spacing: root.stacked || root.flip ? root.stackedGap : -Math.round(root.inlineSize * 0.07)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            font.family: Theme.fontDisplay
            font.pixelSize: root.dateSize
            font.weight: Font.DemiBold
            color: Theme.text
            opacity: 0.92
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.flip
            spacing: Math.round(root.flipSize * 0.1)

            // By count, so a new minute folds the card already there
            // rather than building another.
            Repeater {
                model: root.flip ? root.parts.length : 0

                FlipCard {
                    required property int index

                    value: root.parts[index] ?? ""
                    size: root.flipSize
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.stacked && !root.flip
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
