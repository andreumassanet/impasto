// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W O R K S P A C E   S T Y L E S                                        │
// │   the workspace strip's styles, each drawn as it would be on the bar     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"
import "../bar/widgets"

// Two rows: the shapes and the pills, then the number written out. Each tile
// is the real strip in preview, so it follows the palette and the bar's height.
ColumnLayout {
    id: root

    spacing: 8

    Repeater {
        model: [SettingsService.workspaceStyles.slice(0, 4),
                SettingsService.workspaceStyles.slice(4)]

        RowLayout {
            required property var modelData

            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: parent.modelData

                PreviewTile {
                    id: tile

                    required property var modelData

                    stageHeight: Theme.capsuleHeight + 14
                    caption: Tr.t(modelData.label)
                    selected: SettingsService.workspaceStyle === modelData.id
                    onPicked: SettingsService.set("workspaceStyle", modelData.id)

                    WorkspaceStrip {
                        anchors.centerIn: parent
                        style: tile.modelData.id
                        preview: true
                    }
                }
            }
        }
    }
}
