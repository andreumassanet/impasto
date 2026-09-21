// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T H E M E                                                              │
// │   login screen design tokens                                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick

// Fixed tokens: the greeter runs before any user's palette applies. Values
// match the shell's fixed island colours and its default accent.
QtObject {
    id: root

    // ── COLOUR ──────────────────────────────────────────────────────────────

    // The shell's capsule colours.
    readonly property color island: "#000000"
    readonly property color islandSurface: "#141414"
    readonly property color islandSurfaceHover: "#1f1f1f"
    readonly property color islandBorder: "#262626"

    readonly property color text: "#ffffff"
    readonly property color textMuted: "#8e8e93"

    // The shell's default accent.
    readonly property color accent: "#0a84ff"
    readonly property color accentText: "#ffffff"

    readonly property color indicator: "#ffffff"
    readonly property color indicatorWarn: "#ffd60a"
    readonly property color indicatorBad: "#ff453a"

    // ── METRIC ──────────────────────────────────────────────────────────────

    readonly property int capsuleHeight: 32
    readonly property int barTopMargin: 16

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18
    readonly property int radiusPill: 999
    readonly property int radiusNotch: 6

    // ── TYPE ────────────────────────────────────────────────────────────────

    // Qt matches one family and never a list: a comma-separated stack names
    // no installed font, and the default sans is drawn instead. Qt is handed
    // the first family in the stack that exists.
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

    readonly property string fontFamily:
        root.fontOf("Inter, Cantarell, SF Pro Text, sans-serif")
    readonly property string fontMono:
        root.fontOf("JetBrainsMono Nerd Font, monospace")

    // Inter's display cut, for the clock.
    readonly property string fontDisplay:
        root.fontOf("Inter Display, Inter, Cantarell, sans-serif")

    readonly property int fontSizeSmall: 11
    readonly property int fontSizeRegular: 13
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeDate: 26
    readonly property int fontSizeClock: 300

    // ── MOTION ──────────────────────────────────────────────────────────────

    readonly property int durationFast: 140
    readonly property int durationMedium: 200
    readonly property int durationMorph: 380
    readonly property int easing: Easing.OutCubic
}
