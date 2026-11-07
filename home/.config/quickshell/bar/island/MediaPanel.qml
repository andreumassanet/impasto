// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M E D I A   P A N E L                                                  │
// │   the player in the island · cover, track, controls and lyrics           │
// │                                                                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// The other design of the media piece (`SettingsService.mediaDesign`): a wide
// panel in place of the piece's card. The cover, in the shape the shell uses
// (`mediaCover`) and turning with the music when round, then the track, a
// seek bar, the controls, a switcher when more than one player is around, and
// the lyrics beside them, the line being sung large.
// Space plays or pauses, Left and Right seek by 5 seconds.
FocusScope {
    id: root

    signal closed()

    Component.onCompleted: {
        root.forceActiveFocus()
        MediaService.subscribe()
        LyricsService.subscribe()
    }
    Component.onDestruction: {
        MediaService.release()
        LyricsService.release()
        // A player picked here is picked for as long as the panel is open.
        MediaService.choose(null)
    }

    Keys.onSpacePressed: MediaService.toggle()
    Keys.onLeftPressed: MediaService.seek((MediaService.position - 5) / Math.max(1, MediaService.length))
    Keys.onRightPressed: MediaService.seek((MediaService.position + 5) / Math.max(1, MediaService.length))

    function clock(seconds: real): string {
        const whole = Math.max(0, Math.floor(seconds))
        return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`
    }

    Text {
        anchors.centerIn: parent
        visible: !MediaService.available
        text: Tr.t("Nothing is playing")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.textMuted
    }

    RowLayout {
        anchors.fill: parent
        visible: MediaService.available
        spacing: 24

        // The cover. A circle leaves room for its ring of bars.
        Item {
            id: disc

            Layout.preferredWidth: 270
            Layout.fillHeight: true

            CoverArt {
                anchors.centerIn: parent
                width: Math.min(disc.width, disc.height) - (SettingsService.mediaCover === "circle" ? 84 : 24)
                height: width
                spin: true
                cornerScale: 0.6
                // The island animates the panel's size; one decode serves all of it.
                sourceEdge: 600
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 320
            Layout.maximumWidth: 320
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 6

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                text: MediaService.title
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge + 3
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                Layout.fillWidth: true
                text: [MediaService.artist, MediaService.album].filter(part => part !== "").join(" · ")
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: Theme.textMuted
            }

            // The seek bar; a stream without a length has nothing to seek.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                Layout.topMargin: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.islandSurface

                    Rectangle {
                        width: parent.width * MediaService.progress
                        height: parent.height
                        radius: 3
                        color: Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: MediaService.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => MediaService.seek(mouse.x / width)
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.clock(MediaService.position)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.features: { "tnum": 1 }
                    color: Theme.textMuted
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.clock(MediaService.length)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.features: { "tnum": 1 }
                    color: Theme.textMuted
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 18

                IconButton {
                    icon: "󰒮"
                    iconSize: 20
                    enabled: MediaService.canPrevious
                    onClicked: MediaService.previous()
                }

                // Round at rest, a squircle while playing.
                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 52
                    radius: MediaService.playing ? 16 : 26
                    color: Theme.accent

                    Behavior on radius {
                        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: MediaService.playing ? "󰏤" : "󰐊"
                        font.family: Theme.fontMono
                        font.pixelSize: 24
                        color: Theme.accentText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaService.toggle()
                    }
                }

                IconButton {
                    icon: "󰒭"
                    iconSize: 20
                    enabled: MediaService.canNext
                    onClicked: MediaService.next()
                }
            }

            // The player switcher, with more than one player around.
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: MediaService.players.length > 1
                spacing: 6

                Repeater {
                    model: MediaService.players

                    Rectangle {
                        id: chip

                        required property var modelData
                        readonly property bool current: MediaService.active === chip.modelData

                        width: chipLabel.implicitWidth + 20
                        height: 26
                        radius: 13
                        color: chip.current ? Theme.accent : Theme.islandSurface

                        Text {
                            id: chipLabel

                            anchors.centerIn: parent
                            text: chip.modelData.identity || Tr.t("Player")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: chip.current ? Theme.accentText : Theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MediaService.choose(chip.modelData)
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // The lyrics: timed, the line being sung large and its neighbours
        // dimmed; untimed, as plain text; otherwise what is the matter.
        Item {
            id: words

            readonly property bool timed: LyricsService.available && LyricsService.synced

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Text {
                anchors.centerIn: parent
                width: parent.width
                visible: !words.timed
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: LyricsService.available && !LyricsService.instrumental
                    ? LyricsService.lines.slice(0, 10).map(line => line.text).join("\n")
                    : Tr.t(LyricsService.status !== "" ? LyricsService.status : "No lyrics")
                font.family: Theme.fontFamily
                font.pixelSize: LyricsService.available && !LyricsService.instrumental
                    ? Theme.fontSizeSmall : Theme.fontSizeRegular
                color: Theme.textMuted
            }

            ListView {
                anchors.fill: parent
                visible: words.timed
                model: words.timed ? LyricsService.lines : []
                currentIndex: Math.max(0, LyricsService.current)
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height / 2 - 20
                preferredHighlightEnd: height / 2 + 20
                highlightMoveDuration: Theme.durationMorph
                interactive: false
                spacing: 6

                delegate: Text {
                    required property var modelData
                    required property int index
                    readonly property bool current: index === LyricsService.current

                    width: ListView.view.width
                    wrapMode: Text.WordWrap
                    text: modelData.text || "♪"
                    font.family: Theme.fontFamily
                    font.pixelSize: current ? Theme.fontSizeLarge + 2 : Theme.fontSizeRegular
                    font.weight: current ? Font.DemiBold : Font.Normal
                    color: current ? Theme.text : Theme.textMuted
                    opacity: current ? 1 : Math.max(0.25, 1 - Math.abs(index - LyricsService.current) * 0.2)

                    Behavior on font.pixelSize { NumberAnimation { duration: Theme.durationFast } }
                }
            }
        }
    }
}
