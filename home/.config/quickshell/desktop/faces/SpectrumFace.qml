// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S P E C T R U M   F A C E                                              │
// │   the sound bars as a widget on the grid                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import ".."

// The spectrum on a square: its bars and nothing else, as on an edge, rising
// from the square's bottom in the look its row gives it. The same in both
// themes. Without a row — the tray's card — it keeps a street from the card's
// edges.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property var row: null
    property string family: "4x2"

    readonly property var looks: DesktopService.spectrumOf(root.row)

    // Away as a strip is (`spectrumAwayOn`), except while arranging and on
    // the tray's card.
    readonly property bool away: root.row !== null && !DesktopService.editing
        && DesktopService.spectrumAwayOn(DesktopService.nameOf(root.row))

    SpectrumBars {
        anchors.fill: parent
        anchors.margins: root.row === null ? Theme.desktopGutter : 0
        style: root.looks.look
        fillStyle: root.looks.fill
        color: root.looks.color
        color2: root.looks.color2
        barWidth: root.looks.bar
        gap: root.looks.gap
        lowsAt: root.looks.lows
        peaks: root.looks.peaks
        opacity: root.looks.opacity / 100
        listening: !root.away
        visible: listening
    }
}
