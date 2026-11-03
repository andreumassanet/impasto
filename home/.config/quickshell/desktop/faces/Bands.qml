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
import "../../components"

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
        screentime: screenTimeBand,
        markets: marketsBand,
        notes: notesBand,
        photo: photoBand,
        spectrum: spectrumBand
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

            WeatherIcon {
                anchors.centerIn: parent
                name: WeatherService.available ? WeatherService.icon : ""
                glyph: WeatherService.available ? WeatherService.glyph : ""
                size: 40
            }

            extra: [
                Row {
                    anchors.fill: parent

                    Repeater {
                        model: ScriptModel {
                            values: band.hoursAhead
                        }

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

                                WeatherIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: block.modelData.icon ?? ""
                                    glyph: block.modelData.glyph
                                    size: 28
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

    // The bars in a capsule; see `SpectrumFace`.
    Component {
        id: spectrumBand

        SpectrumFace { ink: root.ink; row: root.row; family: "8x2" }
    }

    // The first pair large, and up to three more beside it, each with its
    // line.
    Component {
        id: marketsBand

        WidgetFace {
            id: marketsFace

            ink: root.ink
            label: MarketsService.lead ? `${MarketsService.lead.base}/${MarketsService.lead.quote}` : "Markets"
            note: !MarketsService.lead
                ? (MarketsService.pairs.length === 0 ? "nothing on the list" : "no prices")
                : `${MarketsService.change(MarketsService.lead)} · ${MarketsService.lead.period}`
            noteTint: MarketsService.lead ? MarketsService.tint(MarketsService.lead) : root.ink.muted

            Text {
                anchors.centerIn: parent
                text: MarketsService.glyph(MarketsService.lead)
                font.family: Theme.fontMono
                font.pixelSize: 34
                color: root.ink.text
            }
            reading: MarketsService.price(MarketsService.lead)
            readingSize: Theme.fontSizeDisplay * 0.65
            extraShare: MarketsService.others.length > 0 ? 0.6 : 0.5

            readonly property var columns: MarketsService.others.length > 0
                ? MarketsService.others.slice(0, 3) : []

            extra: [
                Sparkline {
                    visible: marketsFace.columns.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 64
                    values: MarketsService.shape(MarketsService.lead)
                    stroke: MarketsService.tint(MarketsService.lead)
                    thickness: 2
                },

                Row {
                    anchors.fill: parent
                    spacing: 18
                    visible: marketsFace.columns.length > 0

                    Repeater {
                        model: ScriptModel {
                            values: marketsFace.columns
                        }

                        Column {
                            id: column

                            required property var modelData

                            width: (parent.width - 18 * (marketsFace.columns.length - 1))
                                / marketsFace.columns.length
                            anchors.bottom: parent.bottom
                            spacing: 3

                            Sparkline {
                                width: parent.width
                                height: 34
                                values: MarketsService.shape(column.modelData)
                                stroke: MarketsService.tint(column.modelData)
                                showDot: false
                            }

                            Text {
                                width: parent.width
                                text: MarketsService.price(column.modelData)
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeRegular
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                                color: root.ink.text
                            }

                            Text {
                                width: parent.width
                                text: `${column.modelData.base} ${MarketsService.change(column.modelData)}`
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: MarketsService.tint(column.modelData)
                            }
                        }
                    }
                }
            ]
        }
    }

    // Today large, its hours, and the sessions in a line under them.
    Component {
        id: screenTimeBand

        WidgetFace {
            ink: root.ink
            label: Tr.t("Screen time")
            reading: ScreenTimeService.duration(ScreenTimeService.todayTotal)
            note: ScreenTimeService.todayNote

            UsageRing {
                anchors.fill: parent
                anchors.margins: 4
                parts: ScreenTimeService.todayParts
                thickness: 5
                accent: root.ink.accent
                ink: root.ink.text
            }
            readingSize: Theme.fontSizeDisplay * 0.65
            extraShare: 0.6

            extra: [
                Column {
                    anchors.fill: parent
                    spacing: 8

                    UsageBars {
                        width: parent.width
                        height: parent.height - 18
                        stacks: ScreenTimeService.todayDigest.stacks
                        ceiling: 3600
                        gap: 3
                        accent: root.ink.accent
                        ink: root.ink.text
                    }

                    SessionRibbon {
                        width: parent.width
                        height: 10
                        sessions: ScreenTimeService.todayDigest.sessions
                        accent: root.ink.accent
                        ink: root.ink.text
                    }
                }
            ]
        }
    }
}
