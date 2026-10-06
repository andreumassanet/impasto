// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L Y R I C S   D E T A I L                                              │
// │   the player opened out · the cover, and the lyrics beside it            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// The music's detail when its lyrics are known: the cover large with the
// track, the progress and the transport under it, and the lyrics beside it,
// the line being sung lit and held in the middle. A line is a place in the
// song — a click goes there. Unsynced lyrics are the whole text, to scroll.
Item {
    id: root

    Component.onCompleted: LyricsService.subscribe()
    Component.onDestruction: LyricsService.release()

    // A card's margins, so it sits in the island as every detail does.
    readonly property int inset: Theme.cardInset + Theme.cardPadding
    readonly property int gap: 40
    readonly property int coverSize: root.height - 2 * root.inset - 120

    function clock(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds))
        const minutes = Math.floor(total / 60)
        const rest = total % 60
        return `${minutes}:${rest < 10 ? "0" : ""}${rest}`
    }

    // ── PLAYER ──────────────────────────────────────────────────────────────

    Column {
        id: player

        x: root.inset
        anchors.verticalCenter: parent.verticalCenter
        width: root.coverSize
        spacing: 14

        ClippingRectangle {
            width: root.coverSize
            height: width
            radius: width * Theme.pictureCorner * 0.5
            color: "transparent"

            Image {
                id: art

                anchors.fill: parent
                source: MediaService.artUrl
                visible: source != "" && status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Fixed, not the cover's size: the island grows round the
                // panel, and a size per frame would reload it per frame.
                sourceSize.width: 600
                sourceSize.height: 600
            }

            Text {
                anchors.centerIn: parent
                visible: !art.visible
                text: "󰎇"
                font.family: Theme.fontMono
                font.pixelSize: Math.round(root.coverSize * 0.6)
                color: Theme.text
            }
        }

        Column {
            width: parent.width
            spacing: 2

            Text {
                width: parent.width
                text: MediaService.title || MediaService.identity
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.text
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: MediaService.artist
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: Theme.textMuted
            }
        }

        // The whole strip is the hit area; it thickens under the pointer.
        Item {
            width: parent.width
            height: 22
            visible: MediaService.seekable

            UsageBar {
                id: track

                width: parent.width
                anchors.top: parent.top
                implicitHeight: seekMouse.containsMouse ? 6 : 4
                progress: MediaService.progress
                fillColor: Theme.indicator

                Behavior on implicitHeight {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: root.clock(MediaService.position)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: root.clock(MediaService.length)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            MouseArea {
                id: seekMouse

                width: parent.width
                height: 12
                hoverEnabled: true
                enabled: MediaService.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: event => MediaService.seek(event.x / width)
                onPositionChanged: event => {
                    if (pressed)
                        MediaService.seek(event.x / width)
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            IconButton {
                icon: "󰒮"
                iconSize: 17
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                enabled: MediaService.canPrevious
                opacity: enabled ? 1 : 0.3
                onClicked: MediaService.previous()
            }

            IconButton {
                icon: MediaService.playing ? "󰏤" : "󰐊"
                iconSize: 22
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                onClicked: MediaService.toggle()
            }

            IconButton {
                icon: "󰒭"
                iconSize: 17
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                enabled: MediaService.canNext
                opacity: enabled ? 1 : 0.3
                onClicked: MediaService.next()
            }
        }
    }

    // ── LYRICS ──────────────────────────────────────────────────────────────

    Item {
        id: sheet

        anchors.left: player.right
        anchors.leftMargin: root.gap
        anchors.right: parent.right
        anchors.rightMargin: root.inset
        anchors.top: parent.top
        anchors.topMargin: root.inset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.inset

        Text {
            anchors.centerIn: parent
            visible: LyricsService.instrumental
            text: Tr.t("Instrumental")
            font.family: Theme.fontDisplay
            font.pixelSize: 26
            font.weight: Font.Bold
            color: Theme.textMuted
        }

        ListView {
            id: lines

            anchors.fill: parent
            visible: !LyricsService.instrumental
            model: LyricsService.lines
            // The lines fade out at the top and the bottom rather than being
            // cut; drawn through a layer, so they still take the pointer.
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: fade
                // A gradient, not a cut-out: the mask's alpha is the fade.
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
            spacing: 14
            // Synced, the line being sung is held in the middle and nothing
            // scrolls by hand; unsynced, the text is there to be read.
            interactive: !LyricsService.synced
            currentIndex: LyricsService.synced ? LyricsService.current : -1
            highlightRangeMode: LyricsService.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
            preferredHighlightBegin: height / 2 - 20
            preferredHighlightEnd: height / 2 + 20
            highlightMoveDuration: Theme.durationMorph
            highlightFollowsCurrentItem: true
            header: Item { width: 1; height: LyricsService.synced ? 0 : lines.height / 3 }
            footer: Item { width: 1; height: lines.height / 3 }

            delegate: Text {
                id: verse

                required property var modelData
                required property int index

                readonly property int away: LyricsService.current < 0
                    ? (LyricsService.synced ? verse.index + 1 : 1)
                    : Math.abs(verse.index - LyricsService.current)

                width: lines.width
                text: verse.modelData.text !== "" ? verse.modelData.text : "♪"
                wrapMode: Text.Wrap
                font.family: Theme.fontDisplay
                font.pixelSize: 26
                font.weight: Font.Bold
                color: Theme.text
                opacity: verse.away === 0 ? 1 : Math.max(0.16, 0.42 - 0.09 * (verse.away - 1))

                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: LyricsService.synced && MediaService.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: MediaService.seek(verse.modelData.t / MediaService.length)
                }
            }
        }

        Rectangle {
            id: fade

            anchors.fill: parent
            visible: false
            layer.enabled: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.18; color: "white" }
                GradientStop { position: 0.82; color: "white" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
}
