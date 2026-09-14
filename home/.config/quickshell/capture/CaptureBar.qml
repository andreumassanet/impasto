// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A P T U R E   B A R                                                  │
// │   capture options · region, kind and action                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"
import "../components"

// Capture options: the shape, the kind, and where the result goes (or, for a
// recording, whether it includes audio). Drawn in the island's black at the
// bottom of the screen, as glyphs, each named on hover.
Rectangle {
    id: root

    // Each group sits flat on the bar, its segments square.
    readonly property int groupHeight: 40
    readonly property int glyphSize: 20
    readonly property int tipGap: (root.height - root.groupHeight) / 2 + 8

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 52
    radius: height / 2
    color: Theme.island
    border.color: Theme.islandBorder
    border.width: 1

    // The bar takes its own presses; without this, a click on a segment starts
    // a selection underneath it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => mouse.accepted = true
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 8

        SegmentedControl {
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: root.groupHeight
            color: "transparent"
            border.width: 0
            tipGap: root.tipGap
            iconSize: root.glyphSize
            options: [
                { id: "region", label: "Region", icon: "󰩭" },
                { id: "window", label: "Window", icon: "󰣆" },
                { id: "screen", label: "Screen", icon: "󰍹" }
            ]
            current: CaptureService.shape
            onSelected: id => CaptureService.setShape(id)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 22
            color: Theme.islandBorder
        }

        SegmentedControl {
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: root.groupHeight
            color: "transparent"
            border.width: 0
            tipGap: root.tipGap
            iconSize: root.glyphSize
            options: [
                { id: "photo", label: "Photo", icon: "󰄀" },
                { id: "video", label: "Video", icon: "󰕧" }
            ]
            current: CaptureService.kind
            onSelected: id => CaptureService.setKind(id)
        }

        // Third group: where a screenshot goes, or whether a recording captures
        // audio. One slot for both, so the bar keeps its shape.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: CaptureService.kind === "photo" || RecorderService.canAudio
            width: 1
            height: 22
            color: Theme.islandBorder
        }

        SegmentedControl {
            anchors.verticalCenter: parent.verticalCenter
            visible: CaptureService.kind === "photo"
            implicitHeight: root.groupHeight
            color: "transparent"
            border.width: 0
            tipGap: root.tipGap
            iconSize: root.glyphSize
            // Destinations whose tool is missing are hidden rather than
            // disabled.
            options: [
                { id: "file", label: "Save", icon: "󰆓" },
                { id: "clipboard", label: "Copy", icon: "󰆏" }
            ].concat(CaptureService.offers("editor")
                    ? [{ id: "editor", label: "Annotate", icon: "󰏫" }] : [])
             .concat(CaptureService.offers("text")
                    ? [{ id: "text", label: "Read text", icon: "󱄽" }] : [])
            current: CaptureService.to
            onSelected: id => CaptureService.to = id
        }

        // System audio (the monitor source), not the microphone. Hidden when
        // there is no monitor source.
        SegmentedControl {
            anchors.verticalCenter: parent.verticalCenter
            visible: CaptureService.kind === "video" && RecorderService.canAudio
            implicitHeight: root.groupHeight
            color: "transparent"
            border.width: 0
            tipGap: root.tipGap
            iconSize: root.glyphSize
            options: [
                { id: "mute", label: "No sound", icon: "󰖁" },
                { id: "sound", label: "Sound", icon: "󰕾" }
            ]
            current: SettingsService.recorderAudio ? "sound" : "mute"
            onSelected: id => SettingsService.set("recorderAudio", id === "sound")
        }
    }
}
