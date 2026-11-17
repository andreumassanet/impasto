// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P L A Y E R   C A R D                                                  │
// │   one MPRIS player on its own card · for the media panel's all-players   │
// │   layout                                                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// Every control talks to `player`, not to `MediaService.active`, so a player
// is driven without first being made the one the shell shows. Clicking the
// cover or the name makes it that one.
Rectangle {
    id: root

    required property var modelData
    readonly property MprisPlayer player: root.modelData

    readonly property bool current: MediaService.active === root.player
    readonly property real length: {
        const reported = root.player.length ?? 0
        return reported > 0 && reported < 86400 ? reported : 0
    }
    readonly property real progress: root.length > 0
        ? Math.max(0, Math.min(1, (root.player.position ?? 0) / root.length)) : 0

    radius: Theme.pictureCorner
    color: Theme.islandSurface
    border.width: root.current ? 2 : 0
    border.color: Theme.accent

    // MPRIS does not push position; only this card's own player is polled.
    Timer {
        interval: 1000
        repeat: true
        running: root.player.isPlaying && root.length > 0
        onTriggered: root.player.positionChanged()
    }

    function clock(seconds: real): string {
        const whole = Math.max(0, Math.floor(seconds))
        return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ClippingRectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                radius: Theme.pictureCorner * 72 * 0.6
                color: Theme.surfaceHoverIn(QsWindow.window)

                Image {
                    anchors.fill: parent
                    source: root.player.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 192
                    sourceSize.height: 192
                }

                TapHandler { onTapped: MediaService.choose(root.player) }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: MediaService.nameOf(root.player) || Tr.t("Player")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.current ? Theme.accent : Theme.textMuted
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player.trackTitle ?? ""
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
                    text: root.player.trackArtist ?? ""
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }
        }

        Item { Layout.fillHeight: true }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            visible: root.length > 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 5
                radius: 2.5
                color: Theme.surfaceHoverIn(QsWindow.window)

                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.player.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => root.player.position = (mouse.x / width) * root.length
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            IconButton {
                icon: "󰒮"
                iconSize: 18
                enabled: root.player.canGoPrevious
                onClicked: root.player.previous()
            }

            IconButton {
                icon: root.player.isPlaying ? "󰏤" : "󰐊"
                iconSize: 22
                enabled: root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }

            IconButton {
                icon: "󰒭"
                iconSize: 18
                enabled: root.player.canGoNext
                onClicked: root.player.next()
            }
        }
    }
}
