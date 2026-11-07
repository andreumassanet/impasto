// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P A N E L   T A B S                                                    │
// │   one tab strip for the island panels · pills of equal width             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Layouts

import "../theme"

// The tab strip for the island panels: pills of equal width, the current one
// in the accent, each with an optional glyph. It only reports a click; the
// panel owns the current index and may bind Tab and Shift+Tab to `step`.
RowLayout {
    id: root

    // Entries of { label, glyph? }, or plain strings.
    property var tabs: []
    // Index of the selected tab.
    property int current: 0
    // Pills share the width, or each takes its text's.
    property bool even: true

    // Index of the tab that was clicked, or that `step` moved to.
    signal picked(int index)

    // Asks for the tab `by` places from the current one, wrapping around.
    function step(by: int): void {
        if (root.tabs.length > 0)
            root.picked((root.current + by + root.tabs.length) % root.tabs.length)
    }

    Layout.fillWidth: root.even
    Layout.preferredHeight: 34
    Layout.maximumHeight: 34
    Layout.fillHeight: false
    spacing: 6

    Repeater {
        model: root.tabs

        Rectangle {
            id: tab

            required property var modelData
            required property int index
            readonly property bool chosen: root.current === tab.index
            readonly property string label: typeof tab.modelData === "string" ? tab.modelData : tab.modelData.label
            readonly property string glyph: typeof tab.modelData === "string" ? "" : (tab.modelData.glyph ?? "")

            Layout.fillWidth: root.even
            Layout.fillHeight: true
            Layout.preferredWidth: root.even ? 1 : row.implicitWidth + 28
            radius: height / 2
            color: tab.chosen ? Theme.accent
                : mouse.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : Theme.surfaceIn(QsWindow.window)

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            Row {
                id: row

                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: tab.glyph !== ""
                    text: tab.glyph
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeRegular
                    color: tab.chosen ? Theme.accentText : Theme.textMuted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: tab.chosen ? Font.DemiBold : Font.Normal
                    color: tab.chosen ? Theme.accentText : Theme.text
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(tab.index)
            }
        }
    }
}
