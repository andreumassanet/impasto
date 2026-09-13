// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B   A   N   D   S                                                      │
// │   8×2 widget faces                                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../theme"
import "../../services"

// 8×2 faces: a strip. The same grid as the other families (mark, label, and the
// reading along the bottom), with the reading set large. Suits the bare style
// best.
Item {
    id: root

    property string moduleId: ""

    // Colours resolved by the widget. Faces read this rather than `Theme`.
    property var ink: DesktopService.inkFor(null)

    // The desktop row, for faces that draw what it names (a note).
    property var row: null

    readonly property var components: ({
        clock: clockBand,
        weather: weatherBand,
        github: githubBand,
        notes: notesBand,
        photo: photoBand
    })

    Loader {
        anchors.fill: parent
        sourceComponent: root.components[root.moduleId] ?? null
    }

    Component {
        id: clockBand

        WidgetFace {

            ink: root.ink
            id: clockFace

            readonly property string format: SettingsService.clockShowsSeconds
                ? SettingsService.clockFormat.replace("mm", "mm:ss")
                : SettingsService.clockFormat

            label: Qt.formatDateTime(clock.date, "dddd")
            reading: Qt.formatDateTime(clock.date, clockFace.format)
            note: Qt.formatDateTime(clock.date, "d MMMM yyyy")
            readingSize: Theme.fontSizeDisplay

            SystemClock {
                id: clock
                precision: SettingsService.clockShowsSeconds
                    ? SystemClock.Seconds : SystemClock.Minutes
            }

            Text {
                anchors.centerIn: parent
                text: "󰥔"
                font.family: Theme.fontMono
                font.pixelSize: 30
                color: root.ink.text
            }
        }
    }

    Component {
        id: weatherBand

        WidgetFace {

            ink: root.ink
            id: band

            readonly property var hoursAhead: {
                const hour = WeatherService.clock.date.getHours()
                return (WeatherService.available ? (WeatherService.hourly ?? []) : [])
                    .filter(block => block.tomorrow || block.hour > hour)
                    .slice(0, 6)
            }

            label: WeatherService.place || "Weather"
            reading: WeatherService.available ? `${WeatherService.temperature}°` : "--°"
            note: !WeatherService.available ? "no forecast"
                : WeatherService.description !== ""
                ? `${WeatherService.description} · feels ${WeatherService.feelsLike}° · ${WeatherService.high}° / ${WeatherService.low}°`
                : `feels ${WeatherService.feelsLike}° · ${WeatherService.high}° / ${WeatherService.low}°`
            readingSize: Theme.fontSizeDisplay
            extraShare: 0.55

            Text {
                anchors.centerIn: parent
                text: WeatherService.available ? WeatherService.glyph : "󰅤"
                font.family: Theme.fontMono
                font.pixelSize: 34
                color: root.ink.text
            }

            extra: [
                Row {
                    anchors.fill: parent

                    Repeater {
                        model: band.hoursAhead

                        Item {
                            id: block

                            required property var modelData

                            width: parent.width / Math.max(1, band.hoursAhead.length)
                            height: parent.height

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        const hour = `${block.modelData.hour}`.padStart(2, "0")
                                        return block.modelData.tomorrow
                                            ? `${hour}:00⁺` : `${hour}:00`
                                    }
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    color: root.ink.muted
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: block.modelData.glyph
                                    font.family: Theme.fontMono
                                    font.pixelSize: 24
                                    color: root.ink.text
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: `${block.modelData.temperature}°`
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: root.ink.text
                                }
                            }
                        }
                    }
                }
            ]
        }
    }

    // A note on one line, readable at a distance; see `NoteFace`.
    Component {
        id: notesBand

        NoteFace { ink: root.ink; row: root.row; family: "8x2" }
    }

    // A picture of your own, across the band; see `PhotoFace`.
    Component {
        id: photoBand

        PhotoFace { ink: root.ink; row: root.row; family: "8x2" }
    }

    // The whole contribution year; see `GithubFace`.
    Component {
        id: githubBand

        GithubFace { ink: root.ink; family: "8x2" }
    }
}
