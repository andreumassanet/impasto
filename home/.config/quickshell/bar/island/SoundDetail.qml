// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S O U N D   D E T A I L                                                │
// │   the level, the output, every application's level and the microphone    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯


import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"

// Opened from the control centre's volume, as a phone opens its volume into a
// page: the level, every application playing, and the outputs to choose from
// last, each a titled section. The microphone has a page of its own, behind
// its tile. Every level is a `LevelRow`, so the
// bars are one size and start at one place. Sizes are `AudioService`'s.
ColumnLayout {
    id: root

    signal back()

    spacing: Theme.detailGap

    DetailHeading {
        title: Tr.t("Sound")
        detail: AudioService.ready ? AudioService.outputName(AudioService.sink) : ""
        onBack: root.back()
    }

    DetailSection {
        title: Tr.t("Volume")

        LevelRow {
            glyph: AudioService.icon
            name: AudioService.ready ? AudioService.outputName(AudioService.sink) : ""
            value: AudioService.volume
            available: AudioService.ready
            dimmed: AudioService.muted
            onMoved: value => AudioService.setVolume(value)
            onMarkClicked: AudioService.toggleMute()
        }
    }

    DetailSection {
        title: Tr.t("Apps")
        visible: AudioService.streams.length > 0

        Repeater {
            model: AudioService.streams

            LevelRow {
                id: app

                required property var modelData

                picture: AudioService.streamIcon(app.modelData)
                name: AudioService.streamName(app.modelData)
                value: app.modelData.audio ? Math.round(app.modelData.audio.volume * 100) : 0
                dimmed: app.modelData.audio ? app.modelData.audio.muted : false
                onMoved: value => AudioService.setStreamVolume(app.modelData, value)
                onMarkClicked: AudioService.toggleStreamMute(app.modelData)
            }
        }
    }

    DetailSection {
        title: Tr.t("Output")

        Repeater {
            model: AudioService.outputs

            DetailChoice {
                required property var modelData

                text: AudioService.outputName(modelData)
                chosen: AudioService.sink === modelData
                onPicked: AudioService.choose(modelData)
            }
        }
    }

    DetailSection {
        title: Tr.t("Input")
        visible: AudioService.inputs.length > 0

        Repeater {
            model: AudioService.inputs

            DetailChoice {
                required property var modelData

                text: AudioService.outputName(modelData)
                chosen: AudioService.source === modelData
                onPicked: AudioService.chooseInput(modelData)
            }
        }
    }

    Item { Layout.fillHeight: true }
}
