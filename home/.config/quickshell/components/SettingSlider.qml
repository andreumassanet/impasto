// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G   S L I D E R                                            │
// │   a number you drag, with the number on it                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../theme"

// A setting row with a continuous value (a height, a radius, a blur): the
// name on the left, the track and its figure on the same line at the right.
//
// Clicking the figure turns it into a field for an exact number: Enter
// commits, Escape cancels, arrows step. The mouse wheel steps too, over the
// track only, so scrolling the page never changes a value.
//
// The track is drawn here; the Controls slider on top is invisible and only
// supplies the drag behaviour.
Item {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property int decimals: 0
    property string unit: ""

    // Overridable, e.g. a blur of zero reads "Off".
    property string reading:
        `${root.value.toFixed(root.decimals)}${root.unit}`

    // Same meaning as in `SettingRow`.
    property bool locked: false
    property string reason: ""

    signal moved(real value)

    Layout.fillWidth: true
    implicitHeight: Math.max(48, body.implicitHeight + 16)
    opacity: root.locked ? 0.55 : 1

    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

    SettingDivider {}

    RowLayout {
        id: body

        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12

        SettingLabel {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            label: root.label
            locked: root.locked
            reason: root.reason
        }

        Item {
            Layout.preferredWidth: 240
            Layout.preferredHeight: 16
            Layout.alignment: Qt.AlignVCenter
            enabled: !root.locked

            Rectangle {
                id: track

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Theme.islandSurfaceHover

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * slider.position
                    radius: parent.radius
                    color: Theme.accent
                }
            }

            Rectangle {
                x: track.width * slider.position - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: slider.pressed || slider.hovered ? 16 : 13
                height: width
                radius: width / 2
                color: Theme.accentText
                border.color: Theme.accent
                border.width: 3

                Behavior on width {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }
            }

            Slider {
                id: slider

                anchors.fill: parent
                from: root.from
                to: root.to
                stepSize: root.stepSize
                opacity: 0
                onMoved: root.moved(slider.value)
            }

            // One step per notch, mouse only: a touchpad fling would jump
            // many steps.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse
                onWheel: event => {
                    const direction = event.angleDelta.y > 0 ? 1 : -1
                    root.moved(Math.min(root.to, Math.max(root.from,
                        root.value + direction * root.stepSize)))
                }
            }

            // Dragging breaks a plain binding on `slider.value`; this keeps
            // the track following external changes such as a reset.
            Binding {
                target: slider
                property: "value"
                value: root.value
                when: !slider.pressed
                restoreMode: Binding.RestoreBindingOrValue
            }
        }

        Item {
            id: readingSlot

            property bool editing: false

            Layout.preferredWidth: readingSlot.editing
                ? 68 : Math.max(48, readout.implicitWidth)
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            enabled: !root.locked

            // Clamped and snapped to the slider's steps.
            function commit(entered: string): void {
                const parsed = parseFloat(entered.replace(",", "."))
                if (isNaN(parsed))
                    return
                let wanted = Math.min(root.to, Math.max(root.from, parsed))
                if (root.stepSize > 0)
                    wanted = root.from + Math.round(
                        (wanted - root.from) / root.stepSize) * root.stepSize
                wanted = Math.min(root.to, Math.max(root.from, wanted))
                root.moved(wanted)
            }

            function nudge(direction: int): void {
                const wanted = Math.min(root.to, Math.max(root.from,
                    root.value + direction * root.stepSize))
                root.moved(wanted)
                editor.text = wanted.toFixed(root.decimals)
            }

            Text {
                id: readout

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !readingSlot.editing
                text: root.reading
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: readingMouse.containsMouse ? Theme.text : Theme.textMuted

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            MouseArea {
                id: readingMouse

                anchors.fill: parent
                visible: !readingSlot.editing
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    readingSlot.editing = true
                    editor.text = root.value.toFixed(root.decimals)
                    editor.forceActiveFocus()
                    editor.selectAll()
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: readingSlot.editing
                radius: Theme.radiusSmall - 2
                color: Theme.island
                border.color: Theme.accent
                border.width: 1

                TextInput {
                    id: editor

                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                    selectByMouse: true
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    clip: true
                    validator: RegularExpressionValidator {
                        regularExpression: /-?[0-9]*[.,]?[0-9]*/
                    }

                    Keys.onEscapePressed: readingSlot.editing = false
                    Keys.onUpPressed: readingSlot.nudge(1)
                    Keys.onDownPressed: readingSlot.nudge(-1)

                    // Enter or focus loss. Escape has already cleared
                    // `editing`, so it does not commit.
                    onEditingFinished: {
                        if (!readingSlot.editing)
                            return
                        readingSlot.editing = false
                        readingSlot.commit(editor.text)
                    }
                }
            }
        }
    }
}
