// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E G M E N T E D   C O N T R O L                                      │
// │   pick one of a few, with all of them visible                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Layouts

import "../theme"

// For two or three options, all visible at once.
Rectangle {
    id: root

    // Entries of { id, label }, or { id, label, icon }: an entry with an icon
    // shows only the glyph, and its label appears above the control on hover,
    // unless `labelled` writes the label beside the glyph.
    property var options: []
    property string current: ""
    property int iconSize: Theme.fontSizeLarge
    property bool labelled: false
    // Segments share the control's width equally, for a control that spans
    // its card.
    property bool stretch: false
    // Distance from the control's top edge to the hovered label.
    property int tipGap: 6

    signal selected(string id)

    // The segment under the pointer.
    property Item hovered: null

    implicitWidth: layout.implicitWidth + 6
    implicitHeight: Theme.segmentHeight
    radius: Theme.radiusSmall
    opacity: root.enabled ? 1 : 0.45

    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    color: Theme.surfaceHoverIn(QsWindow.window)
    border.color: Theme.borderIn(QsWindow.window)
    border.width: 1

    RowLayout {
        id: layout
        anchors.centerIn: parent
        width: root.stretch ? root.width - 6 : implicitWidth
        spacing: 2

        Repeater {
            model: root.options

            Rectangle {
                id: segment

                required property var modelData
                readonly property bool active: segment.modelData.id === root.current
                readonly property bool glyph: (segment.modelData.icon ?? "") !== ""
                // A glyph on its own: the label is shown on hover instead.
                readonly property bool iconOnly: segment.glyph && !root.labelled

                Layout.preferredHeight: root.implicitHeight - 6
                Layout.fillWidth: root.stretch
                Layout.preferredWidth: segment.iconOnly
                    ? Layout.preferredHeight
                    : Math.max(64, content.implicitWidth + 20)
                radius: Theme.radiusSmall - 2
                color: segment.active ? Theme.accent
                    : (segmentMouse.containsMouse ? Theme.borderIn(QsWindow.window) : Qt.alpha(Theme.borderIn(QsWindow.window), 0))

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Row {
                    id: content

                    readonly property color ink: segment.active ? Theme.accentText
                        : (segment.glyph && segmentMouse.containsMouse ? Theme.text
                                                                        : Theme.textMuted)

                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: segment.glyph
                        text: segment.modelData.icon ?? ""
                        font.family: Theme.fontMono
                        font.pixelSize: root.iconSize
                        font.weight: segment.active ? Font.DemiBold : Font.Normal
                        color: content.ink
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !segment.iconOnly
                        text: segment.modelData.label ?? ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: segment.active ? Font.DemiBold : Font.Normal
                        color: content.ink
                    }
                }

                MouseArea {
                    id: segmentMouse
                    anchors.fill: parent
                    enabled: root.enabled
                    hoverEnabled: true
                    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.selected(segment.modelData.id)
                    onContainsMouseChanged: {
                        if (containsMouse)
                            root.hovered = segment
                        else if (root.hovered === segment)
                            root.hovered = null
                    }
                }
            }
        }
    }

    // ── LABEL ───────────────────────────────────────────────────────────────
    //
    // The hovered glyph's name, centred over it. It keeps the last segment
    // through the fade-out, so the name does not blank before it is gone.

    Rectangle {
        id: tip

        property Item target: null

        Binding on target {
            when: root.hovered !== null && root.hovered.iconOnly
            value: root.hovered
            restoreMode: Binding.RestoreNone
        }

        visible: opacity > 0
        opacity: root.hovered !== null && root.hovered.iconOnly ? 1 : 0
        x: tip.target === null ? 0
            : layout.x + tip.target.x + (tip.target.width - tip.width) / 2
        y: -tip.height - root.tipGap
        width: tipText.implicitWidth + 20
        height: 26
        radius: height / 2
        color: Theme.island
        border.color: Theme.borderIn(QsWindow.window)
        border.width: 1

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        Behavior on x {
            enabled: tip.opacity > 0
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: tip.target === null ? "" : tip.target.modelData.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.text
        }
    }
}
