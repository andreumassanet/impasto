// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C L O C K   B L O C K                                                  │
// │   clock block · the time, and the date when there is room                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// The clock. Square: time over the day. Wide: larger time over the full date.
// Large square: the same, bigger. 1×2 and 2×4 are square on this grid.
// Uses the configured format, with seconds appended as on the bar.
Card {
    id: root

    property int cols: 1
    property int rows: 2

    readonly property bool tall: root.rows >= 4
    readonly property bool wide: root.cols >= 2 && !root.tall

    SystemClock {
        id: clock
        precision: SettingsService.clockShowsSeconds
            ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property string format: SettingsService.clockShowsSeconds
        ? SettingsService.clockFormat.replace("mm", "mm:ss")
        : SettingsService.clockFormat

    readonly property int timeSize: root.tall ? 64 : (root.wide ? 44 : 30)

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: root.tall ? 6 : 2

        // Scaled down rather than clipped: with seconds on, the time is wider
        // than a square.
        Text {
            width: parent.width
            text: Tr.date(clock.date, root.format)
            horizontalAlignment: Text.AlignHCenter
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontSizeLarge
            font.family: Theme.fontFamily
            font.pixelSize: root.timeSize
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Text {
            width: parent.width
            text: Tr.date(clock.date, root.wide || root.tall ? "dddd d MMMM" : "ddd d MMM")
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: root.tall ? Theme.fontSizeMedium : Theme.fontSizeSmall
            color: Theme.textMuted
        }
    }
}
