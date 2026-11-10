// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T   I   M   E   R       F   A   C   E                                  │
// │   the time left as a ring · sticker                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"

// The time left as a ring on a seven-lobed sticker, the countdown inside it.
// Wide, the label on the tag and two round buttons under it: five minutes,
// or hold and resume, and cancel.
Spread {
    id: face

    readonly property bool on: TimerService.running
    readonly property color tint: face.on ? face.ink.red : face.ink.muted

    hue: face.tint
    reading: face.on ? TimerService.display : Tr.t("Timer")
    note: face.on ? (TimerService.label !== "" ? TimerService.label
        : (TimerService.paused ? Tr.t("held") : Tr.t("counting down"))) : Tr.t("nothing running")
    filled: true

    Tone { id: tone; hue: face.tint }

    Cut {
        id: plate

        anchors.fill: parent
        shape: "cookie"
        lobes: 7
        depth: 0.07
        seed: face.seed
        fill: tone.fill

        Ring {
            anchors.centerIn: parent
            width: plate.side * 0.66
            height: width
            thickness: plate.side * 0.075
            fraction: face.on && TimerService.duration > 0 ? TimerService.remaining / TimerService.duration : 0
            color: tone.deep
            track: tone.track
        }

        Text {
            anchors.centerIn: parent
            text: face.on ? TimerService.display : "󱎫"
            font.family: face.on ? Theme.fontFamily : Theme.fontMono
            font.pixelSize: Math.round(plate.side * (face.on ? 0.15 : 0.26))
            font.weight: Font.Bold
            color: tone.deep
        }
    }

    extra: [
        Row {
            spacing: 6

            Dot {
                width: Math.min(face.height * 0.32, 64)
                height: width
                seed: face.seed + "go"
                hue: face.ink.green
                glyph: TimerService.running && !TimerService.paused ? "󰏤" : "󰐊"
                onClicked: {
                    if (!TimerService.running)
                        TimerService.start(5 * 60 * 1000, "")
                    else
                        TimerService.toggle()
                }
            }

            Dot {
                width: Math.min(face.height * 0.32, 64)
                height: width
                visible: TimerService.running
                seed: face.seed + "stop"
                hue: face.ink.paper
                glyph: "󰅖"
                onClicked: TimerService.cancel()
            }
        }
    ]
}
