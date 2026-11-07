// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A R D   L E V E L                                                    │
// │   one level on a card · its name, a line to drag, its value              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Controls
import QtQuick.Layouts

import "../theme"

// A level that can be set — a volume, a brightness — drawn as a limit is
// (`CardLimit`), with a knob: the two read as one family on a card. The name
// is a glyph or an application's picture and a word; a click on it is
// `markClicked`, which mutes.
RowLayout {
    id: root

    property string glyph: ""
    property string picture: ""
    property string name: ""
    property int value: 0
    property bool dimmed: false
    property bool available: true

    signal moved(int value)
    signal markClicked()

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.cardRow
    spacing: 10

    Item {
        Layout.preferredWidth: Theme.cardLabel
        Layout.fillHeight: true
        opacity: root.dimmed ? 0.5 : 1

        Row {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 7

            Image {
                id: picture

                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: root.picture !== "" && status === Image.Ready
                source: root.picture
                sourceSize.width: 32
                sourceSize.height: 32
                asynchronous: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !picture.visible && root.glyph !== ""
                text: root.glyph
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeRegular
                color: Theme.text
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                text: root.name
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.text
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.markClicked()
        }
    }

    Slider {
        id: slider

        Layout.fillWidth: true
        Layout.fillHeight: true
        enabled: root.available
        from: 0
        to: 100
        stepSize: 1
        value: root.value
        onMoved: root.moved(Math.round(slider.value))

        background: Item {
            Rectangle {
                y: (slider.height - height) / 2
                width: slider.width
                height: 6
                radius: 3
                color: Theme.surfaceHoverIn(QsWindow.window)

                Rectangle {
                    width: slider.handle.x + slider.handle.width / 2
                    height: parent.height
                    radius: parent.radius
                    color: root.dimmed ? Theme.textMuted : Theme.accent
                }
            }
        }

        handle: Rectangle {
            x: slider.visualPosition * (slider.width - width)
            y: (slider.height - height) / 2
            width: 12
            height: 12
            radius: 6
            color: Theme.text
            scale: slider.pressed || slider.hovered ? 1.15 : 1

            Behavior on scale { NumberAnimation { duration: Theme.durationFast } }
        }

        WheelHandler {
            onWheel: event => root.moved(Math.max(0, Math.min(100,
                root.value + (event.angleDelta.y > 0 ? 5 : -5))))
        }
    }

    Text {
        Layout.preferredWidth: 36
        horizontalAlignment: Text.AlignRight
        text: root.dimmed ? Tr.t("off") : `${root.value}%`
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
        color: root.dimmed ? Theme.textMuted : Theme.text
    }
}
