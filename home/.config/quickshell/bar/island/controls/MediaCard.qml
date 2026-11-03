// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M E D I A   C A R D                                                    │
// │   the player, with room for artwork and transport                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Widgets

import "../../../theme"
import "../../../services"
import "../../../components"

Card {
    id: root

    // The cover opens the media card; the buttons stay the player's.
    signal panelRequested(string panel)

    Component.onCompleted: MediaService.subscribe()
    Component.onDestruction: MediaService.release()

    Text {
        anchors.centerIn: parent
        visible: !MediaService.available
        text: "Nothing playing"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted
    }

    ColumnLayout {
        anchors.fill: parent
        visible: MediaService.available
        spacing: 11

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            CoverArt {
                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
                HoverHandler { cursorShape: Qt.PointingHandCursor }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.panelRequested("media")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: MediaService.title
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeRegular
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: MediaService.artist
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Progress, only when the track has a length.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            visible: MediaService.seekable
            radius: 1.5
            color: Theme.surfaceHoverIn(QsWindow.window)

            Rectangle {
                width: parent.width * MediaService.progress
                height: parent.height
                radius: parent.radius
                color: Theme.accent

                Behavior on width {
                    NumberAnimation { duration: 900; easing.type: Easing.Linear }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: root.clock(MediaService.position)
                visible: MediaService.seekable
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            Item { Layout.fillWidth: true }

            IconButton {
                icon: "󰒮"
                iconSize: 15
                enabled: MediaService.canPrevious
                opacity: MediaService.canPrevious ? 1 : 0.35
                onClicked: MediaService.previous()
            }

            IconButton {
                icon: MediaService.playing ? "󰏤" : "󰐊"
                iconSize: 18
                onClicked: MediaService.toggle()
            }

            IconButton {
                icon: "󰒭"
                iconSize: 15
                enabled: MediaService.canNext
                opacity: MediaService.canNext ? 1 : 0.35
                onClicked: MediaService.next()
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.clock(MediaService.length)
                visible: MediaService.seekable
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }
        }
    }

    function clock(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds))
        const minutes = Math.floor(total / 60)
        const remainder = total % 60
        return `${minutes}:${remainder < 10 ? "0" : ""}${remainder}`
    }
}
