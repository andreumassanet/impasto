// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L A U N C H E R   D R A W E R                                          │
// │   frame · the launcher growing from the bottom edge                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"
import "../services"
import "../bar/island"

// The launcher as a drawer: the same `LauncherPanel` the island hosts (search,
// sigils, clipboard, emoji) or the application grid, depending on
// `SettingsService.launcherDesign`. Opened by the launcher key, and optionally
// by resting on the bottom edge (`launcherOnHover`) or from a search pill that
// stays out (`launcherPinned`).
EdgeDrawer {
    id: root

    // Whether this is the screen the launcher belongs to (`shell.qml`).
    property bool live: false
    readonly property bool apps: DrawerService.launcherMode === "apps"
    readonly property bool opened: DrawerService.launcherOpen && root.live

    signal panelRequested(string panel)
    signal settingsRequested()

    edge: "bottom"
    // A pinned search bar stays out while the launcher is closed, as a pill
    // that opens it. It is on every screen, so the room it keeps from the
    // windows never moves with the live one.
    readonly property bool pinnedBar: SettingsService.launcherPinned && !root.opened
    readonly property int pinnedDepth: 56
    shown: root.opened || root.pinnedBar
    framed: root.opened
    grabsKeyboard: root.opened
    reserve: SettingsService.launcherPinned ? root.pinnedDepth : 0

    along: root.pinnedBar ? 520
        : root.apps ? Math.min(1180, root.width - 160)
        : LauncherService.panelWidth + 2 * Theme.panelPadding
    depth: root.pinnedBar ? root.pinnedDepth
        : root.apps ? Math.min(640, root.height * 0.62) : LauncherService.panelHeight + 2 * Theme.panelPadding

    Behavior on depth {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    onDismissed: DrawerService.closeLauncher()

    // With `launcherOnHover`, resting on the bottom edge opens the launcher;
    // leaving it again without typing anything closes it.
    reach: SettingsService.launcherOnHover && root.live ? 3 : 0
    property bool openedByHover: false

    onEdgeHoveredChanged: {
        if (root.edgeHovered && !DrawerService.launcherOpen)
            dwell.restart()
        // The strip lies under the frame, outside the body: a pointer that
        // opened the launcher from it and goes sideways never leaves the body.
        else if (!root.edgeHovered && root.openedByHover && !root.hovered)
            leave.restart()
    }

    Timer {
        id: dwell

        interval: 180
        onTriggered: {
            if (root.edgeHovered && !DrawerService.launcherOpen) {
                root.openedByHover = true
                DrawerService.openLauncher(DrawerService.designMode, root.screen.name)
            }
        }
    }

    onHoveredChanged: {
        if (!root.hovered && root.openedByHover)
            leave.restart()
        else
            leave.stop()
    }

    Timer {
        id: leave

        interval: 700
        onTriggered: {
            if (!root.hovered && !root.edgeHovered && LauncherService.query === "")
                DrawerService.closeLauncher()
        }
    }

    Connections {
        target: DrawerService

        function onLauncherOpenChanged(): void {
            if (!DrawerService.launcherOpen)
                root.openedByHover = false
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: DrawerService.closeLauncher()

        Loader {
            anchors.fill: parent
            anchors.margins: root.apps ? 0 : Theme.panelPadding
            active: root.opened
            focus: true
            sourceComponent: root.apps ? appGrid : search
        }

        // The pinned bar: a search pill; a click opens the launcher.
        Rectangle {
            visible: root.pinnedBar
            anchors.centerIn: parent
            width: parent.width - 24
            height: 38
            radius: height / 2
            color: pinnedMouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 16
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.textMuted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SettingsService.launcherDesign === "grid"
                        ? Tr.t("Search applications") : Tr.t("Search apps, files and commands")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }

            MouseArea {
                id: pinnedMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onClicked: DrawerService.openLauncher(DrawerService.designMode, root.screen.name)
            }
        }
    }

    Component {
        id: search

        LauncherPanel {
            onClosed: DrawerService.closeLauncher()
            onPanelRequested: panel => {
                DrawerService.closeLauncher()
                root.panelRequested(panel)
            }
            onSettingsRequested: {
                DrawerService.closeLauncher()
                root.settingsRequested()
            }
        }
    }

    Component {
        id: appGrid

        AppGrid {
            onClosed: DrawerService.closeLauncher()
        }
    }
}
