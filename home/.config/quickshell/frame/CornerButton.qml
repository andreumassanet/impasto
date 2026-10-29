// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O R N E R   B U T T O N                                              │
// │   frame · a button that opens an edge drawer by click                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// A round button under the bar's corner, drawn as the icon of the drawer it
// opens. Used with `edgeOpen` "click", when the edges do not wake the drawers.
Rectangle {
    id: root

    property string glyph: ""
    // The drawer it opens is out.
    property bool lit: false

    signal triggered()

    width: Theme.capsuleHeight
    height: Theme.capsuleHeight
    radius: height / 2
    color: root.lit ? Theme.accent
        : mouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandGround
    border.color: Theme.islandRim
    border.width: 1

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: Theme.fontMono
        font.pixelSize: Math.round(Theme.capsuleHeight * 0.46)
        color: root.lit ? Theme.accentText : Theme.text
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
