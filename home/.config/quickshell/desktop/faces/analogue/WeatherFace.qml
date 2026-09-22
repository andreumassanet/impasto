// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W   E   A   T   H   E   R       F   A   C   E                          │
// │   the sky drawn, a thermometer beside it · the hours ahead as a curve    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"
import QtQuick.Shapes

// A drawing of the sky at every size, with the temperature under it on a 2×2.
// The 4×2 adds the thermometer, the description and the next hours as small
// skies; the band shows six. The 4×4 plots the coming hours as a temperature
// curve with the sky at each point.
Instrument {
    id: face

    readonly property var ahead: {
        const hour = WeatherService.clock.date.getHours()
        return (WeatherService.hourly ?? [])
            .filter(block => block.tomorrow || block.hour > hour)
            .slice(0, face.band ? 6 : (face.large ? 5 : 3))
    }

    readonly property bool known: WeatherService.available

    line: face.known ? `${WeatherService.temperature}° · ${WeatherService.place}` : "No reading"
    reading: face.known ? `${WeatherService.temperature}°` : "—"
    note: {
        if (!face.known)
            return "no reading yet"
        const range = `${WeatherService.high}° / ${WeatherService.low}°`
        return WeatherService.description !== ""
            ? `${WeatherService.place} · ${WeatherService.description} · ${range}`
            : `${WeatherService.place} · ${range}`
    }
    filled: true

    Item {
        anchors.fill: parent

        Sky {
            ink: face.ink
            glyph: face.known ? WeatherService.glyph : "󰖐"
            quiet: !face.known
            size: face.square ? Math.min(parent.width, parent.height) : parent.height * 0.66
            x: face.square ? (parent.width - width) / 2 : 0
            anchors.verticalCenter: parent.verticalCenter
        }

        Thermometer {
            visible: !face.square
            ink: face.ink
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            size: parent.height * 0.92
            // -10 to 45 °C, a wall thermometer's range.
            fraction: (WeatherService.temperature + 10) / 55
        }
    }

    extra: [
        Row {
            anchors.fill: parent
            visible: !face.large

            Repeater {
                model: ScriptModel {
                    values: face.ahead
                }

                Item {
                    id: block

                    required property var modelData

                    width: parent.width / Math.max(1, face.ahead.length)
                    height: parent.height

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: {
                                const hour = `${block.modelData.hour}`.padStart(2, "0")
                                return block.modelData.tomorrow ? `${hour}⁺` : `${hour}h`
                            }
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: face.ink.muted
                        }

                        Sky {
                            anchors.horizontalCenter: parent.horizontalCenter
                            ink: face.ink
                            glyph: block.modelData.glyph
                            size: 20
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${block.modelData.temperature}°`
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: face.ink.text
                        }
                    }
                }
            }
        }
    ]

    // The coming hours as a curve on one scale: a dot and the value at each,
    // the hour and the sky under the baseline.
    body: [
        Item {
            id: chart

            anchors.fill: parent

            readonly property var blocks: face.ahead
            readonly property var temps: chart.blocks.map(block => block.temperature)
            readonly property real lo: chart.temps.length > 0 ? Math.min.apply(null, chart.temps) - 2 : 0
            readonly property real hi: chart.temps.length > 0 ? Math.max.apply(null, chart.temps) + 2 : 1
            readonly property real plotTop: 20
            readonly property real plotBottom: chart.height - 52
            readonly property real leftX: 20
            readonly property real rightX: chart.width - 20

            function px(index: int): real {
                return chart.leftX + (chart.rightX - chart.leftX) * index / Math.max(1, chart.blocks.length - 1)
            }

            function py(temperature: real): real {
                return chart.plotBottom - (chart.plotBottom - chart.plotTop)
                    * (temperature - chart.lo) / Math.max(1, chart.hi - chart.lo)
            }

            Rectangle {
                x: chart.leftX
                y: chart.plotBottom
                width: chart.rightX - chart.leftX
                height: 1
                color: face.ink.dim
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: face.ink.accent
                    strokeWidth: 2.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: chart.blocks.map((block, index) => Qt.point(chart.px(index), chart.py(block.temperature)))
                    }
                }
            }

            Repeater {
                model: chart.blocks

                Item {
                    id: point

                    required property int index
                    required property var modelData

                    x: chart.px(point.index)
                    y: 0
                    width: 1
                    height: chart.height

                    Rectangle {
                        x: -4
                        y: chart.py(point.modelData.temperature) - 4
                        width: 8
                        height: 8
                        radius: 4
                        color: face.ink.accent
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: chart.py(point.modelData.temperature) - 24
                        text: `${point.modelData.temperature}°`
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: face.ink.text
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: chart.plotBottom + 8
                        text: {
                            const hour = `${point.modelData.hour}`.padStart(2, "0")
                            return point.modelData.tomorrow ? `${hour}⁺` : `${hour}h`
                        }
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: face.ink.muted
                    }

                    Sky {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: chart.plotBottom + 22
                        ink: face.ink
                        glyph: point.modelData.glyph
                        size: 22
                        quiet: true
                    }
                }
            }
        }
    ]
}
