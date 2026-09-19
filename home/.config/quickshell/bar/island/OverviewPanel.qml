// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O V E R V I E W   P A N E L                                            │
// │   workspace overview · live previews, keyboard navigation                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

import "../../theme"
import "../../services"

// Workspaces in numbered order, each a scale model of the screen: every window
// is drawn at its real position and size divided by one factor, so a
// workspace's layout is recognisable at a glance.
//
// Thumbnails are live ScreencopyView captures of each toplevel, on every
// workspace. A hidden client gets no frame callbacks, but capturing a toplevel
// makes it draw again, so `render_unfocused` is not needed.
ColumnLayout {
    id: root

    signal closed()

    // Every workspace up to the maximum, not only those with a dot on the bar.
    readonly property int columns: Math.min(5, SettingsService.workspaceMax)
    readonly property int rows: Math.ceil(SettingsService.workspaceMax / root.columns)
    readonly property int gap: 10

    // The screen this panel is on. It decides the shape of a cell; what a cell
    // MODELS is the screen its own workspace is on, which is not always this
    // one (`areaOf`).
    readonly property string screenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var monitor: root.monitorNamed(root.screenName)
        ?? HyprlandService.monitors[0] ?? null

    function monitorNamed(name: string): var {
        return name === "" ? null
            : (HyprlandService.monitors.find(monitor => monitor.name === name) ?? null)
    }

    // The area windows can occupy on a monitor: its own place in the layout
    // plus its size, minus what the bar reserves, which hyprctl reports per
    // monitor as [left, top, right, bottom]. Modelling the whole screen would
    // draw the bar's strip as empty space above every window and make equal
    // gaps look unequal.
    //
    // A window's position is its real one, in the layout every screen shares,
    // so a cell modelling the wrong monitor puts every window on it thousands
    // of pixels outside the cell — which is a workspace that reads as empty.
    function areaFor(monitor: var): var {
        const width = monitor && monitor.width > 0 ? monitor.width : 1920
        const height = monitor && monitor.height > 0 ? monitor.height : 1200
        const reserved = (monitor && monitor.reserved) ? monitor.reserved : [0, 0, 0, 0]
        return {
            x: (monitor ? monitor.x : 0) + reserved[0],
            y: (monitor ? monitor.y : 0) + reserved[1],
            width: width - reserved[0] - reserved[2],
            height: height - reserved[1] - reserved[3]
        }
    }

    // The area a workspace's own screen offers. One nobody has made yet is
    // modelled on this screen, since that is where it would be made.
    function areaOf(workspaceId: int): var {
        return root.areaFor(root.monitorNamed(HyprlandService.monitorOf(workspaceId))
            ?? root.monitor)
    }

    readonly property var area: root.areaFor(root.monitor)
    readonly property real areaWidth: root.area.width
    readonly property real areaHeight: root.area.height
    readonly property real aspect: root.areaHeight / root.areaWidth

    // Hyprland knows each window's workspace and the Wayland toplevel has its
    // pixels, but Hyprland's address is not a handle the Wayland side knows.
    // They are matched on app id, then title; two windows of the same app with
    // the same title share a thumbnail. `Hyprland.toplevels` would join them
    // properly but reports nothing on Hyprland 0.55.
    function toplevelFor(client: var): var {
        const entries = ToplevelManager.toplevels.values
        return entries.find(entry => entry.appId === client.class
                                  && entry.title === client.title)
            ?? entries.find(entry => entry.title === client.title)
            ?? null
    }

    // ── ARROWS AND ENTER ────────────────────────────────────────────────────
    //
    // The bar's layer surface has the keyboard while a panel is open, so the
    // overview reads arrows rather than swallowing them. It opens with the
    // ring on the current workspace, so Enter alone is a no-op.
    property int selectedId: 1

    // Left and right by one, up and down by a row, wrapping modulo the count.
    // That also keeps a short last row in range, since `workspaceMax` need not
    // divide by the column count.
    function selectBy(delta: int): void {
        const count = SettingsService.workspaceMax
        root.selectedId = (root.selectedId - 1 + delta + count) % count + 1
    }

    function activate(): void {
        HyprlandService.focus(root.selectedId)
        root.closed()
    }

    Keys.onLeftPressed: root.selectBy(-1)
    Keys.onRightPressed: root.selectBy(1)
    Keys.onUpPressed: root.selectBy(-root.columns)
    Keys.onDownPressed: root.selectBy(root.columns)
    Keys.onReturnPressed: root.activate()
    Keys.onEnterPressed: root.activate()

    spacing: root.gap

    // Focus on open, or the arrows go to whatever had the keyboard before.
    // Escape bubbles up to the island.
    Component.onCompleted: {
        HyprlandService.loadClients()
        HyprlandService.loadMonitors()
        void ToplevelManager.toplevels
        root.selectedId = Math.min(Math.max(1, HyprlandService.activeId),
                                   SettingsService.workspaceMax)
        root.forceActiveFocus()
    }

    // ── GRID ────────────────────────────────────────────────────────────────

    Item {
        id: board

        Layout.fillWidth: true
        Layout.fillHeight: true

        // A thin margin around the model. Edge to edge, a maximised window's
        // outline would sit on the cell boundary, where the rounded mask cuts
        // it.
        readonly property real inset: 3

        // Sized by whichever dimension runs out first, then centred. The cell
        // is the model plus a margin of constant thickness; letterboxing the
        // model in a cell of the workspace's aspect would make the margin
        // uneven (`inset` across, `inset * aspect` down).
        readonly property real cellWidth: Math.min(
            (width - (root.columns - 1) * root.gap) / root.columns,
            ((height - (root.rows - 1) * root.gap) / root.rows - 2 * board.inset)
                / root.aspect + 2 * board.inset)
        readonly property real cellHeight:
            (board.cellWidth - 2 * board.inset) * root.aspect + 2 * board.inset

        // The box a cell's model is drawn into. The scale is a cell's own,
        // since the screens it models need not be the same size.
        readonly property real modelWidth: board.cellWidth - 2 * board.inset
        readonly property real modelHeight: board.cellHeight - 2 * board.inset

        // False while the grid is still resizing. Every thumbnail's geometry
        // comes from `cellWidth`, which grows from zero while the panel morphs
        // open, so with Behaviors enabled from the start each window would
        // crawl in from the corner. Move animations wait for this instead.
        property bool settled: false

        onCellWidthChanged: {
            board.settled = false
            settle.restart()
        }

        readonly property Timer settle: Timer {
            id: settle

            interval: 120
            running: true
            onTriggered: board.settled = true
        }

        GridLayout {
            anchors.centerIn: parent
            columns: root.columns
            rowSpacing: root.gap
            columnSpacing: root.gap

            Repeater {
                model: SettingsService.workspaceMax

                Item {
                    id: cell

                    required property int index

                    readonly property int workspaceId: cell.index + 1
                    readonly property bool focused: HyprlandService.activeId === cell.workspaceId
                    readonly property bool selected: root.selectedId === cell.workspaceId
                    readonly property var windows: HyprlandService.clientsOn(cell.workspaceId)
                    readonly property bool empty: cell.windows.length === 0

                    // The screen this cell models, and one scale that fits it
                    // into the cell whichever way it runs out first.
                    readonly property var area: root.areaOf(cell.workspaceId)
                    readonly property real factor: Math.min(
                        board.modelWidth / cell.area.width,
                        board.modelHeight / cell.area.height)

                    // The topmost window at a point on the real screen
                    // (floating above tiled, as drawn). Resolves drops without
                    // a DropArea in every thumbnail.
                    function windowAt(screenX: real, screenY: real, exclude: string): var {
                        const stack = cell.windows.slice().sort(
                            (a, b) => (a.floating ? 1 : 0) - (b.floating ? 1 : 0))
                        for (let i = stack.length - 1; i >= 0; i--) {
                            const client = stack[i]
                            if (client.address === exclude)
                                continue
                            if (screenX >= client.at[0]
                                    && screenX <= client.at[0] + client.size[0]
                                    && screenY >= client.at[1]
                                    && screenY <= client.at[1] + client.size[1])
                                return client
                        }
                        return null
                    }
                    readonly property bool lit: cellHover.containsMouse || dropTarget.containsDrag

                    Layout.preferredWidth: board.cellWidth
                    Layout.preferredHeight: board.cellHeight

                    // ── PICTURE ─────────────────────────────────────────────
                    //
                    // A ClippingRectangle clips the wallpaper and thumbnails
                    // to the cell's rounded border. `clip` is rectangular, and
                    // a layer mask would cost a texture per cell.
                    ClippingRectangle {
                        id: picture

                        anchors.fill: parent
                        // Border over the content. Otherwise the content item
                        // is inset by the border width, which shifts every
                        // window, and shifts them again when the border
                        // thickens on focus.
                        contentUnderBorder: true
                        radius: Theme.radiusLarge
                        color: Theme.island
                        // Both rings in the accent, told apart by weight: thin
                        // for the current workspace, thick for Enter's target.
                        // They coincide on open and separate on the first
                        // arrow press.
                        border.width: cell.selected || dropTarget.containsDrag ? 2 : 1
                        border.color: cell.selected || cell.focused
                                        || dropTarget.containsDrag
                            ? Theme.accent : Theme.islandBorder

                        Behavior on border.color {
                            ColorAnimation { duration: Theme.durationFast }
                        }

                        // The wallpaper. The same picture in every cell, so Qt
                        // loads it once.
                        Image {
                            anchors.fill: parent
                            source: WallpaperService.currentWallpaper !== ""
                                ? `file://${WallpaperService.currentWallpaper}` : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 480
                            opacity: cell.empty ? 0.62 : 0.3

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.durationFast }
                            }
                        }

                        // ── WINDOWS ─────────────────────────────────────────

                        Repeater {
                            model: cell.windows

                            Item {
                                id: thumb

                                required property var modelData

                                // Monitor coordinates, scaled.
                                x: board.inset
                                    + (thumb.modelData.at[0] - cell.area.x) * cell.factor
                                y: board.inset
                                    + (thumb.modelData.at[1] - cell.area.y) * cell.factor
                                width: Math.max(8, thumb.modelData.size[0] * cell.factor)
                                height: Math.max(8, thumb.modelData.size[1] * cell.factor)

                                // Animate moves (swap, float, resize), but not
                                // until the grid has settled.
                                Behavior on x {
                                    enabled: board.settled
                                    NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
                                }
                                Behavior on y {
                                    enabled: board.settled
                                    NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
                                }
                                Behavior on width {
                                    enabled: board.settled
                                    NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
                                }
                                Behavior on height {
                                    enabled: board.settled
                                    NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
                                }

                                // Floating above tiled: the only stacking
                                // information hyprctl reports.
                                z: thumb.modelData.floating ? 2 : 1

                                // Per-corner radius: a corner touching the
                                // workspace's corner takes the cell's curve;
                                // elsewhere it gets the small radius.
                                readonly property real gapL: thumb.x - board.inset
                                readonly property real gapT: thumb.y - board.inset
                                readonly property real gapR:
                                    cell.width - board.inset - (thumb.x + thumb.width)
                                readonly property real gapB:
                                    cell.height - board.inset - (thumb.y + thumb.height)

                                function corner(a: real, b: real): real {
                                    return Math.max(Theme.radiusSmall,
                                                    Theme.radiusLarge - Math.max(a, b))
                                }

                                ClippingRectangle {
                                    id: frame

                                    anchors.fill: parent
                                    topLeftRadius: thumb.corner(thumb.gapL, thumb.gapT)
                                    topRightRadius: thumb.corner(thumb.gapR, thumb.gapT)
                                    bottomLeftRadius: thumb.corner(thumb.gapL, thumb.gapB)
                                    bottomRightRadius: thumb.corner(thumb.gapR, thumb.gapB)
                                    color: Theme.island
                                    // Constant width; only the colour
                                    // changes. Thickening on hover would move
                                    // the edge the capture is inset from and
                                    // rescale the thumbnail by a pixel.
                                    border.width: 2
                                    border.color: windowHover.containsMouse
                                        ? Theme.blue : Theme.islandBorder

                                    Behavior on border.color {
                                        ColorAnimation { duration: Theme.durationFast }
                                    }

                                    ScreencopyView {
                                        anchors.fill: parent
                                        captureSource: root.toplevelFor(thumb.modelData)
                                        live: true
                                        paintCursor: false
                                        // Whole pixels, so the compositor is
                                        // not asked to rescale the capture by
                                        // a fraction of one every frame.
                                        constraintSize: Qt.size(
                                            Math.max(1, Math.round(frame.width)),
                                            Math.max(1, Math.round(frame.height)))
                                    }

                                    // The app icon, for a window with no
                                    // capture.
                                    Image {
                                        anchors.centerIn: parent
                                        width: Math.min(26, parent.width * 0.5)
                                        height: width
                                        visible: root.toplevelFor(thumb.modelData) === null
                                        source: Quickshell.iconPath(thumb.modelData.class, true)
                                        sourceSize.width: 52
                                        sourceSize.height: 52
                                    }
                                }

                                MouseArea {
                                    id: windowHover

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        | Qt.MiddleButton

                                    // The ghost lives above the whole grid
                                    // (below). Inside a cell it would be
                                    // clipped by the cell's mask and stacked
                                    // under every later cell.
                                    drag.target: ghost
                                    drag.threshold: 6

                                    // Only the left button starts a drag; a
                                    // middle press is a click.
                                    onPressed: mouse => {
                                        if (mouse.button !== Qt.LeftButton)
                                            return
                                        const at = thumb.mapToItem(board, 0, 0)
                                        ghost.client = thumb.modelData
                                        ghost.x = at.x
                                        ghost.y = at.y
                                        ghost.width = thumb.width
                                        ghost.height = thumb.height
                                    }

                                    // Not shown on press, or a click would
                                    // flash a copy of the window over the grid.
                                    onPositionChanged: {
                                        if (drag.active) {
                                            ghost.dragging = true
                                            return
                                        }
                                        if (board.settled)
                                            root.selectedId = cell.workspaceId
                                    }

                                    onReleased: {
                                        if (drag.active)
                                            ghost.Drag.drop()
                                        ghost.dragging = false
                                        ghost.client = null
                                    }

                                    // Left focuses, right closes, middle
                                    // toggles floating. The panel stays open
                                    // for the last two.
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            HyprlandService.closeWindow(thumb.modelData.address)
                                            return
                                        }
                                        if (mouse.button === Qt.MiddleButton) {
                                            HyprlandService.toggleFloating(thumb.modelData.address)
                                            return
                                        }
                                        HyprlandService.focusWindow(thumb.modelData.address)
                                        root.closed()
                                    }
                                }
                            }
                        }
                    }

                    // The workspace number, only on empty cells; occupied ones
                    // are recognised by their windows. Hidden under the
                    // pointer. Opacity rather than `visible`, so it fades in
                    // when a cell empties.
                    Text {
                        anchors.centerIn: parent
                        text: cell.workspaceId
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(cell.height * 0.44)
                        font.weight: Font.DemiBold
                        // Plain text colour; the frame already marks the
                        // focused workspace.
                        color: Theme.text
                        opacity: {
                            if (!cell.empty)
                                return 0
                            return cell.lit ? 0.2 : 0.3
                        }
                        z: 4

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.durationMedium }
                        }
                    }

                    // A click on the cell switches to it; windows on top take
                    // their own clicks first.
                    MouseArea {
                        id: cellHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        z: -1

                        // Hover moves the same ring as the arrows, so what is
                        // lit is what Enter does. `onPositionChanged` also
                        // fires when the item itself moves, which it does while
                        // the panel morphs open, so it is ignored until
                        // `board.settled`; otherwise the ring would land on
                        // whichever cell grew under a resting pointer.
                        onPositionChanged: {
                            if (board.settled)
                                root.selectedId = cell.workspaceId
                        }
                        onClicked: {
                            HyprlandService.focus(cell.workspaceId)
                            root.closed()
                        }
                    }

                    // One drop area per cell; where the drop lands decides
                    // what happens.
                    DropArea {
                        id: dropTarget

                        anchors.fill: parent

                        onDropped: dropped => {
                            const client = ghost.client
                            if (!client) {
                                dropped.accept()
                                return
                            }

                            // Back to monitor coordinates. The ghost's hot spot
                            // is its centre.
                            const screenX = cell.area.x
                                + (dropped.x - board.inset) / cell.factor
                            const screenY = cell.area.y
                                + (dropped.y - board.inset) / cell.factor

                            // Another workspace: just move it. Tiling decides
                            // the position; a floating window keeps its own.
                            if (client.workspace.id !== cell.workspaceId) {
                                HyprlandService.moveClient(client.address, cell.workspaceId)
                                dropped.accept()
                                return
                            }

                            // Same workspace, floating: move it to exactly
                            // where it was dropped.
                            if (client.floating) {
                                HyprlandService.moveFloating(client.address,
                                    Math.round(screenX - client.size[0] / 2),
                                    Math.round(screenY - client.size[1] / 2))
                                dropped.accept()
                                return
                            }

                            // Same workspace, tiled, dropped on another tiled
                            // window: swap them. Anywhere else, nothing to do.
                            const under = cell.windowAt(screenX, screenY, client.address)
                            if (under && !under.floating)
                                HyprlandService.swapWindows(client.address, under.address)

                            dropped.accept()
                        }
                    }
                }
            }
        }

        // ── GHOST ───────────────────────────────────────────────────────────
        //
        // One ghost for the whole grid, declared last and parented here so it
        // passes over every cell and no cell's mask clips it. It carries its
        // own capture of the toplevel, since one view cannot be in two places.
        Rectangle {
            id: ghost

            property var client: null
            property bool dragging: false

            visible: ghost.client !== null && ghost.dragging
            radius: Theme.radiusSmall
            color: Theme.island
            border.color: Theme.blue
            border.width: 2
            opacity: 0.92
            z: 100

            Drag.active: ghost.visible
            Drag.source: ghost
            Drag.hotSpot.x: ghost.width / 2
            Drag.hotSpot.y: ghost.height / 2

            ScreencopyView {
                anchors.fill: parent
                anchors.margins: 2
                captureSource: ghost.client ? root.toplevelFor(ghost.client) : null
                live: true
                paintCursor: false
            }
        }
    }
}
