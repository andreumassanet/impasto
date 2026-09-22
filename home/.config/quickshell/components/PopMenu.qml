// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P O P   M E N U                                                        │
// │   context menu · opened at the click position                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"

// A small context menu with the dock menu's look (plate, row height, fixed
// width), so right-click menus on the wallpaper, widgets and dock match.
//
// Drawn inside the owning surface, not as a popup (see `DockMenu`). It never
// takes the keyboard: it closes on a click outside, a right click, or a
// choice.
//
//   rows   [{ id, label, icon, warn }] — `warn` reddens under the pointer,
//          for destructive actions
Item {
    id: root

    property var rows: []

    signal chosen(string id)

    implicitWidth: Theme.dockMenuWidth
    implicitHeight: column.implicitHeight + 2 * Theme.dockMenuPadding
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: Theme.dockMenuPadding
        spacing: 0

        Repeater {
            model: ScriptModel {
                values: root.rows
            }

            Rectangle {
                id: row

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: Theme.dockMenuRow
                radius: Theme.radiusSmall
                color: rowMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        Layout.preferredWidth: 16
                        horizontalAlignment: Text.AlignHCenter
                        text: row.modelData.icon ?? ""
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: row.modelData.warn && rowMouse.containsMouse
                            ? Theme.red : Theme.textMuted
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.label
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: row.modelData.warn && rowMouse.containsMouse
                            ? Theme.red : Theme.text
                    }
                }

                MouseArea {
                    id: rowMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chosen(row.modelData.id)
                }
            }
        }
    }
}
