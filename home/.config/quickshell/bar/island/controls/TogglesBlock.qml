// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T O G G L E S   B L O C K                                              │
// │   quick toggles · paged when they do not fit                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// The toggle tiles, laid out as a grid inside one block.
//
// A page is what fits the block (a 2×3 holds six, a 4×2 eight); extra tiles go
// on further pages. Pages turn with the wheel on either axis, a sideways drag,
// the chevrons or the dots, which only appear when there is more than one page.
//
// Tiles are `ControlsService` toggles; the block only draws them.
Item {
    id: root

    property int cols: 2
    property int rows: 3

    signal panelRequested(string panel)
    signal dismissed()

    // The grid row this block draws (`ControlsService.toggleKeysOf`); empty in
    // the tray preview, which shows the default set.
    property string blockKey: ""

    readonly property var tiles: ControlsService.tilesOf(root.blockKey)
    readonly property int perPage: Math.max(1, root.cols * root.rows)
    readonly property int pages: Math.max(1, Math.ceil(root.tiles.length / root.perPage))
    readonly property bool paged: root.pages > 1

    // The dots take a lane off the bottom; a single page gives tiles the full
    // height.
    readonly property int lane: root.paged ? Theme.centrePagerLane : 0

    // A chevron, hidden (not disabled) at the end it points past.
    component Step: Item {
        id: step

        property string glyph: ""
        property bool usable: true

        signal stepped()

        width: 18
        height: root.lane

        Text {
            anchors.centerIn: parent
            text: step.glyph
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: press.containsMouse ? Theme.text : Theme.textMuted
            opacity: step.usable ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        MouseArea {
            id: press

            anchors.fill: parent
            enabled: step.usable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: step.stepped()
        }
    }

    Component.onCompleted: {
        SystemService.subscribe()
        NetworkService.refresh()
    }
    Component.onDestruction: SystemService.release()

    ListView {
        id: pager

        anchors.fill: parent
        anchors.bottomMargin: root.lane
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: Theme.durationMorph
        boundsBehavior: Flickable.StopAtBounds
        // Paged by the handlers below, not by flicking.
        interactive: false
        clip: true
        model: root.pages

        delegate: Item {
            id: page

            required property int index

            width: pager.width
            height: pager.height

            readonly property var slice:
                root.tiles.slice(page.index * root.perPage, (page.index + 1) * root.perPage)

            // Tiles match the grid's cells and spacing, laid out from the top
            // left so a short last page isn't stretched.
            readonly property real tileWidth:
                (page.width - (root.cols - 1) * Theme.centreGutter) / root.cols
            readonly property real tileHeight:
                (page.height - (root.rows - 1) * Theme.centreGutter) / root.rows

            Repeater {
                model: ScriptModel {
                    values: page.slice
                }

                QuickTile {
                    id: tile

                    required property var modelData
                    required property int index

                    x: (tile.index % root.cols) * (page.tileWidth + Theme.centreGutter)
                    y: Math.floor(tile.index / root.cols) * (page.tileHeight + Theme.centreGutter)
                    width: page.tileWidth
                    height: page.tileHeight

                    icon: tile.modelData.icon
                    label: tile.modelData.label
                    detail: tile.modelData.detail
                    active: tile.modelData.active
                    available: tile.modelData.available
                    expandable: tile.modelData.expandable

                    onToggled: {
                        tile.modelData.activate()
                        if (tile.modelData.closes)
                            root.dismissed()
                    }
                    onExpanded: root.panelRequested(tile.modelData.panel)
                }
            }
        }
    }

    // ── PAGING ──────────────────────────────────────────────────────────────
    //
    // One page per notch of 120 (Qt's unit for a wheel detent). Smaller deltas
    // accumulate first, since touchpads send a stream of them and a trailing
    // burst as the fingers lift. A change of direction resets the count.
    property real spun: 0

    function spin(forward: real): void {
        if (forward === 0)
            return
        if (root.spun !== 0 && (root.spun > 0) !== (forward > 0))
            root.spun = 0
        root.spun += forward
        if (Math.abs(root.spun) < 120)
            return
        const step = root.spun > 0 ? 1 : -1
        root.spun = 0
        root.turn(step)
    }

    function goTo(page: int): void {
        root.spun = 0
        pager.currentIndex = Math.max(0, Math.min(root.pages - 1, page))
    }

    function turn(delta: int): void {
        root.goTo(pager.currentIndex + delta)
    }

    // Down and right are both forward. Two handlers because a WheelHandler only
    // reads its own `orientation`; a single vertical one ignores horizontal
    // swipes.
    WheelHandler {
        enabled: root.paged
        orientation: Qt.Vertical
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.spin(-event.angleDelta.y)
    }

    WheelHandler {
        enabled: root.paged
        orientation: Qt.Horizontal
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.spin(-event.angleDelta.x)
    }

    // A sideways drag turns the page too; it takes over from a tile once the
    // pointer has moved past the drag threshold.
    DragHandler {
        id: swipe

        enabled: root.paged
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (swipe.active)
                return
            if (swipe.translation.x < -40)
                root.turn(1)
            else if (swipe.translation.x > 40)
                root.turn(-1)
        }
    }

    // ── PAGER ───────────────────────────────────────────────────────────────
    //
    // Dots with a chevron either side. The whole lane height is the hit area,
    // not the six-pixel dot.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        visible: root.paged
        spacing: 2

        Step {
            glyph: "󰅁"
            usable: pager.currentIndex > 0
            onStepped: root.turn(-1)
        }

        Repeater {
            model: root.pages

            Item {
                id: dot

                required property int index

                width: 14
                height: root.lane

                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: 6
                    radius: 3
                    color: dot.index === pager.currentIndex ? Theme.text
                        : (spot.containsMouse ? Theme.textMuted : Theme.islandBorder)

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                MouseArea {
                    id: spot

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goTo(dot.index)
                }
            }
        }

        Step {
            glyph: "󰅂"
            usable: pager.currentIndex < root.pages - 1
            onStepped: root.turn(1)
        }
    }
}
