// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T H E M E                                                              │
// │   design tokens · consumed by every component                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick

import "../services"

// Design tokens for the whole shell. Components read Theme.<token> and never
// hardcode a colour, so a palette change repaints everything.
QtObject {
    id: root

    // ── ACTIVE THEME ────────────────────────────────────────────────────────

    property string activeId: "adaptive"
    property string activeName: "Adaptive (Wallpaper)"

    // ── ISLAND ──────────────────────────────────────────────────────────────

    // Pure black in every palette: the island is the shell's identity, not a
    // themed surface. What changes is how much of it there is
    // (`SettingsService.surfaceStyle`): solid, or glass — the terminal's own
    // ground, the accent scaled towards black at kitty's opacity, over the
    // compositor's blur, with a lit edge. `island` stays opaque for what is
    // cut out of it; the island, the capsules and the toasts are painted in
    // `islandGround`, and what sits on them in white washes.
    readonly property string surfaceStyle: SettingsService.surfaceStyle
    readonly property bool solid: root.surfaceStyle !== "glass"
    readonly property bool glass: root.surfaceStyle === "glass"

    readonly property color island: "#000000"
    readonly property color islandGround: root.groundOf(root.surfaceStyle)

    // The terminal's ground: `TERMINAL_TINT` and kitty's `background_opacity`.
    readonly property real terminalTint: 0.22
    readonly property real terminalOpacity: 0.90
    readonly property color terminalGround: Qt.rgba(root.accent.r * root.terminalTint,
        root.accent.g * root.terminalTint, root.accent.b * root.terminalTint, root.terminalOpacity)

    // Any style's ground and rim, for a picture of one that is not chosen.
    function groundOf(style: string): color {
        return style === "glass" ? root.terminalGround : root.island
    }

    function rimOf(style: string): color {
        return style === "glass" ? Qt.rgba(1, 1, 1, 0.20) : "#262626"
    }
    readonly property color islandSurface: "#141414"
    readonly property color islandSurfaceHover: "#1f1f1f"
    readonly property color islandBorder: "#262626"

    // The desk's widgets have a ground of their own, or the bar's
    // (`SettingsService.desktopGround`, empty to follow).
    readonly property string deskStyle: SettingsService.desktopGround || root.surfaceStyle
    readonly property bool deskSolid: root.deskStyle !== "glass"
    readonly property bool deskGlass: root.deskStyle === "glass"

    // The dock's, the same way (`SettingsService.dockGround`).
    readonly property string dockStyle: SettingsService.dockGround || root.surfaceStyle
    readonly property bool dockSolid: root.dockStyle !== "glass"
    readonly property bool dockGlass: root.dockStyle === "glass"

    // The same three on glass: white veils, by style. Only the bar's and the
    // desk's windows are glass, each in its own style (a `glassy` window
    // with a `groundStyle`), and the dock, which asks `dockStyle` directly;
    // everything else — the settings, the lock — stays black, so a part
    // drawn in both asks by its window (`surfaceIn`).
    function veilOf(style: string): color {
        return style === "glass" ? Qt.rgba(1, 1, 1, 0.08) : root.islandSurface
    }

    function veilHoverOf(style: string): color {
        return style === "glass" ? Qt.rgba(1, 1, 1, 0.14) : root.islandSurfaceHover
    }

    function veilLineOf(style: string): color {
        return style === "glass" ? Qt.rgba(1, 1, 1, 0.12) : root.islandBorder
    }

    function styleIn(window: var): string {
        return !!window && window.glassy === true ? (window.groundStyle ?? root.surfaceStyle) : "classic"
    }

    function surfaceIn(window: var): color {
        return root.veilOf(root.styleIn(window))
    }

    function surfaceHoverIn(window: var): color {
        return root.veilHoverOf(root.styleIn(window))
    }

    function borderIn(window: var): color {
        return root.veilLineOf(root.styleIn(window))
    }
    // The outline of the island, the capsules and the desk's widgets: the
    // hairline on solid, a line of light on glass.
    readonly property color islandRim: root.rimOf(root.surfaceStyle)
    // A see-through ground under the pointer: the same glass, a little lit.
    readonly property color islandGroundLit: Qt.tint(root.islandGround, Qt.rgba(1, 1, 1, 0.10))
    // Under the bar's icons when its sides are on the wallpaper.
    readonly property color barShadow: "#000000"
    readonly property int barShadowReach: 8
    // An empty workspace there: white held back, not the dim grey made for
    // a black ground.
    readonly property color barInkDim: Qt.rgba(1, 1, 1, 0.72)
    // The glass style's thick edge (`GlassSheen`): light caught inside the
    // rim, and falling from the top edge.
    readonly property real glassEdge: 0.12
    readonly property color glassSheen: Qt.rgba(1, 1, 1, 0.10)
    // How far down a shape that light reaches, in pixels, so a short pane and
    // a tall one are lit alike; a shape shorter than this keeps some at its
    // foot.
    readonly property int glassSheenDepth: 48

    // ── SEMANTIC COLOURS ────────────────────────────────────────────────────

    property color background: "#0c0c0c"
    property color surface: "#141414"
    property color surfaceHover: "#202020"
    property color border: "#282828"
    property color text: "#ffffff"
    property color textMuted: "#8e8e93"
    property color accent: "#0a84ff"
    property color accentHover: "#409cff"
    property color accentText: "#ffffff"

    property color red: "#ff453a"
    property color green: "#32d74b"
    property color yellow: "#ffd60a"
    property color blue: "#0a84ff"

    // Status indicators are fixed: a wallpaper-derived accent must not change
    // what a battery ring means.
    readonly property color indicator: "#ffffff"
    readonly property color indicatorDim: "#4d4d4d"
    readonly property color indicatorGood: "#32d74b"
    readonly property color indicatorWarn: "#ffd60a"
    readonly property color indicatorBad: "#ff453a"
    readonly property color indicatorTimer: "#64d2ff"

    // What is being watched or listened to, in a phone's colours for the
    // same thing: the microphone orange, the camera green, the screen blue.
    // Fixed, as warnings are.
    readonly property color privacyMicrophone: "#ff9f0a"
    readonly property color privacyCamera: root.indicatorGood
    readonly property color privacyScreen: "#0a84ff"

    // One coat per pet species. Fixed, so a pet looks the same on every
    // wallpaper and palette.
    readonly property color petDot: "#cba6f7"
    readonly property color petSprout: "#a6e3a1"
    readonly property color petEmber: "#f38ba8"
    readonly property color petSol: "#f9e2af"
    readonly property color petDrift: "#89b4fa"

    // Ground and ink over photographs. Fixed, since the ground is always dark.
    readonly property color scrim: "#bf000000"
    // Not `onScrim`: QML parses "on" + capital as a signal handler.
    readonly property color scrimText: "#ffffff"
    readonly property color hairline: "#20ffffff"

    // Sticky-note paper: a palette tint washed towards white, with ink that
    // stays dark in every palette.
    readonly property color paperWash: "#c4ffffff"
    readonly property color paperInk: "#1c1c1e"
    readonly property color paperInkMuted: "#8a1c1c1e"
    readonly property color paperLine: "#261c1c1e"
    readonly property int paperRadius: 10

    // Sticker widgets: a die-cut edge of vinyl white, fixed like the island's
    // black, around a palette hue washed towards it; what is printed on one
    // is the same hue darkened. The edge is a share of the sticker's short
    // side, the lean a sticker's largest tilt in degrees.
    readonly property color stickerPaper: "#fbf7ee"
    readonly property real stickerWash: 0.45
    readonly property real stickerDeep: 0.62
    readonly property real stickerEdge: 0.028
    readonly property real stickerLean: 5

    // Contribution graph, empty to busiest. GitHub's dark ramp, fixed across
    // palettes; the empty step is lifted off black so it reads as a cell.
    readonly property var githubLevels: [
        "#26292e", "#0e4429", "#006d32", "#26a641", "#39d353"
    ]

    readonly property int paletteTransition: 260

    Behavior on background   { ColorAnimation { duration: root.paletteTransition } }
    Behavior on surface      { ColorAnimation { duration: root.paletteTransition } }
    Behavior on surfaceHover { ColorAnimation { duration: root.paletteTransition } }
    Behavior on border       { ColorAnimation { duration: root.paletteTransition } }
    Behavior on text         { ColorAnimation { duration: root.paletteTransition } }
    Behavior on textMuted    { ColorAnimation { duration: root.paletteTransition } }
    Behavior on accent       { ColorAnimation { duration: root.paletteTransition } }
    Behavior on accentHover  { ColorAnimation { duration: root.paletteTransition } }
    Behavior on accentText   { ColorAnimation { duration: root.paletteTransition } }

    // ── METRICS ─────────────────────────────────────────────────────────────

    // The bar's scale. Ring chips, the resting island and the one-capsule
    // band are all one capsule tall.
    readonly property int capsuleHeight: SettingsService.barHeight
    readonly property int barTopMargin: SettingsService.barMargin
    readonly property int capsuleSpacing: 8

    // Exclusive zone: exactly what the bar paints. Hyprland adds `gaps_out`
    // below it, so reserving more leaves a larger top gap than on the other
    // edges.
    readonly property int barReserve: root.barTopMargin + root.capsuleHeight

    // Where the bar's input region ends: 8 px of slack under the capsules.
    readonly property int barBand: root.barReserve + 8

    // ── DESKTOP GRID ────────────────────────────────────────────────────────
    //
    // Widgets span whole cells. The gutter matches Hyprland's `gaps_out`.
    // A square is at least `desktopCell` and grows up to `desktopCellLargest`
    // so the board's margin is the same on all four sides
    // (`DesktopService.gridFor`). At the least, a 4 × 2 widget is 398 × 190,
    // which fits a two-row module card with one gutter around it; a larger
    // detail needs a larger cell.
    readonly property int desktopCell: 86
    readonly property int desktopCellLargest: 108
    readonly property int desktopGutter: 18
    readonly property int desktopStride: root.desktopCell + root.desktopGutter

    // ── CONTROL CENTRE GRID ─────────────────────────────────────────────────
    //
    // Up to 6 × 8 cells (`ControlsService.columns`, `rows`); one cell is one
    // toggle tile, and blocks span whole cells. A round button in the session
    // and shortcut blocks, and the gap between two: six across two cells.
    readonly property int centreColumns: 6
    readonly property int centreRows: 8
    readonly property int centreButton: 42
    readonly property int centreButtonGap: 8
    readonly property int centreCellWidth: 140
    readonly property int centreCellHeight: 64
    readonly property int centreGutter: 12
    readonly property int centreStrideX: root.centreCellWidth + root.centreGutter
    readonly property int centreStrideY: root.centreCellHeight + root.centreGutter

    // The pager strip (dots and chevrons) along the bottom of a paged block.
    readonly property int centrePagerLane: 18

    readonly property int panelPadding: 20

    // A page the control centre opens into (sound): its heading, a
    // section's title, a row (a level or a choice), the gap between rows and
    // between sections, and the column every row's name takes, so every bar
    // on a page starts at the same place.
    readonly property int detailHeader: 38
    readonly property int detailTitle: 24
    readonly property int detailRow: 36
    readonly property int detailRowGap: 4
    readonly property int detailGap: 14
    readonly property int detailLabel: 128

    // The height of a titled section of `rows` rows, with its gap above.
    function detailSection(rows: int): int {
        return root.detailGap + root.detailTitle
            + rows * root.detailRow + Math.max(0, rows - 1) * root.detailRowGap
    }

    // ── MODULE CARDS ────────────────────────────────────────────────────────
    //
    // A module's detail (`ModuleCard`): the island's rim around it, its own
    // padding, a heading on a mark, then rows of one height — a limit, a fact,
    // a level or a choice — so every card has the same margins and one card
    // can be sized from its count of rows before it is built.
    readonly property int cardInset: 4
    readonly property int cardPadding: 16
    readonly property int cardMark: 44
    readonly property int cardGap: 14
    readonly property int cardRow: 22
    readonly property int cardRowGap: 8
    readonly property int cardLabel: 84
    readonly property int cardWidth: 380
    // The one figure a heading may carry on its right.
    readonly property int cardFigure: 24

    // The height of a card with `rows` rows under its heading, and `extra`
    // pixels of anything taller than a row.
    function cardHeight(rows: int, extra: int): int {
        const body = rows * root.cardRow + Math.max(0, rows - 1) * root.cardRowGap + (extra ?? 0)
        return 2 * (root.cardInset + root.cardPadding) + root.cardMark
            + (body > 0 ? root.cardGap + body : 0)
    }

    // ── DOCK ────────────────────────────────────────────────────────────────
    //
    // Everything scales off the icon size. The margin matches `gaps_out`.
    readonly property int dockIcon: SettingsService.dockIconSize
    readonly property int dockPadding: 11
    readonly property int dockGap: root.capsuleSpacing
    readonly property int dockMargin: root.desktopGutter

    // The icons are centred across the dock; the running dot sits in the
    // padding on the screen-edge side. An icon is drawn `dockInset` inside its
    // square, so the dot clears both it and the rim.
    readonly property int dockDot: 4
    readonly property int dockInset: 2
    readonly property int dockThickness: root.dockIcon + 2 * root.dockPadding

    // Screen-edge strip a hidden dock still listens on.
    readonly property int dockReveal: 4

    // Fixed width so a long window title does not stretch the menu.
    readonly property int dockMenuWidth: 250
    readonly property int dockMenuRow: 30
    readonly property int dockMenuPadding: 6

    readonly property int dockRadius: root.desktopRadius

    // Hover scale. Small enough that neighbours never move, which keeps the
    // input region computable.
    readonly property real dockLift: 1.125

    // Matches Hyprland's `rounding`: widgets sit among windows.
    readonly property int desktopRadius: 22

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18
    readonly property int radiusPill: 999

    // Corner radius for pictures, as a fraction of the box. They range from
    // 20 px to 58 px, and no fixed radius looks right at both ends.
    readonly property real pictureCorner: 0.24

    // Where the notch meets the screen edge.
    readonly property int radiusNotch: 6

    // ── FIXED COLOURS ───────────────────────────────────────────────────────
    //
    // For what can be told to keep one colour whatever the palette does (the
    // cursor, the sound bars); "palette" beside them is the accent.
    readonly property var fixedColours: [
        { id: "#000000", label: "Black" },
        { id: "#ffffff", label: "White" },
        { id: "#e5484d", label: "Red" },
        { id: "#f76b15", label: "Orange" },
        { id: "#f5c518", label: "Yellow" },
        { id: "#46a758", label: "Green" },
        { id: "#3b82f6", label: "Blue" },
        { id: "#8b5cf6", label: "Purple" },
        { id: "#e93d82", label: "Pink" }
    ]

    // ── SPECTRUM ────────────────────────────────────────────────────────────
    //
    // Sound bars along a screen edge, as they are placed: a bar
    // `spectrumBar` wide with `spectrumGap` between, reaching `spectrumReach`
    // in from the edge at full level and `spectrumFloor` in silence. Each strip
    // can change the three. Solid at the edge, fading to `spectrumTip` at the
    // end.
    readonly property int spectrumBar: 10
    readonly property int spectrumGap: 6
    readonly property int spectrumReach: 170
    readonly property int spectrumFloor: 3
    readonly property real spectrumBase: 0.95
    readonly property real spectrumTip: 0.25

    // cava reports linear amplitude; a fractional power keeps quiet passages
    // visible.
    readonly property real spectrumCurve: 0.55

    // ── SHADOW ──────────────────────────────────────────────────────────────
    //
    // Shared by Hyprland's `decoration:shadow` (CompositorService) and the
    // bar's own capsule shadow, so both sit at the same height. Only drawn
    // when the setting is on.
    readonly property int shadowRange: 14
    readonly property real shadowOpacity: 0.5
    readonly property color shadowColor: "#000000"

    // Bar only. A Gaussian is at half strength on the edge of its source
    // shape, while Hyprland's shadow is at full strength against the window;
    // blurring a slightly grown copy moves the half-way point outside the
    // capsule.
    readonly property int shadowSpread: 4

    // The bar's capsules are small and have open wallpaper on every side, so
    // the same reach reads much heavier. Scale the reach, keep the darkness.
    readonly property real shadowBarScale: 0.6
    readonly property int shadowBarRange: Math.round(root.shadowRange * root.shadowBarScale)
    readonly property int shadowBarSpread: Math.round(root.shadowSpread * root.shadowBarScale)

    // ── TYPOGRAPHY ──────────────────────────────────────────────────────────

    // Qt matches one family and never a list: a comma-separated stack names
    // no installed font, and fontconfig's default sans is drawn instead. Both
    // settings hold a stack, so Qt is handed the first family in it that
    // exists, or the generic name at the end when none of them do.
    readonly property var installedFonts: Qt.fontFamilies()

    function fontOf(stack: string): string {
        const names = stack.split(",")
        for (const name of names) {
            const family = name.trim()
            if (family !== "" && root.installedFonts.indexOf(family) !== -1)
                return family
        }
        return names[names.length - 1].trim()
    }

    readonly property string fontFamily: root.fontOf(SettingsService.fontFamily)
    readonly property string fontMono: root.fontOf(SettingsService.fontMono)

    // Type drawn very large: Inter's display cut, tighter and finer at that
    // size, when the family is Inter; any other family as it is.
    readonly property string fontDisplay: root.fontFamily === "Inter"
        ? root.fontOf("Inter Display, Inter") : root.fontFamily

    // Script face for the shell's own name, shipped with it.
    readonly property string fontSignature:
        root.fontOf(`Grape Nuts, Georgia, ${root.fontFamily}`)

    // Note bodies: handwriting unless switched off.
    readonly property string fontHand: SettingsService.notesHandwriting
        ? root.fontSignature : root.fontFamily

    readonly property int fontSizeLabel: 10
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeRegular: 13
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeLarge: 16

    // Desktop widgets are read from further away. `fontSizeDisplay` is for
    // faces that are a single number (the large clocks).
    readonly property int fontSizeWidget: 30
    readonly property int fontSizeDisplay: 68

    // ── MOTION ──────────────────────────────────────────────────────────────

    // Game mode stills the shell whatever the pace says: nothing morphs and
    // nothing loops while it is on.
    readonly property real motion: SettingsService.gameMode ? 0 : SettingsService.motionScale / 100
    readonly property bool lively: !SettingsService.gameMode

    readonly property var easingCurves: [
        { id: "OutCubic", label: "Smooth",  type: Easing.OutCubic },
        { id: "OutQuint", label: "Snappy",  type: Easing.OutQuint },
        { id: "OutBack",  label: "Springy", type: Easing.OutBack },
        { id: "Linear",   label: "Flat",    type: Easing.Linear }
    ]

    readonly property int easing: {
        const curve = root.easingCurves.find(entry => entry.id === SettingsService.motionCurve)
        return curve ? curve.type : Easing.OutCubic
    }

    // A preset writes `motionScale` and `motionCurve` together; there is no
    // stored preset key.
    readonly property var motionPresets: [
        { id: "smooth",  label: "Smooth",  scale: 100, curve: "OutCubic" },
        { id: "snappy",  label: "Snappy",  scale: 70,  curve: "OutQuint" },
        { id: "springy", label: "Springy", scale: 110, curve: "OutBack" },
        { id: "off",     label: "None",    scale: 0,   curve: "Linear" }
    ]

    function easingTypeOf(id: string): int {
        const curve = root.easingCurves.find(entry => entry.id === id)
        return curve ? curve.type : Easing.OutCubic
    }

    readonly property int durationFast: Math.round(140 * root.motion)
    readonly property int durationMedium: Math.round(200 * root.motion)
    readonly property int durationMorph: Math.round(380 * root.motion)

    // How long anything that screenshots the screen (lock, picker, capture)
    // waits after closing the island: the morph plus a couple of frames.
    readonly property int durationIslandGone: root.durationMorph + 40


    // ── CAPTURE ─────────────────────────────────────────────────────────────

    // Wash outside the selection. Neutral black: a tinted wash would recolour
    // the screenshot being cropped.
    readonly property color captureWash: "#99000000"

    readonly property int captureBarMargin: root.barTopMargin + 14

    // ── APPLICATION ─────────────────────────────────────────────────────────

    readonly property var tokens: [
        "background", "surface", "surfaceHover", "border", "text", "textMuted",
        "accent", "accentHover", "accentText", "red", "green", "yellow", "blue"
    ]

    // Tokens a palette does not define keep their current value.
    function apply(colors: var, name: string): void {
        if (!colors)
            return
        if (name)
            root.activeName = name
        for (const token of root.tokens) {
            if (colors[token])
                root[token] = colors[token]
        }
    }
}
