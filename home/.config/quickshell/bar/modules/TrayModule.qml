// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R A Y   M O D U L E                                                  │
// │   system tray · status notifier icons with menus                         │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland

import "../../theme"
import "../../components"

Item {
    id: root

    property bool present: false
    property var hostScreen: null

    // Which item's menu is open; null while closed.
    property var menuItem: null
    property Item menuAnchor: null

    implicitWidth: trayRow.implicitWidth
    implicitHeight: Theme.capsuleHeight

    Row {
        id: trayRow
        spacing: 4

        Repeater {
            id: tiles
            model: SystemTray.items

            delegate: Item {
                id: trayItem
                required property var modelData

                width: icon.width + 8
                height: Theme.capsuleHeight

                Image {
                    id: icon
                    anchors.centerIn: parent
                    width: Math.round(Theme.capsuleHeight * 0.56)
                    height: width
                    source: modelData.icon
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                    smooth: true
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 4
                    height: Theme.capsuleHeight - 8
                    radius: height / 2
                    color: Theme.islandSurfaceHover
                    opacity: trayMouse.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: (event) => {
                        switch (event.button) {
                            case Qt.LeftButton:
                                if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu)
                                    root.openMenu(trayItem.modelData, trayItem)
                                else
                                    trayItem.modelData.activate()
                                break
                            case Qt.RightButton:
                                if (trayItem.modelData.hasMenu)
                                    root.openMenu(trayItem.modelData, trayItem)
                                break
                            case Qt.MiddleButton:
                                trayItem.modelData.secondaryActivate()
                                break
                        }
                    }

                    onWheel: (event) => {
                        const dir = event.angleDelta.y > 0 ? 1 : -1
                        trayItem.modelData.scroll(dir, false)
                    }
                }
            }

            onCountChanged: root.present = tiles.count > 0
        }
    }

    function openMenu(handle, item) {
        root.menuItem = handle
        root.menuAnchor = item
    }

    function closeMenu() {
        root.menuItem = null
        root.menuAnchor = null
    }

    // A menu is a clear full-screen surface on top of everything, so a click
    // anywhere else closes it (`TapHandler` below). The window lives in a
    // LazyLoader and is created and destroyed with the menu, which unmaps its
    // layer-shell surface; destroying a window created with `createObject`
    // does not, and leaves an invisible click-blocking surface behind.
    LazyLoader {
        active: root.menuItem !== null

        PanelWindow {
            id: menuWindow

            screen: root.hostScreen
            anchors { top: true; left: true; right: true; bottom: true }
            WlrLayershell.namespace: "impasto-tray-menu"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"

            mask: Region {
                width: menuWindow.width
                height: menuWindow.height
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: root.closeMenu()
            }

            readonly property point anchor: {
                if (!root.menuAnchor) return Qt.point(0, 0)
                const p = root.menuAnchor.mapToItem(null, 0, 0)
                return Qt.point(p.x, p.y + Theme.capsuleHeight + 4)
            }

            TrayMenuLevel {
                id: level
                scope: root.menuItem.menu
                position: menuWindow.anchor
                window: menuWindow
                onClosed: root.closeMenu()
            }
        }
    }
}