// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M   E   D   I   A       F   A   C   E                                  │
// │   the record as a round sticker, and its buttons                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell.Widgets

import "../../../theme"
import "../../../services"

// The record as a round sticker with the cover on it, and the transport as
// round buttons stuck beside it: only play on a square, the three on a 4×2
// under the title's tag, and the same three under the record at 4×4.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)
    property string seed: ""

    readonly property bool something: MediaService.available
    readonly property real side: Math.min(root.width, root.height)
    readonly property string title: MediaService.title !== "" ? MediaService.title
        : (root.something ? MediaService.identity : Tr.t("Nothing playing"))
    readonly property string artist: root.something
        ? (MediaService.artist !== "" ? MediaService.artist : (MediaService.playing ? Tr.t("playing") : Tr.t("paused")))
        : Tr.t("no player on the bus")

    Tone { id: tone; hue: root.ink.accent }

    component Disc: Cut {
        id: disc

        shape: "circle"
        seed: root.seed
        fill: tone.deep

        ClippingRectangle {
            anchors.centerIn: parent
            width: disc.side * 0.66
            height: width
            radius: width / 2
            color: tone.hue

            Image {
                anchors.fill: parent
                visible: MediaService.artUrl !== ""
                source: MediaService.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 256
                sourceSize.height: 256
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: disc.side * 0.12
            height: width
            radius: width / 2
            color: disc.paper
        }
    }

    component Transport: Row {
        id: transport

        property real size: 48

        spacing: transport.size * 0.08

        Dot {
            anchors.verticalCenter: parent.verticalCenter
            width: transport.size * 0.78
            height: width
            seed: root.seed + "back"
            hue: root.ink.paper
            glyph: "󰒮"
            onClicked: MediaService.previous()
        }

        Dot {
            anchors.verticalCenter: parent.verticalCenter
            width: transport.size
            height: width
            seed: root.seed + "play"
            hue: root.ink.green
            glyph: MediaService.playing ? "󰏤" : "󰐊"
            onClicked: MediaService.toggle()
        }

        Dot {
            anchors.verticalCenter: parent.verticalCenter
            width: transport.size * 0.78
            height: width
            seed: root.seed + "next"
            hue: root.ink.paper
            glyph: "󰒭"
            onClicked: MediaService.next()
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.family === "4x4" ? large : room
    }

    Component {
        id: room

        Spread {
            family: root.family
            ink: root.ink
            seed: root.seed
            hue: root.ink.red
            reading: root.title
            note: root.artist
            filled: true

            Disc {
                anchors.fill: parent
            }

            Dot {
                visible: root.family === "2x2"
                x: parent.width * 0.64
                y: parent.height * 0.64
                width: parent.width * 0.4
                height: width
                seed: root.seed + "play"
                hue: root.ink.green
                glyph: MediaService.playing ? "󰏤" : "󰐊"
                onClicked: MediaService.toggle()
            }

            extra: [
                Transport {
                    size: Math.min(parent.height, 68)
                }
            ]
        }
    }

    Component {
        id: large

        Item {
            Disc {
                id: record

                anchors.horizontalCenter: parent.horizontalCenter
                y: root.side * 0.06
                width: root.side * 0.58
                height: width
            }

            Tag {
                id: title

                anchors.horizontalCenter: parent.horizontalCenter
                y: record.y + record.height - height * 0.3
                seed: root.seed + "tag"
                hue: root.ink.red
                reading: root.title
                note: root.artist
                size: 1.4
                room: root.width * 0.84
            }

            Transport {
                anchors.horizontalCenter: parent.horizontalCenter
                y: title.y + title.height + root.side * 0.02
                size: root.side * 0.17
            }
        }
    }
}
