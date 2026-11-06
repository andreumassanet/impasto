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

// A special workspace is named after its scratchpad in the settings, or
// "special" when it has none. While it is open on this screen the
// pill shows the apps inside it, as a numbered workspace does, and a click
// closes it.
Rectangle {
    id: root

    required property string screenName
    property int slotHeight: Math.min(26, Theme.capsuleHeight - 8)

    readonly property int iconSize: root.slotHeight - 8
    // `special:name`, or "" while none is open on this screen.
    readonly property string workspaceName: HyprlandService.specialOn(root.screenName)

    // What the scratchpad is called in Settings → Scratchpads, else "special".
    readonly property string title: {
        const name = root.workspaceName.replace(/^special:/, "")
        const pad = Array.from(SettingsService.overviewScratchpads ?? [])
            .find(entry => entry.name === name)
        return pad ? (pad.label || pad.name) : Tr.t("special")
    }

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
            text: root.title
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
