// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O V E R V I E W   P A N E L                                            │
// │   workspace overview · live previews, keyboard navigation                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

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

    // Every workspace up to the maximum, not only those with a dot on the bar;
    // per screen, every screen's.
    readonly property var ids: HyprlandService.overviewIds
    readonly property int count: root.ids.length
    readonly property int columns: HyprlandService.overviewColumns
    readonly property int rows: HyprlandService.overviewRows
    // How many rows fit before the grid scrolls.
    readonly property int visibleRows: Math.max(1, Math.min(root.rows, HyprlandService.overviewRowsShown))
    readonly property int gap: 10

    // The screen this panel is on. It decides the shape of a cell; what a cell
    // MODELS is the screen its own workspace is on, which is not always this
    // one (`areaOf`).
    readonly property string screenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property int base: HyprlandService.baseOn(root.screenName)
    readonly property int activeId: HyprlandService.activeOn(root.screenName)
        || HyprlandService.activeId
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
    // That also keeps a short last row in range, since the count need not
    // divide by the column count.
    function selectBy(delta: int): void {
        const at = Math.max(0, root.ids.indexOf(root.selectedId))
        root.selectedId = root.ids[(at + delta + root.count) % root.count]
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
        root.selectedId = root.ids.indexOf(root.activeId) >= 0 ? root.activeId : root.ids[0]
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
            ((height - (root.visibleRows - 1) * root.gap) / root.visibleRows - 2 * board.inset)
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

        // The rows, scrolling by the wheel (or the arrows, which follow the
        // selection) once there are more than fit.
        Flickable {
            id: scroller

            anchors.fill: parent
            contentWidth: width
            contentHeight: Math.max(height, grid.height)
            clip: true
            interactive: grid.height > height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ScrollBar.vertical: ScrollBar {
                policy: grid.height > scroller.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                width: 6
            }

            // Brings the selected cell's row into view.
            function reveal(): void {
                const at = Math.max(0, root.ids.indexOf(root.selectedId))
                const top = Math.floor(at / root.columns) * (board.cellHeight + root.gap)
                if (top < scroller.contentY)
                    scroller.contentY = top
                else if (top + board.cellHeight > scroller.contentY + scroller.height)
                    scroller.contentY = top + board.cellHeight - scroller.height
            }

            Connections {
                target: root

                function onSelectedIdChanged(): void { scroller.reveal() }
            }

        GridLayout {
            id: grid

            x: Math.max(0, (scroller.width - width) / 2)
            y: Math.max(0, (scroller.height - height) / 2)
            columns: root.columns
            rowSpacing: root.gap
            columnSpacing: root.gap

            Repeater {
                model: root.count

                Item {
                    id: cell

                    required property int index

                    readonly property int workspaceId: root.ids[cell.index]
                    readonly property bool focused: root.activeId === cell.workspaceId
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
                            ? Theme.accent : Theme.borderIn(QsWindow.window)

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
                            model: ScriptModel {
                                values: cell.windows
                                objectProp: "address"
                            }

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
                                        ? Theme.blue : Theme.borderIn(QsWindow.window)

                                    Behavior on border.color {
                                        ColorAnimation { duration: Theme.durationFast }
                                    }

                                    // A window resized while the overview is
                                    // open (a neighbour moved away) hands the
                                    // compositor a buffer of another size, and
                                    // a live capture ends on that failure
                                    // rather than following it. One that loses
                                    // its picture is started again.
                                    Loader {
                                        id: capture

                                        anchors.fill: parent

                                        readonly property Timer again: Timer {
                                            interval: Theme.durationFast
                                            onTriggered: {
                                                capture.showing = false
                                                capture.active = false
                                                capture.active = true
                                            }
                                        }

                                        // Whether the capture shows a frame now,
                                        // and whether any capture here has, which
                                        // the still below holds.
                                        property bool showing: false
                                        property bool held: false

                                        // A new size is a capture about to fail:
                                        // the still holds from the moment
                                        // Hyprland reports it, and a fresh
                                        // capture starts once the window has
                                        // drawn at that size.
                                        readonly property string shape:
                                            thumb.modelData.size[0] + "x" + thumb.modelData.size[1]
                                        property bool resizing: false
                                        onShapeChanged: {
                                            capture.resizing = true
                                            capture.tries = 0
                                            capture.settle.restart()
                                        }
                                        readonly property Timer settle: Timer {
                                            interval: Theme.durationMorph
                                            onTriggered: capture.again.restart()
                                        }

                                        // Restarts spent on a capture that has
                                        // not shown a frame yet (below).
                                        property int tries: 0

                                        sourceComponent: ScreencopyView {
                                            id: view

                                            captureSource: root.toplevelFor(thumb.modelData)
                                            live: true
                                            paintCursor: false
                                            // Whole pixels of the size the frame
                                            // settles at, so the compositor is not
                                            // asked to rescale every frame.
                                            constraintSize: Qt.size(
                                                Math.max(1, Math.round(thumb.modelData.size[0] * cell.factor)),
                                                Math.max(1, Math.round(thumb.modelData.size[1] * cell.factor)))
                                            // A window carried to another cell
                                            // starts a capture that can fail
                                            // before its first frame. A few more
                                            // tries; a window with nothing to draw
                                            // stays blank after them.
                                            Timer {
                                                interval: Theme.durationMorph
                                                running: !view.hasContent && capture.tries < 8
                                                onTriggered: {
                                                    capture.tries += 1
                                                    capture.again.restart()
                                                }
                                            }

                                            // The failure ends the capture without
                                            // `stopped`; the picture going away is
                                            // the sign.
                                            property bool had: false
                                            onHasContentChanged: {
                                                if (had && !hasContent)
                                                    capture.again.restart()
                                                had = hasContent
                                                capture.showing = hasContent
                                                if (hasContent) {
                                                    capture.held = true
                                                    capture.resizing = false
                                                }
                                            }
                                        }
                                    }

                                    // The last frame, held while a capture
                                    // that lost its picture starts again, so
                                    // the gap is never a black hole.
                                    ShaderEffectSource {
                                        anchors.fill: parent
                                        sourceItem: capture
                                        hideSource: false
                                        live: capture.showing && !capture.resizing
                                        visible: !live && capture.held
                                    }

                                    // The app icon, for a window with no
                                    // capture, or none yet.
                                    Image {
                                        anchors.centerIn: parent
                                        width: Math.min(26, parent.width * 0.5)
                                        height: width
                                        visible: root.toplevelFor(thumb.modelData) === null
                                            || (!capture.held && !capture.showing)
                                        source: Theme.appIcon(thumb.modelData.class)
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

                    // Which screen a row of workspaces belongs to, and which ten it
                    // is when the screen has more than one, on its first cell.
                    Rectangle {
                        visible: HyprlandService.manyBlocks && cell.index % 10 === 0
                        x: 6
                        y: 6
                        z: 6
                        width: chipText.implicitWidth + 12
                        height: 18
                        radius: height / 2
                        color: Qt.alpha(Theme.island, 0.85)
                        border.color: Theme.islandBorder
                        border.width: 1

                        Text {
                            id: chipText

                            anchors.centerIn: parent
                            text: HyprlandService.overviewBlocks[Math.floor(cell.index / 10)]?.label ?? ""
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }
                    }

                    // The workspace number, only on empty cells; occupied ones
                    // are recognised by their windows. Hidden under the
                    // pointer. Opacity rather than `visible`, so it fades in
                    // when a cell empties.
                    Text {
                        anchors.centerIn: parent
                        text: HyprlandService.numberOn(cell.workspaceId, HyprlandService.overviewBlocks[Math.floor(cell.index / 10)]?.screen ?? "")
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

    // Every scratchpad: those of Settings → Scratchpads, and any other special
    // workspace with a window in it. As many to a row as `padsPerRow` allows,
    // the rest on rows below. One element for all of them: the open one is
    // lit and shows its window, rather than a second strip appearing.
    readonly property var pads: HyprlandService.overviewPads
    // As many to a row as the workspaces above, each the size of one of their
    // cells: the proportions of the screen, in the same columns. Worked out from
    // the island's declared width (`overview` in DynamicIsland: 1560, less 20 a
    // side), not from the layout, which the tiles are part of.
    readonly property int padColumns: Math.max(1, Math.min(root.pads.length, root.columns))
    readonly property real tileWidth: (1520 - (root.columns - 1) * root.gap) / root.columns
    readonly property real tileHeight: (root.tileWidth - 6) * root.aspect + 6
    readonly property int padRows: Math.ceil(root.pads.length / root.padColumns)

    // ── SCRATCHPAD TILES ────────────────────────────────────────────────────
    //
    // `overviewScratchpads`: one tile per scratchpad under the strip, each
    // with its apps and the key that opens it. A click runs its command or
    // toggles its workspace; a window dropped on one is sent there.
    GridLayout {
        visible: root.pads.length > 0
        Layout.fillWidth: false
        Layout.fillHeight: false
        Layout.alignment: Qt.AlignLeft
        Layout.preferredHeight: root.padRows * root.tileHeight + (root.padRows - 1) * root.gap
        // As wide as fits, then a new row: tiles stay one size and line up
        // with the strip above and each other.
        columns: root.padColumns
        rowSpacing: root.gap
        columnSpacing: root.gap

        Repeater {
            model: root.pads

            ClippingRectangle {
                id: pad

                required property var modelData
                readonly property string workspace: `special:${pad.modelData.name}`
                // Its apps, one icon per class and three at most, resolved as
                // the dock resolves them.
                readonly property var classes: {
                    const icons = []
                    const seen = []
                    for (const client of HyprlandService.specialClientsOf(pad.workspace)) {
                        const windowClass = client.class || client.initialClass || ""
                        if (windowClass === "" || seen.indexOf(windowClass) >= 0)
                            continue
                        seen.push(windowClass)
                        const entry = DockService.entryOf(DockService.idFor(windowClass))
                        icons.push(Theme.appIcon(entry ? entry.icon : windowClass.toLowerCase()))
                    }
                    return icons.slice(0, 3)
                }
                readonly property bool open: HyprlandService.specialOn(root.screenName) === pad.workspace
                readonly property var windows: HyprlandService.specialClients
                    .filter(client => client.workspace.name === pad.workspace)
                // The window shown while the scratchpad is open.
                readonly property var shown: pad.open && pad.windows.length > 0 ? pad.windows[0] : null
                readonly property var capture: pad.shown ? root.toplevelFor(pad.shown) : null

                Layout.preferredWidth: root.tileWidth
                Layout.preferredHeight: root.tileHeight
                radius: Theme.radiusLarge
                contentUnderBorder: true
                color: Theme.island
                border.color: pad.open || padDrop.containsDrag || padMouse.containsMouse
                    ? Theme.accent : Theme.borderIn(QsWindow.window)
                border.width: pad.open || padDrop.containsDrag ? 2 : 1
                // The open scratchpad is lifted: a little larger and above its
                // neighbours.
                scale: pad.open ? 1.04 : 1
                z: pad.open ? 2 : 0

                Behavior on scale {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }

                Image {
                    anchors.fill: parent
                    // The wallpaper under the card, as under a workspace's cell, so the
                    // cells and the tiles read as one set.
                    source: WallpaperService.currentWallpaper !== ""
                        ? `file://${WallpaperService.currentWallpaper}` : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 480
                    // Clearer while open: the wallpaper comes up.
                    opacity: pad.open ? 0.6 : 0.3

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.durationFast }
                    }
                }

                // The open scratchpad's window, live, as large as the tile
                // lets it be at the window's own proportions.
                ScreencopyView {
                    visible: pad.capture !== null
                    anchors.centerIn: parent
                    height: parent.height
                    width: pad.shown ? Math.min(parent.width, parent.height * pad.shown.size[0] / Math.max(1, pad.shown.size[1])) : 0
                    captureSource: pad.capture
                    live: true
                    paintCursor: false
                }

                // The accent washes a tile a window is dragged over.
                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(Theme.accent, 0.25)
                    opacity: padDrop.containsDrag ? 1 : 0
                }

                // Behind the name once it is in the corner, over the window.
                Rectangle {
                    visible: pad.capture !== null
                    x: labelColumn.x - 6
                    y: labelColumn.y - 3
                    width: labelColumn.width + 12
                    height: labelColumn.height + 6
                    radius: height / 2
                    color: Qt.alpha(Theme.island, 0.82)
                }

                ColumnLayout {
                    id: labelColumn

                    // With the window showing, the name steps aside to the corner.
                    anchors.centerIn: pad.capture === null ? parent : undefined
                    x: 14
                    y: 9
                    spacing: 2

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        PadIcon {
                            visible: pad.classes.length === 0 && value !== ""
                            value: pad.modelData.glyph ?? ""
                            size: 24
                        }

                        Repeater {
                            model: pad.classes

                            IconImage {
                                required property string modelData

                                implicitSize: 20
                                source: modelData
                            }
                        }

                        Text {
                            Layout.maximumWidth: Math.max(40, root.tileWidth - 70)
                            elide: Text.ElideRight
                            text: pad.modelData.name === "scratchpad" ? Tr.t("Scratchpad")
                                : (pad.modelData.label || pad.modelData.name)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: text !== "" && pad.capture === null
                        text: pad.modelData.keys ?? ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                MouseArea {
                    id: padMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closed()
                        Quickshell.execDetached([Quickshell.shellPath("scripts/scratchpad.sh"),
                                                 pad.modelData.name, pad.modelData.command ?? ""])
                    }
                }

                DropArea {
                    id: padDrop

                    anchors.fill: parent
                    onDropped: dropped => {
                        if (ghost.client)
                            HyprlandService.moveClientToNamed(ghost.client.address, pad.workspace)
                        dropped.accept()
                    }
                }
            }
        }
    }
}
