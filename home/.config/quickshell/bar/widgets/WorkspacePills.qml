// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W O R K S P A C E   P I L L S                                          │
// │   the workspace strip as pills · numbers, and the apps inside            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// Ten slots. The focused one is a pill in the accent with its number and its
// apps' icons; an occupied one shows its number (or, with one icon per
// workspace, that icon); an empty one is a dot. A special workspace open on
// this screen gets its own pill after them (SpecialPill).
//
// Which ten: per screen, the screen's own; shared, the ten the focused
// workspace is in. Click goes to a workspace, the wheel steps through them.
Rectangle {
    id: root

    // Inside the one capsule it drops its own capsule and padding.
    property bool chromeless: false
    property bool overWallpaper: false
    readonly property color dim: root.overWallpaper ? Theme.barInkDim : Theme.indicatorDim
    // A still strip for the settings: five slots, the second focused, the
    // first and third occupied, no window queries and nothing to click.
    property bool preview: false

    // "" when drawn outside a bar (the settings, the layout editor).
    readonly property string screenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property int activeId: root.preview ? 2
        : HyprlandService.activeOn(root.screenName) || HyprlandService.activeId
    // The workspace before the first slot.
    readonly property int groupBase: HyprlandService.perScreen
        ? HyprlandService.baseOn(root.screenName)
        : Math.floor((Math.max(1, root.activeId) - 1) / 10) * 10

    readonly property int slotHeight: Math.min(26, Theme.capsuleHeight - 8)
    readonly property int iconSize: root.slotHeight - 8

    // Slots past the number of workspaces available are not drawn.
    function isShown(index: int): bool {
        if (root.preview)
            return true
        return HyprlandService.perScreen ? index + 1 <= HyprlandService.maximum
                                         : root.groupBase + index + 1 <= HyprlandService.maximum
    }

    // The workspaces the wheel may reach: the screen's own ten, or all of them.
    readonly property int firstReachable: HyprlandService.perScreen ? root.groupBase + 1 : 1
    readonly property int lastReachable: HyprlandService.perScreen
        ? root.groupBase + HyprlandService.maximum : HyprlandService.maximum

    implicitHeight: Theme.capsuleHeight
    implicitWidth: row.implicitWidth + (root.chromeless ? 0 : 12)
    radius: Theme.radiusPill
    color: root.chromeless ? "transparent" : Theme.islandGround
    border.color: Theme.islandRim
    border.width: root.chromeless ? 0 : 1

    Component.onCompleted: {
        if (!root.preview)
            WindowService.subscribe()
    }
    Component.onDestruction: {
        if (!root.preview)
            WindowService.release()
    }

    GlassSheen {
        shape: root
        visible: Theme.glass && !root.chromeless
    }

    WheelHandler {
        enabled: !root.preview
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const next = root.activeId + (event.angleDelta.y < 0 ? 1 : -1)
            if (next >= root.firstReachable && next <= root.lastReachable)
                HyprlandService.focus(next)
        }
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        // No gaps: a click between two slots would reach the band behind and
        // open the control centre.
        spacing: 0

        Repeater {
            model: root.preview ? 5 : 10

            Rectangle {
                id: slot

                required property int index
                readonly property int workspaceId: root.preview ? slot.index + 1
                    : root.groupBase + slot.index + 1
                readonly property bool shown: root.isShown(slot.index)
                readonly property bool focused: root.activeId === slot.workspaceId
                readonly property bool occupied: root.preview
                    ? (slot.workspaceId === 1 || slot.workspaceId === 3)
                    : HyprlandService.isOccupied(slot.workspaceId)
                readonly property bool single: SettingsService.workspaceIcons === "single"
                readonly property var classes: !root.preview && (slot.focused || (slot.single && slot.occupied))
                    ? WindowService.iconClassesOn(slot.workspaceId) : []
                // With one icon per workspace, the icon stands for an
                // occupied one's number.
                readonly property bool numbered: slot.focused
                    || (slot.occupied && !(slot.single && slot.classes.length > 0))
                readonly property bool marked: slot.numbered || slot.classes.length > 0

                visible: slot.shown
                Layout.preferredHeight: root.slotHeight
                Layout.preferredWidth: slot.marked
                    ? Math.max(root.slotHeight, content.implicitWidth + (slot.focused ? 14 : 12))
                    : root.slotHeight - 4
                Layout.alignment: Qt.AlignVCenter
                radius: height / 2
                color: slot.focused ? Theme.accent
                    : mouse.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : "transparent"

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                }
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Row {
                    id: content

                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: slot.numbered
                        text: String(root.preview ? slot.workspaceId
                            : HyprlandService.numberOn(slot.workspaceId, root.screenName))
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeRegular
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: slot.focused ? Theme.accentText
                            : slot.occupied ? Theme.text : root.dim
                    }

                    Repeater {
                        model: slot.classes

                        IconImage {
                            required property string modelData

                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: root.iconSize
                            source: WindowService.iconFor(modelData)
                        }
                    }
                }

                // An empty workspace at rest: a dot.
                Rectangle {
                    anchors.centerIn: parent
                    visible: !slot.marked
                    width: 5
                    height: 5
                    radius: 2.5
                    color: root.dim
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: HyprlandService.focus(slot.workspaceId)
                }
            }
        }

        // Hides itself unless a special workspace is open on this screen.
        SpecialPill {
            Layout.leftMargin: 4
            Layout.alignment: Qt.AlignVCenter
            screenName: root.screenName
            slotHeight: root.slotHeight
        }
    }
}
