// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   L   O   C   K       F   A   C   E                                  │
// │   the time as stickers · a lobed dial, or one per figure                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"

// A twelve-lobed dial with pill hands on a square, the minute hand red, and the date on a tag
// over its foot at 4×4. Wide, the time is one sticker per figure, each in a
// hue of its own, and the band adds the date beside them.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)
    property string seed: ""

    readonly property bool dial: root.family === "2x2" || root.family === "4x4"
    readonly property real side: Math.min(root.width, root.height)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.dial ? dialFace : figures
    }

    Component {
        id: dialFace

        Item {
            Tone { id: tone; hue: root.ink.accent }

            Cut {
                id: plate

                readonly property real middle: plate.width / 2
                readonly property real hours: clock.date.getHours() % 12 + clock.date.getMinutes() / 60
                readonly property real minutes: clock.date.getMinutes()

                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.family === "4x4" ? -root.side * 0.05 : 0
                width: root.side * (root.family === "4x4" ? 0.88 : 1)
                height: width
                shape: "cookie"
                lobes: 12
                seed: root.seed
                fill: tone.fill

                Repeater {
                    model: 12

                    Rectangle {
                        required property int index

                        readonly property real angle: index / 12 * 2 * Math.PI

                        width: plate.width * (index % 3 === 0 ? 0.055 : 0.034)
                        height: width
                        radius: width / 2
                        color: tone.deep
                        opacity: 0.8
                        x: plate.middle + plate.width * 0.35 * Math.cos(angle) - width / 2
                        y: plate.middle + plate.width * 0.35 * Math.sin(angle) - height / 2
                    }
                }

                // Hour hand, then minute hand, each turning about its foot.
                Rectangle {
                    x: plate.middle - width / 2
                    y: plate.middle - height + width / 2
                    width: plate.width * 0.08
                    height: plate.width * 0.27
                    radius: width / 2
                    color: tone.deep
                    transform: Rotation {
                        origin.x: plate.width * 0.04
                        origin.y: plate.width * 0.27 - plate.width * 0.04
                        angle: plate.hours * 30
                    }
                }

                Rectangle {
                    x: plate.middle - width / 2
                    y: plate.middle - height + width / 2
                    width: plate.width * 0.055
                    height: plate.width * 0.36
                    radius: width / 2
                    color: root.ink.red
                    transform: Rotation {
                        origin.x: plate.width * 0.0275
                        origin.y: plate.width * 0.36 - plate.width * 0.0275
                        angle: plate.minutes * 6
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: plate.width * 0.09
                    height: width
                    radius: width / 2
                    color: root.ink.paper
                }
            }

            Tag {
                visible: root.family === "4x4"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.side * 0.12
                y: plate.y + plate.height - height * 0.35
                seed: root.seed + "date"
                hue: root.ink.red
                reading: Tr.date(clock.date, "dddd")
                note: Tr.date(clock.date, "d MMMM yyyy")
                size: 1.5
                room: root.width * 0.8
            }
        }
    }

    Component {
        id: figures

        Item {
            // The time as the setting writes it, split into what gets a sticker.
            readonly property string stamp: Tr.date(clock.date, SettingsService.clockFormat)
            readonly property var parts: stamp.split(" ")[0].split("")
            readonly property var hues: [root.ink.accent, root.ink.red, root.ink.yellow,
                                         root.ink.green, root.ink.blue]
            // As tall as the band allows, and on a 4×2 as wide as the face.
            readonly property real tall: band ? root.height * 0.82
                : Math.min(root.height * 0.82, (root.width * 0.94 + 4 * root.height * 0.08) / 3.4)
            readonly property bool band: root.family === "8x2"

            Row {
                id: time

                x: parent.band ? root.height * 0.12 : (parent.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: -root.height * 0.08

                Repeater {
                    model: time.parent.parts

                    Cut {
                        id: figure

                        required property string modelData
                        required property int index

                        readonly property bool colon: figure.modelData === ":"

                        Tone { id: tone; hue: time.parent.hues[figure.index % 5] }

                        anchors.verticalCenter: parent.verticalCenter
                        width: time.parent.tall * (figure.colon ? 0.36 : 0.76)
                        height: time.parent.tall * (figure.colon ? 0.58 : 1)
                        shape: "soft"
                        seed: root.seed + figure.index
                        fill: tone.fill

                        Text {
                            anchors.centerIn: parent
                            text: figure.modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(time.parent.tall * (figure.colon ? 0.4 : 0.66))
                            font.weight: Font.Bold
                            color: tone.deep
                        }
                    }
                }
            }

            Tag {
                visible: parent.band || time.parent.stamp.indexOf(" ") > 0
                x: parent.band ? time.x + time.width + root.height * 0.1 : time.x + time.width - width * 0.6
                y: parent.band ? (parent.height - height) / 2 : parent.height - height - root.height * 0.02
                seed: root.seed + "date"
                hue: root.ink.paper
                reading: parent.band ? Tr.date(clock.date, "dddd")
                    : time.parent.stamp.split(" ")[1] ?? ""
                note: parent.band ? Tr.date(clock.date, "d MMMM yyyy") : ""
                size: parent.band ? 1.6 : 0.9
                room: parent.band ? parent.width - x - root.height * 0.1 : root.height
            }
        }
    }
}
