// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M   E   D   I   A       F   A   C   E                                  │
// │   what is playing as a record · it turns while it plays                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// A record on a turntable, with the title under it on a 2×2 and beside it on a
// 4×2, and the transport and progress under the text. At 4×4 the transport
// moves into the body and the album gets a line.
Instrument {
    id: face

    readonly property bool something: MediaService.available

    line: MediaService.title !== "" ? MediaService.title
        : (face.something ? MediaService.identity : Tr.t("Nothing playing"))
    reading: MediaService.title !== "" ? MediaService.title
        : (face.something ? MediaService.identity : Tr.t("Nothing playing"))
    note: face.something
        ? `${MediaService.artist !== "" ? MediaService.artist + " · " : ""}${MediaService.playing ? Tr.t("playing") : Tr.t("paused")}`
        : Tr.t("no player on the bus")
    filled: true

    Record {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height)
        playing: MediaService.playing
        art: MediaService.artUrl
    }

    extra: [
        Column {
            visible: !face.large
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 8

            UsageBar {
                width: parent.width
                progress: MediaService.progress
                fillColor: face.ink.accent
                trackColor: face.ink.raised
            }

            Row {
                spacing: 16

                IconButton {
                    iconColor: face.ink.text
                    icon: "󰒮"
                    iconSize: 16
                    onClicked: MediaService.previous()
                }

                IconButton {
                    iconColor: face.ink.text
                    icon: MediaService.playing ? "󰏤" : "󰐊"
                    iconSize: 18
                    onClicked: MediaService.toggle()
                }

                IconButton {
                    iconColor: face.ink.text
                    icon: "󰒭"
                    iconSize: 16
                    onClicked: MediaService.next()
                }
            }
        }
    ]

    body: [
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Text {
                width: parent.width
                text: MediaService.album !== "" ? MediaService.album : MediaService.identity
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: face.ink.muted
            }

            UsageBar {
                width: parent.width
                progress: MediaService.progress
                fillColor: face.ink.accent
                trackColor: face.ink.raised
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28

                IconButton {
                    iconColor: face.ink.text
                    icon: "󰒮"
                    iconSize: 22
                    onClicked: MediaService.previous()
                }

                IconButton {
                    iconColor: face.ink.text
                    icon: MediaService.playing ? "󰏤" : "󰐊"
                    iconSize: 26
                    onClicked: MediaService.toggle()
                }

                IconButton {
                    iconColor: face.ink.text
                    icon: "󰒭"
                    iconSize: 22
                    onClicked: MediaService.next()
                }
            }
        }
    ]
}
