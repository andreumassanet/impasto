// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D O C K   D R A W E R                                                  │
// │   frame · the dock as a drawer on a screen edge                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"
import "../services"
import "../components"

// The dock as a drawer (`SettingsService.dockStyle` "drawer"): the same apps
// as the classic dock (`DockService.items`), on the edge the Dock page picks
// and hidden until the pointer reaches it, or until the bar's corner button
// is clicked (`edgeOpen`).
//   hover         the icon grows, its neighbours a little
//   click         the popout (DockPopout, a card beside the icon): a row per
//                 window with a live preview, its title and workspace, and
//                 focus, send to a workspace, float, pin, fullscreen, close;
//                 or a new window when the app has none
//   double-click  go to the app, or start it
//   right-click   the menu: new window, open on a workspace, pin or unpin,
//                 close every window
//   drag          a pinned icon dropped on another takes its place
// Mouse only: it never takes the keyboard.
EdgeDrawer {
    id: root

    // Whether this is the screen being worked on (`shell.qml`).
    property bool live: false
    // Apps are chosen by key, not by object: `DockService.items` is rebuilt
    // whenever a window changes, and the objects with it.
    property string selectedKey: ""
    readonly property var selected: root.selectedKey === "" ? null : root.itemByKey(root.selectedKey)
    property int hoveredIndex: -1
    // The popout as the right-click menu rather than the windows.
    property bool menu: false
    // A pinned icon being dragged, and the one under the pointer.
    property string draggedKey: ""
    property string dropKey: ""

    signal launcherRequested()

    function itemByKey(key: string): var {
        return DockService.items.find(item => item.key === key) ?? null
    }

    onSelectedChanged: if (root.selected === null) root.menu = false

    readonly property int icon: Theme.dockIcon
    readonly property int column: Math.round(root.icon * 1.35) + 16
    // The selected icon's centre, in window coordinates, which the popout
    // grows from.
    property point anchorAt: Qt.point(0, 0)

    function choose(tile: Item, item: var, menu: bool): void {
        root.anchorAt = tile.mapToItem(null, tile.width / 2, tile.height / 2)
        root.selectedKey = item.key
        root.menu = menu
    }

    readonly property bool bottom: root.edge === "bottom"
    readonly property bool hides: DockService.autohide

    edge: DockService.edge
    readonly property bool clickOpens: SettingsService.edgeOpen === "click"
    readonly property bool opened: root.clickOpens && DrawerService.dockOpen
        && DrawerService.edgeScreen === root.screen.name
    reach: root.clickOpens ? 0 : 3
    position: DockService.alignment === "start" ? 0 : DockService.alignment === "end" ? 1 : 0.5
    // The dock keeps its depth; the popout grows out of its edge. While one
    // is open the dock runs long enough along its edge to hold it between
    // the two fillets.
    readonly property int joinFillet: 12
    along: Math.max((root.bottom ? icons.implicitWidth : icons.implicitHeight) + 32,
        root.selected === null ? 0
            : (root.bottom ? popout.fullWidth : popout.fullHeight) + 2 * (root.innerRadius + root.joinFillet))
    depth: root.column
    // Not under a fullscreen window on this screen, nor on a screen it is not
    // shown on.
    readonly property bool wanted: DockService.shownOn(root.screen.name)
        && (root.live || DockService.everywhere || root.opened)
    reserve: DockService.enabled && !root.hides && (root.live || DockService.everywhere)
        ? root.column : 0
    shown: root.wanted
        && (!root.hides || root.opened || (!root.clickOpens && (root.edgeHovered || root.hovered))
            || root.selected !== null)
    framed: root.shown && root.hides

    // Opened by click, it goes back once the pointer has been in it and
    // left, or after a while if it never came.
    property bool visited: false
    onHoveredChanged: if (root.hovered) root.visited = true
    onOpenedChanged: root.visited = false

    Timer {
        running: root.opened && !root.hovered && !popoutHover.hovered && root.selected === null
        interval: root.visited ? 900 : 4000
        onTriggered: DrawerService.dockOpen = false
    }

    onShownChanged: {
        if (!root.shown) {
            root.hoveredIndex = -1
            root.selectedKey = ""
            root.draggedKey = ""
            root.dropKey = ""
        }
    }

    Behavior on depth {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // Leaving the dock and its popout closes the popout after a moment.
    Timer {
        running: !root.hovered && !popoutHover.hovered && root.selected !== null
        interval: 900
        onTriggered: root.selectedKey = ""
    }

    // The dock's inner edge (where the drawer ends), and the stretch of it
    // a piece growing out of it may use: the straight part between the
    // dock's rounded ends, clear of the fillets.
    readonly property real innerEdge: root.frameThickness + root.column
    readonly property real alongFirst: root.alongStart + root.innerRadius + root.joinFillet
    readonly property real alongLast: root.alongStart + root.along - root.innerRadius - root.joinFillet

    // Where along the edge a piece of `length` centred on `centre` goes.
    function placeAlong(centre: real, length: real): real {
        return Math.max(root.alongFirst, Math.min(root.alongLast - length, centre - length / 2))
    }

    floatingMask: popout
    floating: [
        DockPopout {
            id: popout

            app: root.selected
            menu: root.menu
            edge: root.edge
            workspaceBase: HyprlandService.baseOn(root.screen.name)
            x: root.edge === "left" ? root.innerEdge
                : root.edge === "right" ? root.width - root.innerEdge - popout.width
                : root.placeAlong(root.anchorAt.x, popout.fullWidth)
            y: root.bottom ? root.height - root.innerEdge - popout.height
                : root.placeAlong(root.anchorAt.y, popout.fullHeight)
            onDone: root.selectedKey = ""
            onWindowsRequested: root.menu = false

            HoverHandler { id: popoutHover }
        },

        Joint {
            target: popout
            reveal: popout.reveal
        },

        // An icon rested on for a moment names its app in a tab grown out of
        // the dock's edge.
        Item {
            id: nameTab

            readonly property bool wanted: root.peekApp !== null && root.selected === null
                && root.draggedKey === "" && root.shown
            property real reveal: nameTab.wanted ? 1 : 0
            property string label: ""
            readonly property real fullWidth: nameText.implicitWidth + 28
            readonly property real fullHeight: 32

            onWantedChanged: if (nameTab.wanted) nameTab.label = root.peekApp.name
                + (root.peekApp.windows.length > 1 ? `  ·  ${root.peekApp.windows.length}` : "")

            Behavior on reveal { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }

            visible: nameTab.reveal > 0.01
            clip: true
            width: root.bottom ? nameTab.fullWidth : nameTab.fullWidth * nameTab.reveal
            height: root.bottom ? nameTab.fullHeight * nameTab.reveal : nameTab.fullHeight
            x: root.edge === "left" ? root.innerEdge
                : root.edge === "right" ? root.width - root.innerEdge - nameTab.width
                : root.placeAlong(root.peekAt.x, nameTab.fullWidth)
            y: root.bottom ? root.height - root.innerEdge - nameTab.height
                : root.placeAlong(root.peekAt.y, nameTab.fullHeight)

            Rectangle {
                width: nameTab.fullWidth
                height: nameTab.fullHeight
                x: root.edge === "left" ? nameTab.width - nameTab.fullWidth : 0
                y: root.bottom ? nameTab.height - nameTab.fullHeight : 0
                color: Theme.islandGround
                topLeftRadius: root.edge === "left" ? 0 : 12
                bottomLeftRadius: root.edge === "left" || root.bottom ? 0 : 12
                topRightRadius: root.edge === "right" ? 0 : 12
                bottomRightRadius: root.edge === "right" || root.bottom ? 0 : 12

                Text {
                    id: nameText

                    anchors.centerIn: parent
                    text: nameTab.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
            }
        },

        Joint {
            target: nameTab
            reveal: nameTab.reveal
        }
    ]

    // The app whose icon is rested on, after a moment (`peekIntent`), and
    // that icon's centre in window coordinates.
    property var peekApp: null
    property point peekAt: Qt.point(0, 0)
    property var restingApp: null
    property point restingAt: Qt.point(0, 0)

    Timer {
        id: peekIntent

        interval: 280
        onTriggered: {
            root.peekApp = root.restingApp
            root.peekAt = root.restingAt
        }
    }

    function rest(tile: Item, item: var): void {
        root.restingApp = item
        root.restingAt = tile.mapToItem(null, tile.width / 2, tile.height / 2)
        peekIntent.restart()
    }

    function leave(item: var): void {
        if (root.restingApp?.key !== item.key)
            return
        peekIntent.stop()
        root.restingApp = null
        root.peekApp = null
    }

    // Two concave fillets where a piece meets the dock's edge, one at each
    // end, so the piece reads as grown out of the dock.
    component Joint: Item {
        id: joint

        required property Item target
        property real reveal: 1

        anchors.fill: parent
        visible: joint.target.visible
        opacity: Math.min(1, joint.reveal * 2)

        // Before the piece (above it on a side, left of it at the bottom).
        NotchFillet {
            width: root.joinFillet
            height: root.joinFillet
            color: Theme.islandGround
            mirrored: root.edge !== "left"
            x: root.edge === "left" ? root.innerEdge
                : root.edge === "right" ? root.width - root.innerEdge - root.joinFillet
                : joint.target.x - root.joinFillet
            y: root.bottom ? root.height - root.innerEdge - root.joinFillet : joint.target.y - root.joinFillet
            transform: Scale { yScale: -1; origin.y: root.joinFillet / 2 }
        }

        // After the piece (below it on a side, right of it at the bottom).
        NotchFillet {
            width: root.joinFillet
            height: root.joinFillet
            color: Theme.islandGround
            mirrored: root.edge === "right"
            x: root.edge === "left" ? root.innerEdge
                : root.edge === "right" ? root.width - root.innerEdge - root.joinFillet
                : joint.target.x + joint.target.width
            y: root.bottom ? root.height - root.innerEdge - root.joinFillet : joint.target.y + joint.target.height
            transform: Scale { yScale: root.bottom ? -1 : 1; origin.y: root.joinFillet / 2 }
        }
    }

    // The icons, against the edge: a column on a side, a row at the bottom.
    Grid {
        id: icons

        columns: root.bottom ? Math.max(1, iconRepeater.count + (launcherTile.visible ? 1 : 0)) : 1
        x: root.bottom ? (parent.width - width) / 2 : root.edge === "left" ? 8 : parent.width - width - 8
        y: root.bottom ? parent.height - height - 8 : (parent.height - height) / 2

        // The launcher button, first (the Dock page's "launcher button").
        Item {
            id: launcherTile

            visible: DockService.hasLauncher
            width: root.bottom ? root.icon + 10 : root.column - 16
            height: root.bottom ? root.column - 16 : root.icon + 10

            Text {
                anchors.centerIn: parent
                text: "󰀻"
                font.family: Theme.fontMono
                font.pixelSize: Math.round(root.icon * 0.6)
                color: launcherMouse.containsMouse ? Theme.accent : Theme.text
            }

            MouseArea {
                id: launcherMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launcherRequested()
            }
        }

        Repeater {
            id: iconRepeater

            // Keyed, so a window or title change does not recreate the tile
            // being dragged (its release is what ends the drag).
            model: ScriptModel {
                objectProp: "key"
                values: DockService.items
            }

            Item {
                id: tile

                required property var modelData
                required property int index
                readonly property int distance: root.hoveredIndex < 0 ? 99 : Math.abs(tile.index - root.hoveredIndex)
                readonly property real magnified: !SettingsService.dockMagnify ? 1
                    : tile.distance === 0 ? 1.3 : tile.distance === 1 ? 1.12 : 1
                readonly property string iconSource: DockApps.iconOf(tile.modelData)
                readonly property bool chosen: root.selectedKey === tile.modelData.key

                width: root.bottom ? root.icon * tile.magnified + 10 : root.column - 16
                height: root.bottom ? root.column - 16 : root.icon * tile.magnified + 10

                Behavior on height { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic } }

                // A dot per window, up to three, on the edge's side.
                Grid {
                    columns: root.bottom ? 3 : 1
                    x: root.bottom ? (parent.width - width) / 2 : root.edge === "left" ? 0 : parent.width - width
                    y: root.bottom ? parent.height - height : (parent.height - height) / 2
                    spacing: 3

                    Repeater {
                        model: Math.min(3, tile.modelData.windows.length)

                        Rectangle { width: 4; height: 4; radius: 2; color: Theme.accent }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.icon * tile.magnified + 8
                    height: width
                    radius: Theme.radiusLarge
                    color: tile.chosen ? Theme.islandSurfaceHover : "transparent"
                    // Where a dragged pin would land.
                    border.color: Theme.accent
                    border.width: root.draggedKey !== "" && root.dropKey === tile.modelData.key
                        && root.draggedKey !== tile.modelData.key ? 2 : 0
                }

                Item {
                    anchors.centerIn: parent
                    width: root.icon * tile.magnified
                    height: width
                    opacity: root.draggedKey === tile.modelData.key ? 0.45 : 1

                    Image {
                        id: picture

                        anchors.fill: parent
                        source: tile.iconSource
                        visible: tile.iconSource !== "" && status === Image.Ready
                        sourceSize: Qt.size(Theme.dockIcon * 2, Theme.dockIcon * 2)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !picture.visible
                        text: "󰀻"
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(parent.width * 0.6)
                        color: Theme.textMuted
                    }
                }

                MouseArea {
                    id: tileMouse

                    property point pressedAt: Qt.point(0, 0)
                    // Set by a drop, so the release that ends it is not a click.
                    property bool dropped: false

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: root.draggedKey !== "" ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    onEntered: {
                        root.hoveredIndex = tile.index
                        root.rest(tile, tile.modelData)
                    }
                    onExited: {
                        if (root.hoveredIndex === tile.index)
                            root.hoveredIndex = -1
                        root.leave(tile.modelData)
                    }
                    onPressed: mouse => {
                        tileMouse.pressedAt = Qt.point(mouse.x, mouse.y)
                        // A drop that wrote nothing makes no click either, so
                        // the flag is only good until the next press.
                        tileMouse.dropped = false
                    }
                    // Past 10 px with the left button held, a pin is being dragged.
                    onPositionChanged: mouse => {
                        if (!(mouse.buttons & Qt.LeftButton) || !tile.modelData.pinned)
                            return
                        if (root.draggedKey === ""
                                && Math.hypot(mouse.x - tileMouse.pressedAt.x, mouse.y - tileMouse.pressedAt.y) < 10)
                            return
                        root.draggedKey = tile.modelData.key
                        root.selectedKey = ""
                        const point = tileMouse.mapToItem(icons, mouse.x, mouse.y)
                        root.dropKey = icons.childAt(point.x, point.y)?.modelData?.key ?? ""
                    }
                    // The move rebuilds every tile, this one included, so it
                    // runs after the handler is done with it.
                    onReleased: mouse => {
                        if (root.draggedKey === "")
                            return
                        const moving = root.draggedKey
                        const target = root.dropKey
                        root.draggedKey = ""
                        root.dropKey = ""
                        tileMouse.dropped = true
                        const from = DockService.pinned.indexOf(root.itemByKey(moving)?.id ?? "")
                        const to = DockService.pinned.indexOf(root.itemByKey(target)?.id ?? "")
                        if (from >= 0 && to >= 0)
                            Qt.callLater(() => DockService.reorder(from, to))
                    }
                    // A drop whose release lands outside the tile makes no
                    // click, and a cancelled press ends the drag.
                    onCanceled: {
                        tileMouse.dropped = false
                        root.draggedKey = ""
                        root.dropKey = ""
                    }
                    // A click waits a moment so a double-click is not taken for one.
                    onClicked: mouse => {
                        if (tileMouse.dropped) {
                            tileMouse.dropped = false
                            return
                        }
                        if (mouse.button === Qt.RightButton) {
                            singleClick.stop()
                            if (tile.chosen && root.menu)
                                root.selectedKey = ""
                            else
                                root.choose(tile, tile.modelData, true)
                            return
                        }
                        singleClick.restart()
                    }
                    onDoubleClicked: mouse => {
                        if (mouse.button !== Qt.LeftButton)
                            return
                        singleClick.stop()
                        DockService.activate(tile.modelData)
                        root.selectedKey = ""
                    }

                    Timer {
                        id: singleClick

                        interval: 230
                        onTriggered: {
                            if (tile.modelData.windows.length === 0)
                                DockService.launch(tile.modelData)
                            else if (tile.chosen && !root.menu)
                                root.selectedKey = ""
                            else
                                root.choose(tile, tile.modelData, false)
                        }
                    }
                }
            }
        }
    }
}
