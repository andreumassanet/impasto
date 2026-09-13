// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O N I T O R   C A N V A S                                            │
// │   the screens to scale · dragged into place, snapped to each other       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"

// The compositor's coordinate space, scaled to fit. Screens are dragged into
// place and, on release, snap to the nearest edge of another screen within
// reach, so a free drag never leaves a one-pixel gap or an overlap. Snapping
// only on release keeps the plate from jumping under the pointer.
Item {
    id: root

    // `MonitorService.monitors`, or a subset of it.
    property var monitors: []
    property string selected: ""

    signal picked(string description)
    // The whole arrangement as { description: { x, y } }: normalising after
    // a move can shift every screen, not just the one dragged.
    signal arranged(var positions)

    // Disabled screens report zero geometry; the section lists them below.
    readonly property var lit: root.monitors.filter(m => !m.disabled)

    readonly property int spanX: {
        let far = 1
        for (const m of root.lit)
            far = Math.max(far, m.x + m.width)
        return far
    }
    readonly property int spanY: {
        let far = 1
        for (const m of root.lit)
            far = Math.max(far, m.y + m.height)
        return far
    }

    // ── FIT ─────────────────────────────────────────────────────────────────
    //
    // The span is fitted with a margin and the arrangement centred in it, so
    // a screen can be dropped left of or above all the others. 1.6 leaves 30%
    // of the span free on each side.
    readonly property real slack: 1.6

    readonly property real factor: Math.min(
        (width - 2 * padding) / (root.spanX * root.slack),
        (height - 2 * padding) / (root.spanY * root.slack))

    readonly property int padding: 26

    // Where the origin of the compositor's space sits on the canvas.
    readonly property real originX:
        (width - 2 * padding - root.spanX * root.factor) / 2
    readonly property real originY:
        (height - 2 * padding - root.spanY * root.factor) / 2

    // Snap distance in compositor pixels, derived from a fixed 80 px on the
    // canvas so it feels the same at any scale.
    readonly property int reach: Math.round(80 / Math.max(root.factor, 0.0001))

    function positionOf(description: string): var {
        const found = root.lit.find(m => m.description === description)
        return found ? { x: found.x, y: found.y } : null
    }

    // Where a screen dropped at (x, y) snaps to. Each axis is decided on its
    // own, against four candidates per other screen: butted against either
    // side, or aligned with either edge. The nearest within `reach` wins.
    function settle(description: string, wantedX: real, wantedY: real): var {
        const me = root.lit.find(m => m.description === description)
        if (!me)
            return { x: Math.round(wantedX), y: Math.round(wantedY) }

        let x = Math.round(wantedX)
        let y = Math.round(wantedY)
        let nearestX = root.reach
        let nearestY = root.reach

        for (const other of root.lit) {
            if (other.description === description)
                continue

            for (const candidate of [other.x - me.width, other.x + other.width,
                                     other.x, other.x + other.width - me.width]) {
                const gap = Math.abs(candidate - wantedX)
                if (gap < nearestX) {
                    nearestX = gap
                    x = candidate
                }
            }

            for (const candidate of [other.y - me.height, other.y + other.height,
                                     other.y, other.y + other.height - me.height]) {
                const gap = Math.abs(candidate - wantedY)
                if (gap < nearestY) {
                    nearestY = gap
                    y = candidate
                }
            }
        }

        return { x: x, y: y }
    }

    // Every screen's position after the drop, shifted so the layout's top-left
    // is (0, 0). Hyprland accepts negative coordinates; normalising keeps the
    // same arrangement at the same numbers.
    function arrangementWith(description: string, at: var): var {
        const places = ({})
        for (const m of root.lit)
            places[m.description] = m.description === description
                ? { x: at.x, y: at.y }
                : { x: m.x, y: m.y }

        let leftmost = Infinity
        let topmost = Infinity
        for (const key in places) {
            leftmost = Math.min(leftmost, places[key].x)
            topmost = Math.min(topmost, places[key].y)
        }
        for (const key in places) {
            places[key].x -= leftmost
            places[key].y -= topmost
        }
        return places
    }

    // A well in the group's card, like the other previews on these pages.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1
    }

    Item {
        id: field

        x: root.padding
        y: root.padding
        width: parent.width - 2 * root.padding
        height: parent.height - 2 * root.padding

        Repeater {
            model: root.lit

            Rectangle {
                id: plate

                required property var modelData

                readonly property bool chosen:
                    plate.modelData.description === root.selected

                // Bound to the compositor's position except while dragging.
                x: drag.active ? x : root.originX + plate.modelData.x * root.factor
                y: drag.active ? y : root.originY + plate.modelData.y * root.factor
                width: plate.modelData.width * root.factor
                height: plate.modelData.height * root.factor

                radius: Theme.radiusSmall
                color: plate.chosen ? Theme.accent : Theme.islandSurfaceHover
                border.color: plate.chosen ? Theme.accent : Theme.islandBorder
                border.width: 1
                z: drag.active ? 2 : (plate.chosen ? 1 : 0)

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: plate.modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: plate.chosen ? Theme.accentText : Theme.text
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${plate.modelData.width}×${plate.modelData.height}`
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: plate.chosen ? Theme.accentText : Theme.textMuted
                        opacity: 0.8
                    }
                }

                // Marks the screen carrying the island.
                Text {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 5
                    visible: MonitorService.primaryName === plate.modelData.name
                    text: "★"
                    font.pixelSize: Theme.fontSizeSmall
                    color: plate.chosen ? Theme.accentText : Theme.accent
                }

                MouseArea {
                    id: drag

                    anchors.fill: parent
                    cursorShape: Qt.OpenHandCursor

                    property bool active: false
                    property real grabX: 0
                    property real grabY: 0

                    onPressed: mouse => {
                        root.picked(plate.modelData.description)
                        drag.grabX = mouse.x
                        drag.grabY = mouse.y
                        drag.active = true
                    }

                    onPositionChanged: mouse => {
                        if (!drag.active)
                            return
                        plate.x += mouse.x - drag.grabX
                        plate.y += mouse.y - drag.grabY
                    }

                    onReleased: {
                        if (!drag.active)
                            return
                        drag.active = false
                        const at = root.settle(
                            plate.modelData.description,
                            (plate.x - root.originX) / root.factor,
                            (plate.y - root.originY) / root.factor)
                        root.arranged(root.arrangementWith(
                            plate.modelData.description, at))
                    }

                    onCanceled: drag.active = false
                }
            }
        }
    }
}
