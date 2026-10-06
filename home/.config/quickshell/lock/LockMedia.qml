// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L O C K   M E D I A                                                    │
// │   what is playing, on the lock · the cover, and the lyrics beside it     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

import "../theme"
import "../services"
import "../components"

// The player as the lock draws it: the cover large with the track, the
// progress and the transport under it, and — when the lyrics are asked for
// and known — the lyrics beside it, the line being sung lit and held level
// with the cover's middle. Type on the blur, shadowed like the clock, and no
// capsule: it is the lock's own page, not a panel opened on it.
Item {
    id: root

    // Whether the lyrics are wanted here; they show once they are known.
    property bool lyrics: false

    readonly property bool lined: root.lyrics && LyricsService.available
        && !LyricsService.instrumental
    readonly property int coverSize: 220
    readonly property int sheetWidth: 500
    readonly property int gap: 56

    implicitWidth: root.lined ? root.coverSize + root.gap + root.sheetWidth : root.coverSize
    implicitHeight: player.implicitHeight

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    Component.onCompleted: {
        MediaService.subscribe()
        if (root.lyrics)
            LyricsService.subscribe()
    }
    Component.onDestruction: {
        MediaService.release()
        if (root.lyrics)
            LyricsService.release()
    }
    onLyricsChanged: root.lyrics ? LyricsService.subscribe() : LyricsService.release()

    function clock(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds))
        const minutes = Math.floor(total / 60)
        const rest = total % 60
        return `${minutes}:${rest < 10 ? "0" : ""}${rest}`
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 1
        shadowOpacity: 0.45
        shadowVerticalOffset: 3
        shadowColor: Theme.island
    }

    // ── PLAYER ──────────────────────────────────────────────────────────────

    Column {
        id: player

        width: root.coverSize
        spacing: 12

        ClippingRectangle {
            width: root.coverSize
            height: width
            radius: width * Theme.pictureCorner * 0.5
            color: art.status === Image.Ready ? "transparent" : Theme.island

            Image {
                id: art

                anchors.fill: parent
                source: MediaService.artUrl
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 2 * root.coverSize
                sourceSize.height: 2 * root.coverSize
            }

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "󰎇"
                font.family: Theme.fontMono
                font.pixelSize: Math.round(root.coverSize * 0.5)
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
                horizontalAlignment: root.lined ? Text.AlignLeft : Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge + 1
                font.weight: Font.Bold
                color: Theme.text
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: MediaService.artist
                elide: Text.ElideRight
                horizontalAlignment: root.lined ? Text.AlignLeft : Text.AlignHCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.text
                opacity: 0.7
            }
        }

        Item {
            width: parent.width
            height: 22
            visible: MediaService.seekable

            UsageBar {
                width: parent.width
                anchors.top: parent.top
                implicitHeight: 4
                progress: MediaService.progress
                fillColor: Theme.text
                trackColor: Qt.rgba(1, 1, 1, 0.25)
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: root.clock(MediaService.position)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.text
                opacity: 0.7
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: root.clock(MediaService.length)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.text
                opacity: 0.7
            }
        }

        // Pressed without waking the lock: the music is what is being
        // reached for, not the password.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            Repeater {
                model: [
                    { glyph: "󰒮", size: 20, live: MediaService.canPrevious, act: () => MediaService.previous() },
                    { glyph: MediaService.playing ? "󰏤" : "󰐊", size: 28, live: MediaService.canToggle, act: () => MediaService.toggle() },
                    { glyph: "󰒭", size: 20, live: MediaService.canNext, act: () => MediaService.next() }
                ]

                Item {
                    id: control

                    required property var modelData

                    width: 44
                    height: 44
                    opacity: control.modelData.live ? 1 : 0.35

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.14)
                        opacity: press.containsMouse && control.modelData.live ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: control.modelData.glyph
                        font.family: Theme.fontMono
                        font.pixelSize: control.modelData.size
                        color: Theme.text
                    }

                    MouseArea {
                        id: press

                        anchors.fill: parent
                        enabled: control.modelData.live
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: control.modelData.act()
                    }
                }
            }
        }
    }

    // ── LYRICS ──────────────────────────────────────────────────────────────

    Item {
        id: sheet

        x: root.coverSize + root.gap
        width: root.sheetWidth
        height: player.height
        visible: opacity > 0
        opacity: root.lined ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
        }

        ListView {
            id: lines

            anchors.fill: parent
            model: root.lined ? LyricsService.lines : []
            spacing: 12
            interactive: !LyricsService.synced
            currentIndex: LyricsService.synced ? LyricsService.current : -1
            highlightRangeMode: LyricsService.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
            // Level with the middle of the cover.
            preferredHighlightBegin: root.coverSize / 2 - 17
            preferredHighlightEnd: root.coverSize / 2 + 17
            highlightMoveDuration: Theme.durationMorph
            header: Item { width: 1; height: LyricsService.synced ? 0 : root.coverSize / 3 }
            footer: Item { width: 1; height: lines.height }

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: fade
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

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
                opacity: verse.away === 0 ? 1 : Math.max(0.18, 0.45 - 0.09 * (verse.away - 1))

                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
                }
            }
        }

        Rectangle {
            id: fade

            anchors.fill: lines
            visible: false
            layer.enabled: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: "white" }
                GradientStop { position: 0.8; color: "white" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
}
