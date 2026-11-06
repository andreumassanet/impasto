// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W O R K S P A C E   S T R I P                                          │
// │   the strip in the chosen style · pills, or a widget with extras         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"

// The one place that knows which strip a style is, so the bar, the settings'
// tiles and the layout editor draw the same thing. Pills are their own strip;
// every other style is `WorkspacesWidget`, followed by the apps and the
// special pill when `SettingsService.workspaceExtras` is on.
Item {
    id: root

    property bool chromeless: false
    property bool overWallpaper: false
    // A still strip with nothing to click, for the settings.
    property bool preview: false
    // `SettingsService.workspaceStyle` unless a picker draws another.
    property string style: SettingsService.workspaceStyle

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: Theme.capsuleHeight

    Loader {
        id: loader

        anchors.fill: parent
        sourceComponent: root.style === "pills" ? pills : widget
    }

    Component {
        id: pills

        WorkspacePills {
            chromeless: root.chromeless
            overWallpaper: root.overWallpaper
            preview: root.preview
        }
    }

    Component {
        id: widget

        Row {
            spacing: root.chromeless ? 8 : Theme.capsuleSpacing

            WorkspacesWidget {
                chromeless: root.chromeless
                overWallpaper: root.overWallpaper
                style: root.style
                preview: root.preview
            }

            Loader {
                active: SettingsService.workspaceExtras && !root.preview
                visible: item !== null && item.shown

                sourceComponent: WorkspaceExtras {
                    chromeless: root.chromeless
                }
            }
        }
    }
}
