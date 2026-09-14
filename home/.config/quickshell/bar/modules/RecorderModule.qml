// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   R E C O R D E R   M O D U L E                                          │
// │   screen recorder · recording indicator and elapsed time                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// A recording changes nothing on screen, so the bar is where it shows. Idle,
// the chip is a muted camera and the detail starts a take; while recording,
// the chip counts up and the detail stops it.
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

                // A red ring with a breathing dot. `indicatorBad`, not `red`:
                // warnings don't follow the palette, and one palette's red is
                // pink. The dot fades to 0.4 rather than blinking, so it never
                // disappears.
                RingIndicator {
                    anchors.fill: parent
                    visible: RecorderService.recording
                    thickness: 2.5
                    progress: 1
                    trackColor: Theme.indicatorDim
                    fillColor: Theme.indicatorBad

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(Theme.capsuleHeight * 0.3)
                        height: width
                        radius: width / 2
                        color: Theme.indicatorBad

                        SequentialAnimation on opacity {
                            running: RecorderService.recording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 900; easing.type: Theme.easing }
                            NumberAnimation { to: 1;   duration: 900; easing.type: Theme.easing }
                        }
                    }
                }

                RingIndicator {
                    anchors.fill: parent
                    visible: !RecorderService.recording
                    thickness: 2.5
                    progress: 0
                    trackColor: Theme.indicatorDim

                    Text {
                        anchors.centerIn: parent
                        text: "󰕧"
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(Theme.capsuleHeight * 0.38)
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: Theme.islandSurface
                    border.color: RecorderService.recording
                        ? Theme.indicatorBad : Theme.islandBorder
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: RecorderService.recording
                        width: 14
                        height: 14
                        radius: 7
                        color: Theme.indicatorBad
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !RecorderService.recording
                        text: "󰕧"
                        font.family: Theme.fontMono
                        font.pixelSize: 18
                        color: Theme.textMuted
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: RecorderService.recording
                            ? RecorderService.display : "Not recording"
                        elide: Text.ElideRight
                        font.family: RecorderService.recording
                            ? Theme.fontMono : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    // Describes the next take, or the last one.
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (RecorderService.recording)
                                return RecorderService.name
                            if (RecorderService.name !== "")
                                return `Last · ${RecorderService.name}`
                            const parts = [RecorderService.subject]
                            if (SettingsService.recorderAudio && RecorderService.canAudio)
                                parts.push("with sound")
                            parts.push(RecorderService.tool)
                            return parts.join(" · ")
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }

                PillButton {
                    Layout.alignment: Qt.AlignVCenter
                    text: RecorderService.recording ? "Stop" : "Record"
                    implicitHeight: 28
                    implicitWidth: 78
                    onClicked: RecorderService.toggle(CaptureService.settle)
                }
            }

            // Before a take, this row sets its options; during one, it
            // describes it. The row keeps its height either way.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9
                    visible: !RecorderService.recording

                    // Same three shapes as the capture surface.
                    // Screen starts at once; region and window open the surface
                    // to pick.
                    SegmentedControl {
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 28
                        options: [
                            { id: "region", label: "Region" },
                            { id: "window", label: "Window" },
                            { id: "screen", label: "Screen" }
                        ]
                        current: SettingsService.recorderShape
                        onSelected: id => SettingsService.set("recorderShape", id)
                    }

                    // This button takes the spare width: a SegmentedControl
                    // given extra width centres its segments and leaves gaps at
                    // both ends.
                    PillButton {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 28
                        implicitWidth: 96
                        enabled: RecorderService.canAudio
                        // System audio, not the microphone.
                        text: SettingsService.recorderAudio ? "Sound on" : "Sound off"
                        active: SettingsService.recorderAudio
                        onClicked: SettingsService.set("recorderAudio",
                                                       !SettingsService.recorderAudio)
                    }
                }

                // Region, audio and file size of the running take. These come
                // from what `record.py` reports, not from the settings, so they
                // stay correct if a setting changes mid-take or the shell
                // restarts.
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    visible: RecorderService.recording

                    Repeater {
                        model: [
                            { label: "Taking", value: RecorderService.subject },
                            { label: "Sound", value: RecorderService.sound
                                ? "On" : "Off" },
                            // Same formatter as the machine card.
                            { label: "Size",
                              value: StatsService.bytes(RecorderService.size) }
                        ]

                        ColumnLayout {
                            id: reading

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 1

                            Text {
                                text: reading.modelData.label.toUpperCase()
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.6
                                color: Theme.textMuted
                            }

                            Text {
                                Layout.fillWidth: true
                                text: reading.modelData.value
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                        }
                    }
                }
            }

            // Polls the file size only while the detail exists, not for the
            // whole take.
            Timer {
                interval: 2000
                repeat: true
                running: RecorderService.recording
                triggeredOnStart: true
                onTriggered: RecorderService.measure()
            }
        }
    }
}
