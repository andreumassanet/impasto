// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   V O L U M E   M O D U L E                                              │
// │   volume · sink level ring, slider when open                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The ring is the level and the glyph the output device; the detail is the
// output's and the microphone's levels, every application playing, and the
// outputs to choose from. The ring stays white: volume is a choice, not a
// warning.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    Component {
        id: chip

        Item {
            Item {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight

                RingIndicator {
                    anchors.fill: parent
                    thickness: 2.5
                    progress: AudioService.muted ? 0 : AudioService.volume / 100
                    trackColor: Theme.indicatorDim
                    fillColor: Theme.indicator

                    Text {
                        anchors.centerIn: parent
                        text: AudioService.icon
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(Theme.capsuleHeight * 0.38)
                        color: AudioService.muted ? Theme.textMuted : Theme.indicator
                    }
                }
            }
        }
    }

    Component {
        id: detail

        ModuleCard {
            title: "Sound"
            subtitle: AudioService.ready ? AudioService.outputName(AudioService.sink) : "No output"
            figure: AudioService.muted ? "Muted" : `${AudioService.volume}%`
            figureColor: AudioService.muted ? Theme.textMuted : Theme.text

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: AudioService.muted ? 0 : AudioService.volume / 100
                trackColor: Theme.indicatorDim
                fillColor: Theme.indicator

                Text {
                    anchors.centerIn: parent
                    text: AudioService.icon
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: AudioService.muted ? Theme.textMuted : Theme.indicator
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioService.toggleMute()
                }
            }

            CardLevel {
                glyph: AudioService.icon
                name: "Volume"
                value: AudioService.volume
                to: AudioService.ceiling
                dimmed: AudioService.muted
                available: AudioService.ready
                onMoved: value => AudioService.setVolume(value)
                onMarkClicked: AudioService.toggleMute()
            }

            CardLevel {
                glyph: AudioService.sourceIcon
                name: "Microphone"
                value: AudioService.sourceVolume
                dimmed: AudioService.sourceMuted
                available: AudioService.sourceReady
                onMoved: value => AudioService.setSourceVolume(value)
                onMarkClicked: AudioService.toggleSourceMute()
            }

            CardHeading {
                visible: AudioService.streams.length > 0
                text: "Apps"
            }

            Repeater {
                model: AudioService.streams

                CardLevel {
                    id: app

                    required property var modelData

                    picture: AudioService.streamIcon(app.modelData)
                    glyph: "󰝚"
                    name: AudioService.streamName(app.modelData)
                    value: app.modelData.audio ? Math.round(app.modelData.audio.volume * 100) : 0
                    dimmed: app.modelData.audio ? app.modelData.audio.muted : false
                    onMoved: value => AudioService.setStreamVolume(app.modelData, value)
                    onMarkClicked: AudioService.toggleStreamMute(app.modelData)
                }
            }

            CardHeading {
                visible: AudioService.outputs.length > 1
                text: "Output"
            }

            Repeater {
                model: AudioService.outputs.length > 1 ? AudioService.outputs : []

                CardChoice {
                    required property var modelData

                    text: AudioService.outputName(modelData)
                    chosen: AudioService.sink === modelData
                    onPicked: AudioService.choose(modelData)
                }
            }
        }
    }
}
