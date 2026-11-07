// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B R I G H T N E S S   M O D U L E                                      │
// │   brightness · the focused screen's ring, a slider per screen when open  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// Hidden when no screen can be dimmed. The ring is white: brightness is a
// choice, not a warning.
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
                    progress: BrightnessService.slider / 100
                    trackColor: Theme.indicatorDim
                    fillColor: Theme.indicator

                    Text {
                        anchors.centerIn: parent
                        text: BrightnessService.icon
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(Theme.capsuleHeight * 0.38)
                        color: Theme.indicator
                    }
                }
            }
        }
    }

    // A level per screen that can be dimmed, named by the screen.
    Component {
        id: detail

        ModuleCard {
            title: Tr.t("Brightness")
            subtitle: BrightnessService.several
                ? Tr.t("%1 screens").arg(BrightnessService.dimmable.length)
                : Tr.t("One screen")
            figure: `${BrightnessService.slider}%`

            Component.onCompleted: BrightnessService.refresh()

            // Same white ring as the chip; only the levels follow the palette.
            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: BrightnessService.slider / 100
                trackColor: Theme.indicatorDim
                fillColor: Theme.indicator

                Text {
                    anchors.centerIn: parent
                    text: BrightnessService.icon
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: Theme.indicator
                }
            }

            Repeater {
                model: ScriptModel {
                    values: BrightnessService.dimmable
                }

                CardLevel {
                    id: screen

                    required property var modelData

                    glyph: screen.modelData.icon
                    name: screen.modelData.title
                    value: screen.modelData.slider
                    onMoved: value => screen.modelData.setSlider(value)
                }
            }
        }
    }
}
