// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S P E C I A L   P I L L                                                │
// │   the special workspace open on a screen · one pill, the apps inside     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell.Hyprland
import Quickshell.Widgets

import "../../theme"
import "../../services"

// Special workspaces are one workspace here, named "special" whatever
// Hyprland calls the one that is open. While it is open on this screen the
// pill shows the apps inside it, as a numbered workspace does, and a click
// closes it.
Rectangle {
    id: root

    required property string screenName
    property int slotHeight: Math.min(26, Theme.capsuleHeight - 8)

    readonly property int iconSize: root.slotHeight - 8
    // `special:name`, or "" while none is open on this screen.
    readonly property string workspaceName: HyprlandService.specialOn(root.screenName)

    visible: root.workspaceName !== ""
    implicitHeight: root.slotHeight
    implicitWidth: root.visible ? content.implicitWidth + 16 : 0
    radius: height / 2
    color: Qt.alpha(Theme.accent, 0.22)
    border.color: Theme.accent
    border.width: 1

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "special"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Repeater {
            model: WindowService.specialIconClasses(root.screenName)

            IconImage {
                required property string modelData

                anchors.verticalCenter: parent.verticalCenter
                implicitSize: root.iconSize
                source: WindowService.iconFor(modelData)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch(
            `hl.dsp.workspace.toggle_special("${root.workspaceName.replace(/^special:/, "")}")`)
    }
}
