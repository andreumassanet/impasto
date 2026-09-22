// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W E A T H E R   C A R D                                                │
// │   weather · now and the rest of the day                                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// Current conditions and the next few hours from wttr.in, which geolocates by
// IP, so the location is shown as part of the reading.
//
// One row: a single line. Two rows: now. Three: the rest of the day below it.
// Four columns: the two side by side.
Card {
    id: root

    property int cols: 2
    property int rows: 3

    readonly property bool oneLine: root.rows <= 1
    readonly property bool beside: root.cols >= 4 && root.rows <= 2
    readonly property bool showAhead: !root.oneLine && (root.rows >= 3 || root.beside)

    Component.onCompleted: WeatherService.subscribe()
    Component.onDestruction: WeatherService.release()

    // ── LINE ────────────────────────────────────────────────────────────────

    RowLayout {
        anchors.fill: parent
        visible: root.oneLine
        spacing: 10

        Text {
            text: WeatherService.available ? WeatherService.glyph : "󰅤"
            font.family: Theme.fontMono
            font.pixelSize: 22
            color: Theme.accent
        }

        Text {
            text: WeatherService.available ? `${WeatherService.temperature}°` : "—"
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Text {
            Layout.fillWidth: true
            text: WeatherService.available
                ? `${WeatherService.description}  ·  feels ${WeatherService.feelsLike}°`
                : "No reading"
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }

        Text {
            visible: WeatherService.available
            text: `${WeatherService.high}° / ${WeatherService.low}°`
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeLabel
            color: Theme.textMuted
        }
    }

    // ── CARD ────────────────────────────────────────────────────────────────

    GridLayout {
        anchors.fill: parent
        visible: !root.oneLine
        columns: root.beside ? 2 : 1
        rowSpacing: 10
        columnSpacing: 16

        // ── NOW ─────────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            // Side by side, equal preferred widths so the two halves split the
            // card evenly.
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 12

            Text {
                text: WeatherService.available ? WeatherService.glyph : "󰅤"
                font.family: Theme.fontMono
                font.pixelSize: 40
                color: Theme.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: WeatherService.available
                            ? `${WeatherService.temperature}°`
                            : "—"
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    // Pushed to the far edge.
                    Item { Layout.fillWidth: true }

                    Text {
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 5
                        visible: WeatherService.available
                        text: `${WeatherService.high}° / ${WeatherService.low}°`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: WeatherService.available
                        ? `${WeatherService.description}  ·  feels ${WeatherService.feelsLike}°`
                        : "No reading"
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                // Location and age share the line under the conditions to save
                // a row for the calendar in the same column.
                Text {
                    Layout.fillWidth: true
                    visible: WeatherService.available
                    text: `󰍎 ${WeatherService.place}, ${WeatherService.region}`
                        + `  ·  ${WeatherService.age}`
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                    opacity: 0.75
                }
            }
        }

        // Only when stacked: keeps the hours at the bottom of the card.
        Item {
            Layout.fillHeight: true
            visible: !root.beside
        }

        // ── REST OF THE DAY ─────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: root.beside ? Qt.AlignVCenter : Qt.AlignBottom
            spacing: 6
            visible: root.showAhead && WeatherService.ahead.length > 0

            Repeater {
                model: ScriptModel {
                    values: WeatherService.ahead
                }

                // A filling Item holding a centred Column: `Layout.fillWidth`
                // and `Layout.alignment` on the same item conflict, since an
                // alignment stops the layout from resizing it.
                Item {
                    id: block

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: stack.implicitHeight

                    Column {
                        id: stack

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            // Marks hours past midnight, so 21, 0, 3, 6 doesn't
                            // read as a broken sort.
                            text: {
                                const hour = `${block.modelData.hour}`.padStart(2, "0")
                                return block.modelData.tomorrow ? `${hour}:00⁺` : `${hour}:00`
                            }
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: block.modelData.glyph
                            font.family: Theme.fontMono
                            font.pixelSize: 16
                            color: Theme.text
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${block.modelData.temperature}°`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        // Only when there is some chance of rain.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: block.modelData.rain >= 20
                            text: `${block.modelData.rain}%`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.blue
                        }
                    }
                }
            }
        }
    }
}
