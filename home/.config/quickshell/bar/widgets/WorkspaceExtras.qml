// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W O R K S P A C E   E X T R A S                                        │
// │   the apps of the focused workspace and the special pill, beside a strip │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// What the pills carry, for the other workspace styles (dots, bars, rings and
// the written numbers): the focused workspace's icons, by
// `SettingsService.workspaceIcons`, and the special workspace's pill. Gone
// when it has neither.
Rectangle {
    id: root

    property bool chromeless: false

    readonly property string screenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property int activeId: HyprlandService.activeOn(root.screenName) || HyprlandService.activeId
    readonly property var classes: WindowService.iconClassesOn(root.activeId)
    readonly property int iconSize: Math.min(26, Theme.capsuleHeight - 8) - 8

    // Not `special.visible`: that is false while this is hidden, so a special
    // workspace opening alone could never bring it back.
    readonly property bool shown: root.classes.length > 0
        || HyprlandService.specialOn(root.screenName) !== ""

    visible: root.shown
    implicitHeight: Theme.capsuleHeight
    implicitWidth: root.visible ? row.implicitWidth + (root.chromeless ? 0 : 16) : 0
    radius: Theme.radiusPill
    color: root.chromeless ? "transparent" : Theme.islandGround
    border.color: Theme.islandRim
    border.width: root.chromeless ? 0 : 1

    Component.onCompleted: WindowService.subscribe()
    Component.onDestruction: WindowService.release()

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: root.classes

            IconImage {
                required property string modelData

                anchors.verticalCenter: parent.verticalCenter
                implicitSize: root.iconSize
                source: WindowService.iconFor(modelData)
            }
        }

        SpecialPill {
            id: special

            anchors.verticalCenter: parent.verticalCenter
            screenName: root.screenName
        }
    }
}
