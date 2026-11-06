// End_4 ii's on-screen keyboard, in the island's look, along the
// bottom edge. Opened from the control centre's tile or `qs ipc call osk
// toggle`; pinned, it keeps its space from the windows. Keys go through
// ydotool, so it needs no keyboard focus.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../theme"
import "../services"
import "layouts.js" as Layouts

PanelWindow {
    id: root

    readonly property var layout: Layouts.byName[Layouts.defaultLayout]

    visible: SettingsService.osk && OskService.open && !LockService.locked
    anchors { bottom: true; left: true; right: true }
    implicitHeight: board.height + 2 * Theme.desktopGutter
    exclusiveZone: OskService.pinned ? board.height + Theme.desktopGutter : 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "impasto-osk"
    mask: Region { item: board }

    Rectangle {
        id: board

        anchors.centerIn: parent
        width: content.implicitWidth + 24
        height: content.implicitHeight + 24
        radius: Theme.radiusLarge
        color: Theme.islandGround
        border.color: Theme.islandRim

        RowLayout {
            id: content

            anchors.centerIn: parent
            spacing: 10

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 6

                Repeater {
                    model: [
                        { glyph: "󰐃", action: () => OskService.pinned = !OskService.pinned, lit: () => OskService.pinned },
                        { glyph: "󰌐", action: () => OskService.open = false, lit: () => false }
                    ]

                    Rectangle {
                        required property var modelData

                        implicitWidth: 40
                        implicitHeight: 40
                        radius: Theme.radiusMedium
                        color: modelData.lit() ? Theme.accent : Theme.islandSurface

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.glyph
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLarge
                            color: parent.modelData.lit() ? Theme.accentText : Theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.action()
                        }
                    }
                }
            }

            ColumnLayout {
                spacing: 5

                Repeater {
                    model: root.layout.keys

                    RowLayout {
                        required property var modelData

                        spacing: 5

                        Repeater {
                            model: parent.modelData

                            OskKey {
                                required property var modelData

                                keyData: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
