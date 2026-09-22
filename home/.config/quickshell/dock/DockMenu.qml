// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D O C K   M E N U                                                      │
// │   one application's windows · and what can be done to it                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"
import "../services"

// Right-click menu for a dock icon: the application's windows by title, with
// the focused one marked and each one's workspace, then the application's own
// actions.
//
// ── LAYOUT ──────────────────────────────────────────────────────────────────
//
// Drawn inside the dock's surface, not a new one: same-layer surfaces stack in
// creation order, so one created on demand would cover the dock and take its
// clicks. While it is open the dock's input region is the whole screen, so a
// click outside closes it.
//
// No keyboard focus, so no Escape: right-click, click outside, or choose an
// item.
//
// Fixed width: fitting the content would make the rows' width and the plate's
// depend on each other, and window titles need eliding anyway.
Item {
    id: root

    required property var item

    signal closed()

    readonly property bool multiple: root.item.windows.length > 1

    // A window with no matching desktop entry: nothing to launch or pin, only
    // its windows.
    readonly property bool known: root.item.id !== ""

    // Application actions, below the windows.
    readonly property var actions: {
        const rows = []
        if (root.known) {
            rows.push({
                id: "launch",
                label: root.item.running ? Tr.t("New window") : Tr.t("Open"),
                warn: false
            })
            rows.push({
                id: "pin",
                label: root.item.pinned
                    ? Tr.t("Remove from the dock")
                    : Tr.t("Keep in the dock"),
                warn: false
            })
        }
        if (root.item.running) {
            rows.push({
                id: "close",
                label: root.multiple ? Tr.t("Close all windows") : Tr.t("Close"),
                warn: true
            })
        }
        return rows
    }

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

        // ── WINDOWS ─────────────────────────────────────────────────────────

        Repeater {
            model: ScriptModel {
                values: root.item.windows
                objectProp: "address"
            }

            Rectangle {
                id: window

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: Theme.dockMenuRow
                radius: Theme.radiusSmall
                color: windowMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Marks the focused window; hyprctl's order carries no
                    // meaning.
                    Rectangle {
                        Layout.preferredWidth: Theme.dockDot
                        Layout.preferredHeight: Theme.dockDot
                        Layout.alignment: Qt.AlignVCenter
                        radius: Theme.radiusPill
                        color: Theme.accent
                        opacity: window.modelData.front ? 1 : 0
                    }

                    Text {
                        Layout.fillWidth: true
                        text: window.modelData.title
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }

                    // The window's workspace, since choosing it also switches
                    // workspace.
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: `${window.modelData.workspace}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                MouseArea {
                    id: windowMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        HyprlandService.focusWindow(window.modelData.address)
                        root.closed()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 5
            Layout.bottomMargin: 5
            visible: root.item.running && root.actions.length > 0
            color: Theme.hairline
        }

        // ── APPLICATION ─────────────────────────────────────────────────────

        Repeater {
            model: root.actions

            Rectangle {
                id: action

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: Theme.dockMenuRow
                radius: Theme.radiusSmall
                color: actionMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    // Aligned with the window titles, not the dots.
                    anchors.leftMargin: 16 + Theme.dockDot
                    text: action.modelData.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    // Closing cannot be undone, so it turns red on hover
                    // instead of asking for confirmation.
                    color: action.modelData.warn && actionMouse.containsMouse
                        ? Theme.red : Theme.text
                }

                MouseArea {
                    id: actionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        switch (action.modelData.id) {
                        case "launch":
                            DockService.launch(root.item)
                            break
                        case "pin":
                            DockService.togglePin(root.item.id)
                            break
                        case "close":
                            DockService.closeAll(root.item)
                            break
                        }
                        root.closed()
                    }
                }
            }
        }
    }
}
