// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W E A T H E R   M O D U L E                                            │
// │   weather · condition icon, hourly forecast when open                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"

// Condition glyph and temperature on the chip; the detail adds the location,
// feels-like and the next hours. Shows the reading's age, since it comes from
// the network.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: WeatherService.subscribe()
    Component.onDestruction: WeatherService.release()

    // Six hours rather than the card's four: this detail is wider.
    readonly property var hoursAhead: {
        const hour = WeatherService.clock.date.getHours()
        return (WeatherService.hourly ?? [])
            .filter(block => block.tomorrow || block.hour > hour)
            .slice(0, 6)
    }

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                Text {
                    text: WeatherService.glyph
                    font.family: Theme.fontMono
                    font.pixelSize: 30
                    color: Theme.indicator
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: WeatherService.place
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            text: `${WeatherService.temperature}°`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            const parts = []
                            if (WeatherService.description !== "")
                                parts.push(WeatherService.description)
                            parts.push(`feels ${WeatherService.feelsLike}°`)
                            if (WeatherService.age !== "")
                                parts.push(WeatherService.age)
                            return parts.join(" · ")
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            // Columns divide the width by hand: a RowLayout sizes from its
            // children's implicit widths and packs them to the left.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.hoursAhead.length > 0

                Row {
                    anchors.fill: parent

                    Repeater {
                        model: ScriptModel {
                            values: root.hoursAhead
                        }

                        Item {
                            id: block

                            required property var modelData

                            width: parent.width / Math.max(1, root.hoursAhead.length)
                            height: parent.height

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        const hour = `${block.modelData.hour}`.padStart(2, "0")
                                        return block.modelData.tomorrow
                                            ? `${hour}:00⁺` : `${hour}:00`
                                    }
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    color: Theme.textMuted
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: block.modelData.glyph
                                    font.family: Theme.fontMono
                                    font.pixelSize: 15
                                    color: Theme.indicator
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: `${block.modelData.temperature}°`
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    color: Theme.text
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
