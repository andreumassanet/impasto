// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W O R K S P A C E S   W I D G E T                                      │
// │   dots that stretch into a pill for the one you are on                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import Quickshell

import "../../theme"
import "../../services"

// Three states, by shape and weight alone:
//
//     focused    a wide pill
//     occupied   a dot, solid but dim
//     empty      a dot, dimmer still
//
// The first few dots are always shown; the rest appear with use. The pill
// slides and stretches between positions rather than switching. Drawn in the
// accent: unlike the battery it carries no warning, so it follows the palette.
Rectangle {
    id: root

    // Inside the one capsule it drops its own capsule and padding.
    property bool chromeless: false

    // The strip is about the screen it is drawn on: the ten are shared, and
    // this says which of them this screen is showing. Off a screen of its own
    // it falls back to the focused one.
    readonly property string screenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property int activeId: HyprlandService.activeOn(root.screenName)
        || HyprlandService.activeId

    readonly property int dotSize: 6
    readonly property int activeWidth: 22
    readonly property int slotSpacing: 8

    implicitHeight: Theme.capsuleHeight
    // Each slot carries its own gap, so a collapsed one takes no space; the
    // spare gap is subtracted here.
    implicitWidth: layout.implicitWidth - root.slotSpacing
        + (root.chromeless ? 0 : 20)
    radius: Theme.radiusPill

    color: root.chromeless ? "transparent" : Theme.island
    border.color: Theme.islandBorder
    border.width: root.chromeless ? 0 : 1

    RowLayout {
        id: layout
        anchors.centerIn: parent
        // Row spacing would still surround a collapsed slot.
        spacing: 0

        // A slot per workspace, shown or not, so arrivals and departures both
        // animate. A Repeater over only the visible ones would destroy items
        // and make the rest jump.
        Repeater {
            model: HyprlandService.maximum

            Item {
                id: slot

                required property int index
                readonly property int workspaceId: slot.index + 1
                readonly property bool shown: HyprlandService.isVisible(slot.workspaceId)
                readonly property bool focused: root.activeId === slot.workspaceId
                readonly property bool occupied: HyprlandService.isOccupied(slot.workspaceId)

                Layout.preferredWidth: slot.shown
                    ? (slot.focused ? root.activeWidth : root.dotSize) + root.slotSpacing
                    : 0
                Layout.preferredHeight: Theme.capsuleHeight
                Layout.alignment: Qt.AlignVCenter

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - root.slotSpacing)
                    height: root.dotSize
                    radius: height / 2

                    color: {
                        if (slot.focused || mouse.containsMouse)
                            return Theme.accent
                        return slot.occupied ? Theme.accent : Theme.indicatorDim
                    }
                    // Dimming separates occupied from focused without a third
                    // shape.
                    opacity: slot.focused ? 1 : (slot.occupied ? 0.55 : 1)

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                }

                // Fills the slot, gap included; a 6 px target is too small.
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: HyprlandService.focus(slot.workspaceId)
                }
            }
        }
    }
}
