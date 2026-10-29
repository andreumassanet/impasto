// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W E A T H E R   I C O N                                                │
// │   the weather as a full-colour icon at any size                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// The sky as KDE Breeze's full-colour weather icon, by the `name`
// `WeatherService.icon` gives ("few-clouds", "showers-night", ...). Without a
// name, or where the Breeze icons are not installed, the Nerd Font `glyph`
// `WeatherService` gives is drawn in the accent instead.
Item {
    id: root

    property string name: ""
    property string glyph: ""
    property int size: 24

    width: root.size
    height: root.size

    Image {
        id: picture

        anchors.fill: parent
        visible: status === Image.Ready
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        source: root.name !== "" ? `file:///usr/share/icons/breeze/applets/48/weather-${root.name}.svg` : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Text {
        anchors.fill: parent
        visible: !picture.visible
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.glyph !== "" ? root.glyph : "󰅤"
        font.family: Theme.fontMono
        font.pixelSize: Math.round(root.size * 0.85)
        color: Theme.accent
    }
}
