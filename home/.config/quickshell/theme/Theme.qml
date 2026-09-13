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
    // themed surface.
    readonly property color island: "#000000"
    readonly property color islandSurface: "#141414"
    readonly property color islandSurfaceHover: "#1f1f1f"
    readonly property color islandBorder: "#262626"

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
    // which fits the largest island detail (380 × 172) with one gutter around
    // it; a larger detail needs a larger cell.
    readonly property int desktopCell: 86
    readonly property int desktopCellLargest: 108
    readonly property int desktopGutter: 18
    readonly property int desktopStride: root.desktopCell + root.desktopGutter

    // ── CONTROL CENTRE GRID ─────────────────────────────────────────────────
    //
    // 6 × 8 cells; one cell is one toggle tile, and blocks span whole cells.
    readonly property int centreColumns: 6
    readonly property int centreRows: 8
    readonly property int centreCellWidth: 140
    readonly property int centreCellHeight: 64
    readonly property int centreGutter: 12
    readonly property int centreStrideX: root.centreCellWidth + root.centreGutter
    readonly property int centreStrideY: root.centreCellHeight + root.centreGutter

    // The pager strip (dots and chevrons) along the bottom of a paged block.
    readonly property int centrePagerLane: 18

    readonly property int panelPadding: 20

    // ── DOCK ────────────────────────────────────────────────────────────────
    //
    // Everything scales off the icon size. The margin matches `gaps_out`.
    readonly property int dockIcon: SettingsService.dockIconSize
    readonly property int dockPadding: 8
    readonly property int dockGap: root.capsuleSpacing
    readonly property int dockMargin: root.desktopGutter

    // Depth is the icon plus a lane for the running dots, so icons sit off
    // centre, away from the screen edge.
    readonly property int dockDot: 5
    readonly property int dockDotLane: 9
    readonly property int dockDepth: root.dockIcon + root.dockDotLane
    readonly property int dockThickness: root.dockDepth + 2 * root.dockPadding

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

    readonly property string fontFamily: SettingsService.fontFamily
    readonly property string fontMono: SettingsService.fontMono

    // Script face for the shell's own name. Checked explicitly because Qt
    // substitutes silently when a family is missing.
    readonly property string fontSignature: {
        const installed = Qt.fontFamilies()
        for (const family of ["Grape Nuts", "Georgia"]) {
            if (installed.indexOf(family) !== -1)
                return family
        }
        return root.fontFamily
    }

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

    readonly property real motion: SettingsService.motionScale / 100

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
