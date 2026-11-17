// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P L A Y E R   S W I T C H                                              │
// │   ‹ 1/2 › · which media player the shell drives                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"

// Steps `MediaService` through the players around; there when there are two
// or more, gone otherwise. `color` is the surface's own ink.
Row {
    id: root

    property color color: Theme.text
    property int iconSize: 14

    visible: MediaService.count > 1
    spacing: 2

    IconButton {
        iconColor: root.color
        icon: "󰅁"
        iconSize: root.iconSize
        onClicked: MediaService.cycle(-1)
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: `${MediaService.index}/${MediaService.count}`
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeLabel
        color: root.color
        opacity: 0.7
    }

    IconButton {
        iconColor: root.color
        icon: "󰅂"
        iconSize: root.iconSize
        onClicked: MediaService.cycle(1)
    }
}
