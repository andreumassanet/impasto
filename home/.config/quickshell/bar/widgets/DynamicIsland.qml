// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D Y N A M I C   I S L A N D                                            │
// │   morphing centre capsule · hosts every island layer                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../island"
import "../modules"

// One capsule that changes shape to fit whatever it shows. IslandState picks
// the layer, this sizes the capsule for it, and a Loader swaps the contents;
// the shape animates while the contents cross-fade.
Rectangle {
    id: root

    // Settings is a separate window owned by `shell.qml`; the request is
    // passed up.
    signal settingsRequested()

    readonly property alias state: islandState
    readonly property bool expanded: islandState.expanded

    // The island is drawn on every screen; one of them is the one being
    // worked on (`Bar.live`) and the rest are this shape at rest. Only the
    // live one opens anything, and `IslandState` is where that is enforced.
    property bool active: true

    // While a note is open the island is the note: paper to the edge, with no
    // rim or padding.
    readonly property bool paper: islandState.openPanel === "notes" && NotesService.opened !== ""
    readonly property var paperNote: NotesService.entry(NotesService.opened)
    readonly property color paperColor: NotesService.paperOf(root.paperNote ? root.paperNote.tint : "yellow")
    // A module detail brings its own margins.
    readonly property int panelPad: root.paper
        ? 0 : (islandState.openPanel === "module" ? 4 : Theme.panelPadding)

    // For the bar: attached, the notch fillets have to light with the island.
    readonly property bool hovered: hover.hovered
    // Lit where a click does something: the clock at rest and the glance. Not
    // at rest in the one-capsule style, where the band and the island are one
    // shape and cannot light separately; not over panels, which have their
    // own controls; and not while `landing` from one.
    readonly property bool lit: hover.hovered && !root.landing
        && ((islandState.layer === islandState.layerModules && !root.hosted)
            || islandState.layer === islandState.layerSummary)
    readonly property color surfaceColor: root.lit
        ? Theme.islandSurfaceHover
        : (SettingsService.islandAttached ? Theme.island : Theme.islandSurface)

    // ── HOSTED ──────────────────────────────────────────────────────────────
    //
    // In the one-capsule style the bar draws a band behind the island and puts
    // the sides on it. This flag only changes what the island paints at rest;
    // once it shows more than the clock, the band morphs into it
    // (`Bar.islandTaken`).
    property bool hosted: false

    // Width left between the bar's ends (`Bar.panelRoom`). Unconstrained by
    // default, so an island without a bar gets the size it asks for.
    property int roomForPanel: 100000

    readonly property int overviewRows: Math.ceil(SettingsService.workspaceMax / 5)

    // ── PANEL SIZES ─────────────────────────────────────────────────────────
    //
    // Declared rather than measured: the island has to reach its final shape
    // before the panel inside it is loaded.
    readonly property var panelSizes: ({
        controls:   { width: ControlsService.panelWidth, height: ControlsService.panelHeight },
        appearance: root.appearanceSize,
        palette:    root.appearanceSize,
        stats:      { width: 940,  height: 614 },
        // Depends on the results when `launcherFits` is on.
        launcher:   { width: LauncherService.panelWidth,
                      height: LauncherService.panelHeight },
        wifi:       { width: 420,  height: 500 },
        bluetooth:  { width: 420,  height: 500 },
        session:    { width: 720,  height: 180 },
        // A row per creature, plus one for the next egg.
        pet:        { width: 560,  height: 205 + 62 * PetService.family.length },
        // The shelf of cards, or the game being played at its own size.
        games:      GamesService.playing !== ""
            ? GamesService.panelSize(GamesService.playing)
            : { width: GamesService.shelfWidth, height: GamesService.shelfHeight },
        // Declared by their services, which the panels read back for layout.
        notes:      { width: NotesService.panelWidth, height: NotesService.panelHeight },
        board:      { width: TasksService.panelWidth, height: TasksService.panelHeight },
        // The key sheet's columns come from the compositor's bind list.
        keys:       { width: ShortcutService.sheetWidth, height: ShortcutService.sheetHeight },
        packages:   { width: PackagesService.panelWidth, height: PackagesService.panelHeight },
        module:     root.moduleSize,
        overview:   { width: 1560, height: 72 + root.overviewRows * 190 }
    })

    // One panel under two names (its two strips), so switching between them
    // slides instead of rebuilding. Fits five strip tiles and the large one.
    readonly property var appearanceSize: ({ width: 940, height: 196 })

    // A module's detail, sized from the catalogue.
    readonly property var moduleSize: ModuleService.openSize(ModuleService.openId)

    readonly property var panelSize:
        root.panelSizes[islandState.openPanel] ?? root.panelSizes.controls

    // Only the overview is ever wide enough to hit the limit.
    readonly property int panelWidth: Math.min(root.panelSize.width, root.roomForPanel)
    readonly property int panelHeight: root.panelSize.height

    // One entry per layer: the capsule's size and the padding inside it.
    readonly property var layerSizes: ({
        modules:      { width: ModuleService.restWidth, height: Theme.capsuleHeight, padding: 0 },
        summary:      { width: ModuleService.summaryWidth,
                        height: ModuleService.summaryHeight,
                        padding: 0 },
        osd:          { width: 260, height: Theme.capsuleHeight, padding: 10 },
        notification: { width: 430, height: 68,                  padding: 13 },
        panel:        { width: root.panelWidth, height: root.panelHeight, padding: Theme.panelPadding }
    })

    readonly property var size: root.layerSizes[islandState.layer] ?? root.layerSizes.modules

    // Off for the first frame so the island does not animate in from nothing
    // at startup.
    property bool animated: false

    // Attached, only the shape reaches up to the screen edge; the contents keep
    // their padding, so nothing already drawn moves.
    readonly property int notchPad: SettingsService.islandAttached ? Theme.barTopMargin : 0

    readonly property var layerComponents: ({
        modules: restLayer,
        summary: summaryLayer,
        osd: osdLayer,
        notification: notificationLayer
    })

    readonly property var panelComponents: ({
        controls: controlsPanel,
        appearance: appearancePanel,
        palette: appearancePanel,
        launcher: launcherPanel,
        wifi: networkDetail,
        bluetooth: bluetoothDetail,
        stats: statsPanel,
        overview: overviewPanel,
        session: sessionPanel,
        pet: petPanel,
        games: gamesPanel,
        notes: notesPanel,
        board: boardPanel,
        keys: keysPanel,
        packages: packagesPanel,
        module: moduleDetail
    })

    function open(panel: string): void {
        islandState.open(panel)
    }

    function close(): void {
        islandState.close()
    }

    // Shortcuts toggle: the same key opens and closes.
    function toggle(panel: string): void {
        if (islandState.openPanel === panel)
            root.close()
        else
            root.open(panel)
    }

    IslandState {
        id: islandState

        active: root.active
    }

    // ── GLANCE ──────────────────────────────────────────────────────────────
    //
    // Hovering opens the summary after a short intent delay, leaving closes it
    // after a grace period, and a click opens the control centre. 80 ms is
    // under a perceptible wait but longer than a moving pointer spends
    // crossing the clock; the grace period stops a pointer on the edge from
    // flapping it open and shut.
    //
    // Re-entering cancels the close. A click holds the glance off until the
    // pointer leaves, so a just-dismissed panel is not replaced by the summary.
    // A HoverHandler rather than the MouseArea because it stays hovered over
    // the sides' own click targets.
    HoverHandler {
        id: hover
    }

    property bool summaryHeld: false

    readonly property bool restBusy: islandState.layer === islandState.layerModules
        && (collapsedLoader.item?.busy ?? false)

    readonly property bool canSummarise: SettingsService.islandSummary
        && root.active
        && !root.summaryHeld
        && !root.landing
        && ModuleService.openId === ""
        && (islandState.layer === islandState.layerModules
            || islandState.layer === islandState.layerSummary)

    onCanSummariseChanged: {
        if (!root.canSummarise)
            islandState.summary = false
    }

    onRestBusyChanged: {
        if (root.restBusy)
            dwell.stop()
        else if (hover.hovered && !islandState.summary)
            dwell.restart()
    }

    Timer {
        id: dwell
        interval: 80
        onTriggered: {
            if (hover.hovered && root.canSummarise && !root.restBusy)
                islandState.summary = true
        }
    }

    // Set while the island shrinks back to rest from a panel, detail,
    // notification or OSD: opening the glance mid-morph would turn the shape
    // round halfway. The glance's own close is not a landing, since re-entering
    // should reverse it.
    property bool landing: false
    property string lastLayer: islandState.layerModules

    Connections {
        target: islandState

        function onLayerChanged(): void {
            if (islandState.layer === islandState.layerModules
                    && root.lastLayer !== islandState.layerSummary
                    && root.lastLayer !== islandState.layerModules) {
                root.landing = true
                Qt.callLater(root.checkLanded)
            }
            root.lastLayer = islandState.layer
        }
    }

    onSettledChanged: root.checkLanded()

    // Also called deferred: with motion off `settled` never changes, and the
    // glance would stay blocked.
    function checkLanded(): void {
        if (!root.landing || !root.settled || islandState.layer !== islandState.layerModules)
            return
        root.landing = false
        if (hover.hovered && !islandState.summary)
            dwell.restart()
    }

    Timer {
        id: grace
        interval: 260
        onTriggered: {
            if (!hover.hovered)
                islandState.summary = false
        }
    }

    Connections {
        target: hover

        function onHoveredChanged(): void {
            if (hover.hovered) {
                grace.stop()
                if (!islandState.summary)
                    dwell.restart()
            } else {
                dwell.stop()
                grace.restart()
                root.summaryHeld = false
            }
        }
    }

    width: root.size.width
    height: root.size.height + root.notchPad

    // True once the morph has reached its target size.
    readonly property bool settled: root.width === root.size.width
        && root.height === root.size.height + root.notchPad
    // A pill at capsule height, a rounded card once a module makes it taller.
    radius: islandState.expanded && islandState.openPanel !== "module"
        ? Theme.radiusLarge
        : Math.min(root.height / 2, Theme.radiusLarge + 4)

    color: islandState.expanded
        ? (root.paper ? root.paperColor : Theme.island)
        : root.surfaceColor
    border.color: Theme.islandBorder

    // No hairline in the one-capsule style: at rest the island's edges run
    // through the band's interior, and while growing the band is the outer
    // edge. `Bar.qml` draws the outline over both.
    readonly property bool inBand: root.hosted
    border.width: root.paper || root.inBand ? 0 : 1
    clip: true

    // Attached, the upper corners go square: the curve is added outside the
    // island by NotchFillet, flaring away from it rather than cutting into it.
    topLeftRadius: SettingsService.islandAttached ? 0 : root.radius
    topRightRadius: SettingsService.islandAttached ? 0 : root.radius

    Behavior on topLeftRadius {
        enabled: root.animated
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }
    Behavior on topRightRadius {
        enabled: root.animated
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Component.onCompleted: root.animated = true

    // One animated value per axis; everything the bar draws around the island
    // (band, sides, fillets) is derived from it. None of those gets its own
    // Behavior: animating a sum whose other term changes every frame restarts
    // on every change and settles late.
    Behavior on width {
        enabled: root.animated
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }
    Behavior on height {
        enabled: root.animated
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }
    Behavior on radius {
        enabled: root.animated
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    // ── COLLAPSED ───────────────────────────────────────────────────────────

    // An Item, not a second rounded rectangle, so the hover light and the
    // click target cover the whole island.
    Item {
        id: capsule

        anchors.fill: parent
        opacity: islandState.expanded ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            enabled: root.animated
            NumberAnimation { duration: 110; easing.type: Theme.easing }
        }

        // Declared before the layer so the layer's own controls (the media
        // play button) get clicks first; this still gets hover and the rest.
        MouseArea {
            id: capsuleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.summaryHeld = true
                root.open("controls")
            }
        }

        Item {
            id: middle

            anchors.fill: parent

            // Fades each new layer in.
            Loader {
                id: collapsedLoader

                anchors.fill: parent
                // Attached, the contents are centred in the full height,
                // matching the bar's raised midline (`Bar.laneY`).
                anchors.topMargin: root.size.padding + root.notchPad / 2
                anchors.leftMargin: root.size.padding
                anchors.rightMargin: root.size.padding
                anchors.bottomMargin: root.size.padding + root.notchPad / 2
                sourceComponent: root.layerComponents[islandState.layer] ?? restLayer

                onSourceComponentChanged: fade.restart()

                NumberAnimation {
                    id: fade
                    target: collapsedLoader
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.durationFast
                    easing.type: Theme.easing
                }
            }
        }
    }

    // ── EXPANDED ────────────────────────────────────────────────────────────

    // A FocusScope, so one Escape handler covers every panel. A plain Item
    // holding focus here would take it from the launcher's search field; a
    // scope delegates inward, so the field keeps the keyboard and unhandled
    // keys bubble up here. Nothing inside sets `focus: true` for the same
    // reason: on the Loader it takes focus from the field a frame after the
    // field asks for it.
    FocusScope {
        id: panelScope

        anchors.fill: parent
        focus: islandState.expanded

        Keys.onEscapePressed: root.close()

        Loader {
            id: panelLoader

            anchors.fill: parent
            anchors.topMargin: root.panelPad + root.notchPad
            anchors.leftMargin: root.panelPad
            anchors.rightMargin: root.panelPad
            anchors.bottomMargin: root.panelPad
            active: islandState.expanded
            sourceComponent: root.panelComponents[islandState.openPanel] ?? controlsPanel
            opacity: islandState.expanded ? 1 : 0

            Behavior on opacity {
                enabled: root.animated
                NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
            }
        }
    }

    // Swallows clicks on the panel background so they do not reach the
    // dismiss area covering the rest of the bar.
    MouseArea {
        anchors.fill: parent
        enabled: islandState.expanded
        acceptedButtons: Qt.AllButtons
        z: -1
    }

    // ── LAYERS ──────────────────────────────────────────────────────────────

    Component {
        id: restLayer
        IslandRest {}
    }

    Component {
        id: summaryLayer
        IslandSummary {}
    }

    Component {
        id: moduleDetail
        DetailFace {
            moduleId: ModuleService.openId
            onClosed: root.close()
        }
    }

    Component {
        id: notificationLayer
        NotificationLayer {}
    }

    Component {
        id: osdLayer
        OsdLayer {
            icon: islandState.transientIcon
            label: islandState.transientLabel
            progress: islandState.transientProgress
        }
    }

    Component {
        id: controlsPanel
        ControlsPanel {
            onClosed: root.close()
            onPanelRequested: panel => root.open(panel)
            // Settings is a window, not a panel: close the island, then pass
            // the request up.
            onSettingsRequested: {
                root.close()
                root.settingsRequested()
            }
        }
    }

    Component {
        id: appearancePanel
        AppearancePanel {
            page: islandState.openPanel === "palette" ? "palette" : "wallpaper"
            onClosed: root.close()
            // Up and Down switch strips by panel name, so `page` follows
            // `openPanel`.
            onPanelRequested: panel => root.open(panel)
        }
    }

    Component {
        id: launcherPanel
        LauncherPanel {
            onClosed: root.close()
            // `>` lists every panel, so the launcher hands the island over the
            // same way the control centre does.
            onPanelRequested: panel => root.open(panel)
            onSettingsRequested: {
                root.close()
                root.settingsRequested()
            }
        }
    }

    // Wi-Fi and Bluetooth are panels of their own rather than views inside the
    // control centre, because a panel's size is keyed on `openPanel`.
    Component {
        id: networkDetail
        NetworkDetail { onBack: root.open("controls") }
    }

    Component {
        id: bluetoothDetail
        BluetoothDetail { onBack: root.open("controls") }
    }

    Component {
        id: statsPanel
        StatsPanel { onClosed: root.close() }
    }

    Component {
        id: overviewPanel
        OverviewPanel { onClosed: root.close() }
    }

    Component {
        id: sessionPanel
        SessionPanel { onClosed: root.close() }
    }

    Component {
        id: petPanel
        PetPanel { onClosed: root.close() }
    }

    Component {
        id: gamesPanel
        GamesPanel { onClosed: root.close() }
    }

    Component {
        id: notesPanel
        NotesPanel { onClosed: root.close() }
    }

    Component {
        id: boardPanel
        BoardPanel { onClosed: root.close() }
    }

    Component {
        id: keysPanel
        KeysPanel { onClosed: root.close() }
    }

    Component {
        id: packagesPanel
        PackagesPanel { onClosed: root.close() }
    }

    // A module asking for a panel: the arcade's detail opening the arcade.
    Connections {
        target: ModuleService

        function onPanelRequested(panel: string): void {
            root.open(panel)
        }
    }
}
