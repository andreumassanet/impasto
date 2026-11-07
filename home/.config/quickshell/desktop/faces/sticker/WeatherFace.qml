// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W   E   A   T   H   E   R       F   A   C   E                          │
// │   the sky as a sticker · sun, night or cloud                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"

// The sky as a sticker with the temperature on it: a yellow sun with rays
// by day, a blue disc by night, a blue cloud when it is wet or grey; the
// shape is keyed on the glyph `weather.py` chose. Wide, the sky's word on
// the tag and the next hours as small round stickers under it.
Spread {
    id: face

    readonly property bool known: WeatherService.available
    readonly property string glyph: face.known ? WeatherService.glyph : "󰖐"
    readonly property string sky: {
        switch (face.glyph) {
        case "󰖨": case "󰖕": return "sun"
        case "󰖔": case "󰼱": return "night"
        default: return "cloud"
        }
    }
    readonly property color tint: !face.known ? face.ink.muted
        : face.sky === "sun" ? face.ink.yellow : face.ink.blue

    readonly property var ahead: {
        const hour = WeatherService.clock.date.getHours()
        return (WeatherService.hourly ?? [])
            .filter(block => block.tomorrow || block.hour > hour)
            .slice(0, face.band ? 6 : 3)
    }

    line: face.known ? WeatherService.place : ""
    hue: face.tint
    reading: !face.known ? Tr.t("No forecast")
        : WeatherService.description !== "" ? WeatherService.description : WeatherService.place
    note: face.known ? `${WeatherService.place} · ${WeatherService.high}° / ${WeatherService.low}°`
        : Tr.t("no reading yet")
    filled: face.ahead.length > 0

    Tone { id: tone; hue: face.tint }

    Cut {
        id: plate

        anchors.fill: parent
        shape: face.sky === "night" ? "circle" : "cookie"
        lobes: face.sky === "sun" ? 9 : 5
        depth: face.sky === "sun" ? 0.12 : 0.08
        seed: face.seed
        fill: tone.fill

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -plate.side * 0.02

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.glyph
                font.family: Theme.fontMono
                font.pixelSize: Math.round(plate.side * 0.15)
                color: tone.deep
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.known ? `${WeatherService.temperature}°` : "—"
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(plate.side * 0.27)
                font.weight: Font.Bold
                color: tone.deep
            }
        }
    }

    extra: [
        Row {
            id: hours

            readonly property real side: Math.min(parent.height,
                (parent.width - (face.ahead.length - 1) * spacing) / Math.max(1, face.ahead.length))

            spacing: face.band ? 10 : 4

            Repeater {
                model: ScriptModel {
                    values: face.ahead
                }

                Cut {
                    id: hour

                    required property var modelData
                    required property int index

                    Tone { id: hourTone; hue: face.tint }

                    width: hours.side
                    height: hours.side
                    shape: "circle"
                    lean: Theme.stickerLean * 0.6
                    seed: face.seed + "hour" + hour.index
                    fill: hourTone.fill

                    Column {
                        anchors.centerIn: parent

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${hour.modelData.hour}`.padStart(2, "0") + (hour.modelData.tomorrow ? "⁺" : "h")
                            font.family: Theme.fontMono
                            font.pixelSize: Math.round(hour.side * 0.16)
                            color: hourTone.deep
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${hour.modelData.temperature}°`
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(hour.side * 0.26)
                            font.weight: Font.Bold
                            color: hourTone.deep
                        }
                    }
                }
            }
        }
    ]
}
