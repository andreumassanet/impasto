// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L A Y O U T   E D I T O R                                              │
// │   bar layout editor · preview and module catalogue                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"
import "../bar/widgets"
import "../bar/modules"

// The bar drawn as it will look, with a catalogue of every piece under it.
// Drag a piece onto the bar, along it, across the island, or off it to remove
// it; clicking a catalogue piece appends it to the right side. Clicking a
// piece on the bar picks it and opens a card to override its look. The side a
// piece lands on is whichever half of the bar it is dropped over.
//
// The catalogue always lists everything; taking from it copies, so a piece
// can be on the bar twice.
//
// The bar is rebuilt whenever the drop gap moves, which would destroy a piece
// that owned its own drag. So pieces are only drawn, and one MouseArea over
// the editor hit-tests, carries a copy and writes the lists on release.
Item {
    id: root

    // `{ id, shape, figure }` per piece (`SettingsService.barItems`), less
    // any piece no longer in the catalogue and the split it leaves loose, so
    // the next write drops both.
    readonly property var leftItems: SettingsService.tidy(SettingsService.barItems("left")
        .filter(item => ModuleService.placeable(item.id)))
    readonly property var rightItems: SettingsService.tidy(SettingsService.barItems("right")
        .filter(item => ModuleService.placeable(item.id)))

    // Four groups: modules that measure (a ring or a symbol), modules that
    // read out a state or a count (a symbol), the buttons, then the workspace
    // strip and the split. The shape setting only applies to the first group.
    readonly property var catalogueGroups: {
        const gauges = []
        const readings = []
        for (const entry of ModuleService.catalogue) {
            if (!entry.bar)
                continue
            if (ModuleService.ringed.indexOf(entry.id) >= 0)
                gauges.push(entry.id)
            else
                readings.push(entry.id)
        }
        return [gauges, readings, Object.keys(ModuleService.buttons), ["workspaces", "split"]]
    }

    readonly property var catalogueIds:
        root.catalogueGroups.reduce((all, group) => all.concat(group), [])

    readonly property var catalogueItems:
        root.catalogueIds.map(id => ({ id: id, shape: "", figure: "", when: "" }))

    readonly property string barStyle: SettingsService.barStyle
    readonly property bool chromeless: root.barStyle === "island"

    readonly property int tileHeight: Theme.capsuleHeight + 4
    readonly property int street: 8
    readonly property int stagePad: 20
    readonly property int sceneMargin: 12
    readonly property int bandPad: 10

    // ── THE DRAG ────────────────────────────────────────────────────────────

    property string held: ""
    property var heldItem: null
    property string heldFrom: ""
    property int heldIndex: -1
    property string overSide: ""
    property int overIndex: -1
    property bool moved: false
    property point pressedAt: Qt.point(0, 0)
    property point pointer: Qt.point(0, 0)

    // ── PICKED PIECE ────────────────────────────────────────────────────────
    //
    // Identified by position, since the same piece can appear twice. Any move
    // clears the pick.

    property string pickedSide: ""
    property int pickedIndex: -1

    readonly property var picked: root.pickedSide === ""
        ? null : (root.listOf(root.pickedSide)[root.pickedIndex] ?? null)
    readonly property bool pickedModule: root.picked !== null
        && root.picked.id !== "workspaces" && root.picked.id !== "split"
        && !ModuleService.isButton(root.picked.id)

    function pick(side: string, index: int): void {
        const again = root.pickedSide === side && root.pickedIndex === index
        root.pickedSide = again ? "" : side
        root.pickedIndex = again ? -1 : index
    }

    function unpick(): void {
        root.pickedSide = ""
        root.pickedIndex = -1
    }

    // On the list as drawn: a saved piece that has left the catalogue would
    // otherwise shift the look onto its neighbour. The write drops it, as
    // every write from here does. An empty value reverts that field to the
    // bar-wide setting.
    function setLook(changes: var): void {
        const items = root.listOf(root.pickedSide).slice()
        if (root.pickedIndex < 0 || root.pickedIndex >= items.length)
            return
        items[root.pickedIndex] = Object.assign({}, items[root.pickedIndex], changes)
        SettingsService.setBarZone(root.pickedSide, items)
    }

    function removePicked(): void {
        const items = root.listOf(root.pickedSide).slice()
        items.splice(root.pickedIndex, 1)
        const side = root.pickedSide
        root.unpick()
        SettingsService.setBarZone(side, items)
    }

    function listOf(side: string): var {
        return side === "left" ? root.leftItems
            : side === "right" ? root.rightItems : root.catalogueItems
    }

    // A side's list during a drag: the carried piece removed and a gap
    // inserted where it would land.
    function shown(side: string): var {
        const list = root.listOf(side).slice()
        if (root.held === "" || !root.moved)
            return list
        if (root.heldFrom === side)
            list.splice(root.heldIndex, 1)
        if (root.overSide === side)
            list.splice(Math.min(root.overIndex, list.length), 0,
                { id: "__gap", shape: "", figure: "", when: "" })
        return list
    }

    // Splits a side's list into what the bar draws: capsules of adjacent
    // modules, the workspace strip, and splits. Each piece keeps its index.
    function groupsOf(list: var): var {
        const out = []
        let chips = []
        const flush = () => {
            if (chips.length > 0)
                out.push({ kind: "chips", items: chips })
            chips = []
        }
        list.forEach((item, index) => {
            const piece = Object.assign({ index: index }, item)
            if (item.id === "split") {
                flush()
                out.push({ kind: "split", items: [piece] })
            } else if (item.id === "workspaces") {
                flush()
                out.push({ kind: "workspaces", items: [piece] })
            } else {
                chips.push(piece)
            }
        })
        flush()
        return out
    }

    function nameOf(id: string): string {
        if (id === "workspaces")
            return Tr.t("Workspaces")
        if (id === "split")
            return Tr.t("Split")
        if (ModuleService.isButton(id))
            return Tr.t(ModuleService.buttons[id].name)
        return Tr.t(ModuleService.entry(id).name)
    }

    // Every tile in the editor. Repeater delegates are children of their Row,
    // so the tree has to be walked.
    function tilesIn(item: var, out: var): var {
        for (const child of item.children) {
            if (child.isTile === true)
                out.push(child)
            else
                root.tilesIn(child, out)
        }
        return out
    }

    function tileAt(point: point): var {
        for (const tile of root.tilesIn(root, [])) {
            if (tile.isGap || !tile.visible || tile.ghost)
                continue
            const at = tile.mapFromItem(root, point.x, point.y)
            if (at.x >= 0 && at.y >= 0 && at.x < tile.width && at.y < tile.height)
                return tile
        }
        return null
    }

    function inside(item: var, point: point): bool {
        const at = item.mapFromItem(root, point.x, point.y)
        return at.x >= 0 && at.y >= 0 && at.x < item.width && at.y < item.height
    }

    // "left"/"right" by which half of the bar the pointer is over, "tray" for
    // the catalogue, or "".
    function sideAt(point: point): string {
        if (root.inside(stage, point))
            return scene.mapFromItem(root, point.x, point.y).x < scene.width / 2 ? "left" : "right"
        if (root.inside(tray, point))
            return "tray"
        return ""
    }

    // Insertion index: the tiles on that side whose centre is left of the
    // pointer.
    function indexIn(side: string, point: point): int {
        let count = 0
        for (const tile of root.tilesIn(scene, [])) {
            if (tile.side !== side || tile.isGap)
                continue
            if (tile.mapToItem(root, tile.width / 2, 0).x < point.x)
                count++
        }
        return count
    }

    function commit(): void {
        const left = root.leftItems.slice()
        const right = root.rightItems.slice()
        if (root.heldFrom === "left")
            left.splice(root.heldIndex, 1)
        if (root.heldFrom === "right")
            right.splice(root.heldIndex, 1)

        // Dropped outside: leave everything as it was.
        if (root.overSide === "")
            return
        // Catalogue to catalogue: nothing to do.
        if (root.heldFrom === "tray" && root.overSide === "tray")
            return

        if (root.overSide === "left")
            left.splice(root.overIndex, 0, root.heldItem)
        if (root.overSide === "right")
            right.splice(root.overIndex, 0, root.heldItem)

        SettingsService.setBarZone("left", left)
        SettingsService.setBarZone("right", right)
    }

    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        // ── THE BAR ─────────────────────────────────────────────────────────

        Rectangle {
            id: stage

            Layout.fillWidth: true
            implicitHeight: Theme.capsuleHeight + 2 * root.stagePad
            radius: Theme.radiusMedium
            color: Theme.islandSurface
            border.color: root.moved && (root.overSide === "left" || root.overSide === "right")
                ? Theme.accent : Theme.islandBorder
            border.width: 1
            clip: true

            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            // Highlights the half a carried piece would land in.
            Rectangle {
                x: root.overSide === "right" ? parent.width / 2 : 0
                width: parent.width / 2
                height: parent.height
                visible: root.moved && (root.overSide === "left" || root.overSide === "right")
                color: Theme.accent
                opacity: 0.06
            }

            // The bar at natural size, scaled down as a whole when it does not
            // fit.
            Item {
                id: scene

                readonly property real islandWidth: ModuleService.entry("clock").width
                readonly property real reach: Math.max(leftSide.implicitWidth, rightSide.implicitWidth)
                readonly property real half: scene.islandWidth / 2 + Theme.capsuleSpacing
                    + scene.reach + root.sceneMargin + (root.chromeless ? root.bandPad : 0)
                readonly property real natural: 2 * scene.half

                width: Math.max(stage.width, scene.natural)
                height: Theme.capsuleHeight
                x: (stage.width - scene.width) / 2
                y: root.stagePad
                scale: Math.min(1, stage.width / scene.natural)

                readonly property real middle: scene.width / 2

                // Single-capsule style: one band, sides at its ends.
                Rectangle {
                    visible: root.chromeless
                    readonly property real reach: scene.islandWidth / 2 + Theme.capsuleSpacing
                        + scene.reach + root.bandPad
                    x: scene.middle - reach
                    width: 2 * reach
                    height: Theme.capsuleHeight
                    radius: height / 2
                    color: Theme.island
                    border.color: Theme.islandBorder
                    border.width: 1
                }

                Side {
                    id: leftSide

                    side: "left"
                    x: {
                        if (root.barStyle === "spread")
                            return root.sceneMargin
                        if (root.chromeless)
                            return scene.middle - scene.islandWidth / 2 - Theme.capsuleSpacing
                                - scene.reach
                        return scene.middle - scene.islandWidth / 2 - Theme.capsuleSpacing
                            - leftSide.implicitWidth
                    }
                }

                // The island at rest, with the real time on it.
                Rectangle {
                    x: scene.middle - scene.islandWidth / 2
                    width: scene.islandWidth
                    height: Theme.capsuleHeight
                    radius: height / 2
                    color: Theme.island
                    border.color: Theme.islandBorder
                    border.width: root.chromeless ? 0 : 1

                    ClockModule {
                        anchors.fill: parent
                    }
                }

                Side {
                    id: rightSide

                    side: "right"
                    x: {
                        if (root.barStyle === "spread")
                            return scene.width - root.sceneMargin - rightSide.implicitWidth
                        if (root.chromeless)
                            return scene.middle + scene.islandWidth / 2 + Theme.capsuleSpacing
                                + scene.reach - rightSide.implicitWidth
                        return scene.middle + scene.islandWidth / 2 + Theme.capsuleSpacing
                    }
                }
            }
        }

        // ── THE PICKED PIECE ────────────────────────────────────────────────

        Rectangle {
            id: inspector

            Layout.fillWidth: true
            visible: root.picked !== null
            implicitHeight: card.implicitHeight + 28
            radius: Theme.radiusMedium
            color: Theme.island
            border.color: Theme.accent
            border.width: 1

            ColumnLayout {
                id: card

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: root.picked ? root.nameOf(root.picked.id) : ""
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    PillButton {
                        text: Tr.t("Remove")
                        implicitHeight: 26
                        onClicked: root.removePicked()
                    }

                    IconButton {
                        icon: "󰅖"
                        iconSize: 12
                        onClicked: root.unpick()
                    }
                }

                // Buttons, the strip and splits have no look to set.
                Text {
                    Layout.fillWidth: true
                    visible: !root.pickedModule
                    text: Tr.t("Nothing to set: it is drawn one way.")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                Flow {
                    Layout.fillWidth: true
                    visible: root.pickedModule
                    spacing: 24

                    Column {
                        spacing: 6

                        Text {
                            text: Tr.t("Shape")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            color: Theme.textMuted
                        }

                        // Shown but disabled for modules with no gauge to
                        // draw as a ring.
                        SegmentedControl {
                            readonly property bool ringable: root.picked !== null
                                && ModuleService.ringed.indexOf(root.picked.id) >= 0

                            enabled: ringable
                            opacity: ringable ? 1 : 0.55
                            options: [{ id: "", label: Tr.t("Like the bar") }].concat(
                                SettingsService.chipShapes.map(entry =>
                                    ({ id: entry.id, label: Tr.t(entry.label) })))
                            current: root.picked ? root.picked.shape : ""
                            onSelected: id => root.setLook({ shape: id })
                        }
                    }

                    Column {
                        spacing: 6

                        Text {
                            text: Tr.t("Figure")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            color: Theme.textMuted
                        }

                        SegmentedControl {
                            options: [{ id: "", label: Tr.t("Like the bar") }].concat(
                                SettingsService.chipFigures.map(entry =>
                                    ({ id: entry.id, label: Tr.t(entry.label) })))
                            current: root.picked ? root.picked.figure : ""
                            onSelected: id => root.setLook({ figure: id })
                        }
                    }

                    // Only for `ModuleService.runners`: on the bar always, or
                    // only while running.
                    Column {
                        spacing: 6
                        visible: root.picked !== null
                            && ModuleService.runners.indexOf(root.picked.id) >= 0

                        Text {
                            text: Tr.t("When")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            color: Theme.textMuted
                        }

                        SegmentedControl {
                            options: [{ id: "", label: Tr.t("Always") },
                                      { id: "running", label: Tr.t("While it runs") }]
                            current: root.picked ? root.picked.when : ""
                            onSelected: id => root.setLook({ when: id })
                        }
                    }
                }
            }
        }

        // ── THE CATALOGUE ───────────────────────────────────────────────────

        Rectangle {
            id: tray

            Layout.fillWidth: true
            implicitHeight: groups.implicitHeight + 16
            radius: Theme.radiusMedium
            color: Theme.islandSurface
            border.color: root.moved && root.overSide === "tray" && root.heldFrom !== "tray"
                ? Theme.accent : Theme.islandBorder
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            Column {
                id: groups

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 16

                Repeater {
                    model: root.catalogueGroups

                    Flow {
                        id: flow

                        required property var modelData
                        required property int index

                        // Index of this group's first piece in the flat
                        // catalogue list.
                        readonly property int offset: root.catalogueGroups
                            .slice(0, flow.index)
                            .reduce((count, group) => count + group.length, 0)

                        width: parent.width
                        spacing: root.street

                        Repeater {
                            model: flow.modelData

                            Entry {
                                required property string modelData
                                required property int index

                                entryId: modelData
                                place: flow.offset + index
                            }
                        }
                    }
                }
            }
        }
    }

    // `preventStealing`: the page is a Flickable, and a vertical drag down to
    // the catalogue would otherwise be taken as a scroll.
    MouseArea {
        anchors.fill: parent
        preventStealing: true
        cursorShape: root.held !== "" ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onPressed: mouse => {
            const hit = root.tileAt(Qt.point(mouse.x, mouse.y))
            if (!hit) {
                // Clicking the bar's background clears the pick.
                if (root.inside(stage, Qt.point(mouse.x, mouse.y)))
                    root.unpick()
                mouse.accepted = false
                return
            }
            root.held = hit.entryId
            root.heldItem = root.listOf(hit.side)[hit.place]
            root.heldFrom = hit.side
            root.heldIndex = hit.place
            root.pressedAt = Qt.point(mouse.x, mouse.y)
            root.pointer = root.pressedAt
            root.moved = false
            root.overSide = hit.side
            root.overIndex = hit.place
        }

        onPositionChanged: mouse => {
            if (root.held === "")
                return
            root.pointer = Qt.point(mouse.x, mouse.y)
            if (!root.moved && Math.hypot(mouse.x - root.pressedAt.x, mouse.y - root.pressedAt.y) < 5)
                return
            root.moved = true
            root.overSide = root.sideAt(root.pointer)
            root.overIndex = root.overSide === "left" || root.overSide === "right"
                ? root.indexIn(root.overSide, root.pointer) : -1
        }

        onReleased: {
            if (root.held === "")
                return
            if (root.moved) {
                root.unpick()
                root.commit()
            } else if (root.heldFrom === "tray") {
                SettingsService.setBarZone("right", root.rightItems.concat([root.heldItem]))
            } else {
                root.pick(root.heldFrom, root.heldIndex)
            }
            root.held = ""
            root.moved = false
            root.overSide = ""
        }

        onCanceled: {
            root.held = ""
            root.moved = false
            root.overSide = ""
        }
    }

    // The copy under the pointer. Its width also sizes the drop gap.
    Piece {
        id: carried

        ghost: true
        visible: root.held !== "" && root.moved
        x: root.pointer.x - carried.width / 2
        y: root.pointer.y - carried.height / 2
        entryId: root.held !== "" ? root.held : "split"
        ownShape: root.heldItem ? root.heldItem.shape : ""
        ownFigure: root.heldItem ? root.heldItem.figure : ""
        opacity: 0.92
        z: 10
    }

    // ── SIDE ────────────────────────────────────────────────────────────────

    component Side: Row {
        id: lane

        property string side: ""

        readonly property var groups: root.groupsOf(root.shown(lane.side))

        height: Theme.capsuleHeight
        spacing: root.chromeless ? 14 : Theme.capsuleSpacing

        // Drop target for an empty side.
        Rectangle {
            visible: lane.groups.length === 0
            width: 64
            height: Theme.capsuleHeight
            radius: height / 2
            color: "transparent"
            border.color: Theme.islandBorder
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: Tr.t("Empty")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }
        }

        Repeater {
            model: lane.groups

            Item {
                id: group

                required property var modelData

                readonly property string kind: group.modelData.kind
                readonly property var items: group.modelData.items
                readonly property var pieces: group.items.filter(item => item.id !== "__gap")
                readonly property bool alone: group.kind === "chips" && group.pieces.length === 1

                // A lone ring is its own outline, as in `BarZone`.
                readonly property bool bare: group.alone
                    && !ModuleService.isButton(group.pieces[0].id)
                    && ModuleService.shapeOf(group.pieces[0].id, group.pieces[0].shape) === "ring"
                    && ModuleService.figureOf(group.pieces[0].figure) !== "on"

                readonly property int pad: root.chromeless || group.alone ? 0 : 4

                width: group.kind === "chips" ? chips.implicitWidth + 2 * group.pad
                    : group.kind === "split" ? seam.width : (strip.item ? strip.item.width : 0)
                height: Theme.capsuleHeight

                Rectangle {
                    anchors.fill: parent
                    visible: group.kind === "chips"
                    radius: height / 2
                    color: root.chromeless ? "transparent" : Theme.island
                    border.color: Theme.islandBorder
                    border.width: root.chromeless || group.bare ? 0 : 1

                    Row {
                        id: chips

                        x: group.pad
                        height: Theme.capsuleHeight

                        Repeater {
                            model: group.kind === "chips" ? group.items : []

                            Chip {
                                required property var modelData

                                anchors.verticalCenter: parent.verticalCenter
                                entryId: modelData.id
                                ownShape: modelData.shape
                                ownFigure: modelData.figure
                                ownWhen: modelData.when ?? ""
                                place: modelData.index
                                side: lane.side
                                alone: group.alone
                            }
                        }
                    }
                }

                Seam {
                    id: seam

                    visible: group.kind === "split"
                    side: lane.side
                    place: group.kind === "split" ? group.items[0].index : -1
                }

                // The live workspace strip, built only where the layout has one.
                Loader {
                    id: strip

                    active: group.kind === "workspaces"
                    sourceComponent: Strip {
                        side: lane.side
                        place: group.items[0].index
                    }
                }
            }
        }
    }

    // ── PIECES ──────────────────────────────────────────────────────────────

    // A module or button, drawn exactly as the bar draws it. The drop gap is
    // also a Chip: empty, outlined in the accent.
    component Chip: Item {
        id: chip

        property string entryId: ""
        property string ownShape: ""
        property string ownFigure: ""
        property string ownWhen: ""
        property int place: -1
        property string side: ""
        property bool alone: false
        property bool ghost: false

        readonly property bool isTile: !chip.isGap
        readonly property bool isGap: chip.entryId === "__gap"
        readonly property bool button: ModuleService.isButton(chip.entryId)
        readonly property string figure: ModuleService.figureOf(chip.ownFigure)
        readonly property bool picked: !chip.ghost && root.pickedSide === chip.side
            && root.pickedIndex === chip.place

        // Figure reveal as on the bar, but frozen during a drag so widths do
        // not shift under the pointer.
        property real reveal: {
            if (chip.figure === "on")
                return 1
            if (chip.figure === "hover" && hover.hovered && root.held === "")
                return 1
            return 0
        }

        Behavior on reveal {
            NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic }
        }

        width: chip.isGap ? carried.width : chip.button ? Theme.capsuleHeight : face.implicitWidth
        height: Theme.capsuleHeight

        // Dimmed when the bar would not show it right now: unavailable on
        // this machine, or set to show only while running.
        opacity: chip.isGap || chip.button || ModuleService.shows(chip.entryId, chip.ownWhen)
            ? 1 : 0.45

        HoverHandler { id: hover }

        // Accent outline for the drop gap and the picked piece.
        Rectangle {
            anchors.fill: parent
            anchors.margins: chip.isGap ? 3 : 1
            visible: chip.isGap || chip.picked
            radius: height / 2
            color: chip.picked ? Theme.islandSurfaceHover : "transparent"
            border.color: Theme.accent
            border.width: 1
        }

        Text {
            anchors.centerIn: parent
            visible: chip.button
            text: chip.button ? ModuleService.buttons[chip.entryId].glyph : ""
            font.family: Theme.fontMono
            font.pixelSize: Math.round(Theme.capsuleHeight * 0.44)
            color: Theme.text
        }

        ChipFace {
            id: face

            visible: !chip.button && !chip.isGap
            moduleId: chip.button || chip.isGap ? "" : chip.entryId
            shape: ModuleService.shapeOf(chip.entryId, chip.ownShape)
            alone: chip.alone
            reveal: chip.reveal
        }
    }

    // A split between two capsules. Picked, moved and removed like any piece.
    component Seam: Item {
        id: seamTile

        property string side: ""
        property int place: -1
        property bool ghost: false

        readonly property bool isTile: visible
        readonly property bool isGap: false
        readonly property string entryId: "split"
        readonly property bool picked: !seamTile.ghost && root.pickedSide === seamTile.side
            && root.pickedIndex === seamTile.place

        width: 10
        height: Theme.capsuleHeight

        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: Math.round(Theme.capsuleHeight * 0.45)
            radius: 1
            color: seamTile.picked ? Theme.accent : Theme.textMuted
        }
    }

    // The live workspace strip.
    component Strip: Item {
        id: stripTile

        property string side: ""
        property int place: -1
        property bool ghost: false

        readonly property bool isTile: visible
        readonly property bool isGap: false
        readonly property string entryId: "workspaces"

        width: workspaces.implicitWidth
        height: Theme.capsuleHeight

        WorkspacesWidget {
            id: workspaces

            anchors.fill: parent
            chromeless: root.chromeless
        }

        Rectangle {
            anchors.fill: parent
            visible: !stripTile.ghost && root.pickedSide === stripTile.side
                && root.pickedIndex === stripTile.place
            radius: height / 2
            color: "transparent"
            border.color: Theme.accent
            border.width: 1
        }
    }

    // A standalone piece: the carried copy, and what sizes the drop gap.
    component Piece: Item {
        id: piece

        property string entryId: ""
        property string ownShape: ""
        property string ownFigure: ""
        property bool ghost: false

        readonly property bool module: piece.entryId !== "workspaces" && piece.entryId !== "split"

        width: piece.module ? lone.width
            : piece.entryId === "split" ? 10 : (pieceStrip.item ? pieceStrip.item.width : 0)
        height: Theme.capsuleHeight

        Rectangle {
            anchors.fill: parent
            visible: piece.module || piece.entryId === "split"
            radius: height / 2
            color: Theme.island
            border.color: Theme.accent
            border.width: 1
        }

        Chip {
            id: lone

            visible: piece.module
            ghost: true
            entryId: piece.module ? piece.entryId : ""
            ownShape: piece.ownShape
            ownFigure: piece.ownFigure
            alone: true
        }

        Seam {
            anchors.centerIn: parent
            visible: piece.entryId === "split"
            ghost: true
        }

        Loader {
            id: pieceStrip

            active: piece.entryId === "workspaces"
            sourceComponent: Strip {
                ghost: true
            }
        }
    }

    // A catalogue entry: the piece's mark in the bar's current shape, without
    // its figure, and its name.
    component Entry: Rectangle {
        id: entry

        property string entryId: ""
        property int place: -1

        readonly property bool isTile: true
        readonly property bool isGap: false
        readonly property bool ghost: false
        readonly property string side: "tray"
        readonly property bool moduled: entry.entryId !== "workspaces" && entry.entryId !== "split"
            && !ModuleService.isButton(entry.entryId)

        implicitWidth: content.implicitWidth + 16
        implicitHeight: root.tileHeight
        radius: height / 2
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1

        Row {
            id: content

            anchors.verticalCenter: parent.verticalCenter
            x: 4
            spacing: 2

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: entry.moduled ? mark.width
                    : ModuleService.isButton(entry.entryId) ? Theme.capsuleHeight : 0
                height: Theme.capsuleHeight

                ChipFace {
                    id: mark

                    visible: entry.moduled
                    moduleId: entry.moduled ? entry.entryId : ""
                    reveal: 0
                    width: entry.moduled ? implicitWidth : 0
                }

                // Buttons show their glyph.
                Text {
                    anchors.centerIn: parent
                    visible: ModuleService.isButton(entry.entryId)
                    text: visible ? ModuleService.buttons[entry.entryId].glyph : ""
                    font.family: Theme.fontMono
                    font.pixelSize: Math.round(Theme.capsuleHeight * 0.44)
                    color: Theme.text
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: entry.entryId === "workspaces"
                leftPadding: 6
                rightPadding: 6
                spacing: 4

                Repeater {
                    model: [false, true, false]

                    Rectangle {
                        required property bool modelData
                        width: modelData ? 14 : 5
                        height: 5
                        radius: 2.5
                        color: modelData ? Theme.accent : Theme.indicatorDim
                    }
                }
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                visible: entry.entryId === "split"
                width: 18
                height: 14

                Rectangle {
                    anchors.centerIn: parent
                    width: 2
                    height: 14
                    radius: 1
                    color: Theme.textMuted
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: 6
                text: root.nameOf(entry.entryId)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }
        }
    }
}
