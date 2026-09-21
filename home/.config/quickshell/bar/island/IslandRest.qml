// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I S L A N D   R E S T                                                  │
// │   resting island · the clock and running activities                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"
import "../modules"

// The island at rest: the clock in the middle, with a recording, countdown or
// track either side while one is running (one item split across both sides,
// mark leading and figure trailing, or one item per side).
//
// A recording stops with one click here, since nothing else on screen can stop
// it; the dot squares off under the pointer to show that. A countdown or a
// track opens its detail.
Item {
    id: root

    readonly property var activities: ModuleService.activities
    readonly property bool split: root.activities.length === 1

    // A side under the pointer holds the glance off, so a click on the dot
    // never lands on a summary that opened under it.
    readonly property bool busy: leading.hovered || trailing.hovered

    ClockModule {
        anchors.centerIn: parent
        width: root.activities.length > 0 ? ModuleService.clockCore : parent.width
        height: Theme.capsuleHeight
    }

    Segment {
        id: leading

        anchors.left: parent.left
        width: ModuleService.activitySide
        height: parent.height
        visible: root.activities.length > 0
        activityId: root.activities[0] ?? ""
        part: root.split ? "mark" : "both"
    }

    Segment {
        id: trailing

        anchors.right: parent.right
        width: ModuleService.activitySide
        height: parent.height
        visible: root.activities.length > 0
        activityId: root.split ? (root.activities[0] ?? "") : (root.activities[1] ?? "")
        part: root.split ? "figure" : "both"
    }

    component Segment: Item {
        id: segment

        property string activityId: ""

        // "mark", "figure", or "both".
        property string part: "both"

        readonly property alias hovered: mouse.containsMouse

        readonly property var marks: ({
            recorder: recorderMark, timer: timerMark, media: mediaMark
        })
        readonly property var figures: ({
            recorder: recorderFigure, timer: timerFigure, media: mediaFigure
        })

        Row {
            anchors.centerIn: parent
            spacing: 7

            Loader {
                anchors.verticalCenter: parent.verticalCenter
                active: segment.part !== "figure" && segment.activityId !== ""
                visible: active
                sourceComponent: segment.marks[segment.activityId] ?? null
            }

            Loader {
                anchors.verticalCenter: parent.verticalCenter
                active: segment.part !== "mark" && segment.activityId !== ""
                visible: active
                sourceComponent: segment.figures[segment.activityId] ?? null
            }
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (segment.activityId === "recorder")
                    RecorderService.toggle()
                else
                    ModuleService.activate(segment.activityId)
            }
        }

        // ── RECORDING ───────────────────────────────────────────────────────
        //
        // `indicatorBad`, not the palette's red: warnings do not follow the
        // palette. It breathes rather than blinks, and under the pointer it
        // stops and squares off into a stop button.
        Component {
            id: recorderMark

            Rectangle {
                width: segment.hovered ? 9 : 8
                height: width
                radius: segment.hovered ? 2 : width / 2
                color: Theme.indicatorBad

                Behavior on radius { NumberAnimation { duration: Theme.durationFast } }

                SequentialAnimation on opacity {
                    running: !segment.hovered
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) parent.opacity = 1
                    NumberAnimation { to: 0.4; duration: 900; easing.type: Theme.easing }
                    NumberAnimation { to: 1;   duration: 900; easing.type: Theme.easing }
                }
            }
        }

        Component {
            id: recorderFigure

            Text {
                text: RecorderService.display
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }

        // ── COUNTDOWN ───────────────────────────────────────────────────────
        Component {
            id: timerMark

            RingIndicator {
                width: 16
                height: 16
                thickness: 2
                progress: TimerService.progress
                trackColor: Theme.indicatorDim
                fillColor: TimerService.tint
            }
        }

        Component {
            id: timerFigure

            Text {
                text: TimerService.display
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: TimerService.paused ? Theme.textMuted : Theme.text
            }
        }

        // ── TRACK ───────────────────────────────────────────────────────────
        //
        // The artwork, and the real spectrum: bars animated on a timer keep
        // moving through silence.
        Component {
            id: mediaMark

            ClippingRectangle {
                width: 20
                height: 20
                radius: width * Theme.pictureCorner
                color: Theme.islandSurfaceHover

                Component.onCompleted: MediaService.subscribe()
                Component.onDestruction: MediaService.release()

                Image {
                    id: art
                    anchors.fill: parent
                    source: MediaService.artUrl
                    visible: source != "" && status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 40
                    sourceSize.height: 40
                }

                Text {
                    anchors.centerIn: parent
                    visible: !art.visible
                    text: "󰎇"
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    color: Theme.indicator
                }
            }
        }

        Component {
            id: mediaFigure

            Spectrum {
                height: 14
                barWidth: 2
                minimum: 2
                active: MediaService.playing
                barColor: Theme.indicator

                Component.onCompleted: CavaService.subscribe()
                Component.onDestruction: CavaService.release()
            }
        }
    }
}
