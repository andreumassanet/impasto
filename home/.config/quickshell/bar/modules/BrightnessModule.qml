// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B R I G H T N E S S   M O D U L E                                      │
// │   brightness · the focused screen's ring, a slider per screen when open  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

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
                    progress: BrightnessService.percent / 100
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

    // One row per screen that can be dimmed; with only one, the row is
    // "Brightness" rather than the screen's name.
    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            Component.onCompleted: BrightnessService.refresh()

            Repeater {
                model: BrightnessService.dimmable

                RowLayout {
                    id: row

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    // Same white ring as the chip; only the slider follows the palette.
                    RingIndicator {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignVCenter
                        thickness: 3
                        progress: row.modelData.percent / 100
                        trackColor: Theme.indicatorDim
                        fillColor: Theme.indicator

                        Text {
                            anchors.centerIn: parent
                            text: row.modelData.icon
                            font.family: Theme.fontMono
                            font.pixelSize: 17
                            color: Theme.indicator
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: BrightnessService.dimmable.length > 1
                                    ? row.modelData.title : "Brightness"
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            Text {
                                text: `${row.modelData.percent}%`
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.text
                            }
                        }

                        // The whole strip is the hit area.
                        Item {
                            id: slider

                            Layout.fillWidth: true
                            Layout.preferredHeight: 16

                            UsageBar {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                implicitHeight: sliderMouse.containsMouse ? 6 : 4
                                progress: row.modelData.percent / 100
                                fillColor: Theme.accent

                                Behavior on implicitHeight {
                                    NumberAnimation {
                                        duration: Theme.durationFast
                                        easing.type: Theme.easing
                                    }
                                }
                            }

                            MouseArea {
                                id: sliderMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: event => row.modelData.setPercent(
                                    Math.round(event.x / slider.width * 100))
                                onPositionChanged: event => {
                                    if (pressed)
                                        row.modelData.setPercent(Math.max(0,
                                            Math.min(100,
                                                Math.round(event.x / slider.width * 100))))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
