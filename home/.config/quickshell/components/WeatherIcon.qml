// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W E A T H E R   I C O N                                                │
// │   the weather's glyph at any size, in the accent                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// `glyph` is the Nerd Font symbol `WeatherService` gives for the sky.
Text {
    id: root

    property string glyph: ""
    property int size: 24

    width: root.size
    height: root.size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: root.glyph !== "" ? root.glyph : "󰅤"
    font.family: Theme.fontMono
    font.pixelSize: Math.round(root.size * 0.85)
    color: Theme.accent
}
