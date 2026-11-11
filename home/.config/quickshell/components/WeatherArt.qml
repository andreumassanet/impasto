// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W E A T H E R   A R T                                                  │
// │   the weather in full colour, over the glyph it stands in for            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../services"

// Breeze's full-colour weather icon, by the name `WeatherService` gives
// ("few-clouds", "showers-night"…), drawn over the glyph Text it is a child
// of, while Settings → Modules → Weather → Icons says colour. The glyph hides
// itself while `shown`; without Breeze, or without a name, it stays.
Image {
    id: root

    property string name: ""
    // How much larger than the glyph's type the picture is drawn.
    property real grow: 1.2

    readonly property bool wanted: root.name !== "" && SettingsService.weatherIcons === "colour"
    readonly property bool shown: root.wanted && root.status === Image.Ready

    anchors.centerIn: parent
    width: Math.round(parent.font.pixelSize * root.grow)
    height: root.width
    sourceSize: Qt.size(root.width * 2, root.width * 2)
    source: root.wanted ? `file://${WeatherService.breezeIcons}/weather-${root.name}.svg` : ""
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    visible: root.shown
}
