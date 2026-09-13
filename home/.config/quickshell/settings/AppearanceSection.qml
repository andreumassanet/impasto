// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A P P E A R A N C E   S E C T I O N                                    │
// │   appearance · palette, windows, fonts and motion                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// Theme, windows, type and motion.
//
// The compositor values here are stored in the shell's settings and pushed to
// Hyprland at login and after every reload. `hypr/modules/look.lua` holds the
// defaults and is never written.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    signal panelRequested(string panel)

    Component.onCompleted: {
        CompositorService.load()
        // Loaded up front so the rules have rows as soon as they are shown.
        CompositorService.loadWindowRules()
        CompositorService.loadGlass()
        FontService.load()
    }

    // The stored value first, the compositor's second: `remember` stores on
    // every drag step while the push to Hyprland is coalesced, so reading the
    // compositor back would lag the slider.
    function live(option: string, fallback: real): real {
        const kept = SettingsService.compositor
        if (kept && kept[option] !== undefined)
            return Number(kept[option])
        return Number(CompositorService.value(option, fallback))
    }

    readonly property bool blurOn: {
        const kept = SettingsService.compositor
        const raw = kept && kept["decoration:blur:enabled"] !== undefined
            ? kept["decoration:blur:enabled"]
            : CompositorService.value("decoration:blur:enabled", true)
        return String(raw) === "true" || raw === true || raw === 1
    }

    // ── THEME ───────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "theme"

        // Theme and wallpaper are chosen in the island's appearance panel;
        // this row only opens it.
        SettingGroup {
            title: Tr.t("Theme")
            note: Tr.t("The palette follows the wallpaper, and both are chosen in the island.")
            hint: Tr.t("This opens the island's appearance panel, where wallpapers and palettes are chosen together.")

            SettingRow {
                label: Tr.t("Theme and wallpaper")
                reading: Theme.activeName

                PillButton {
                    text: Tr.t("Open")
                    icon: "󰔏"
                    active: true
                    implicitWidth: 92
                    implicitHeight: 30
                    onClicked: root.panelRequested("appearance")
                }
            }
        }

        // Each tile loops its awww transition in miniature.
        SettingGroup {
            title: Tr.t("Transition")
            note: Tr.t("How the next wallpaper arrives over the last one.")
            hint: Tr.t("Random picks one of the effects above each time a wallpaper is applied.")

            SettingTiles {
                label: Tr.t("Effect")

                Repeater {
                    model: WallpaperService.transitions

                    PreviewTile {
                        id: transitionTile

                        required property var modelData

                        stageHeight: 52
                        caption: Tr.t(transitionTile.modelData.label)
                        selected: SettingsService.wallpaperTransition === transitionTile.modelData.id
                        onPicked: SettingsService.set("wallpaperTransition", transitionTile.modelData.id)

                        WallpaperTransitionPreview {
                            anchors.centerIn: parent
                            effect: transitionTile.modelData.id
                        }
                    }
                }
            }
        }

        // The tiles play the generated greeting scenes in the current palette.
        SettingGroup {
            title: Tr.t("Greeting")
            note: Tr.t("The animation shown beside fastfetch when you run fa.")
            hint: Tr.t("Four pixel-art scenes, redrawn in the current palette whenever it changes. Random picks a new one on every run, and fa with a scene name (fa koi) plays that one.")

            SettingTiles {
                label: Tr.t("Scene")

                Repeater {
                    model: ThemeService.greetings

                    PreviewTile {
                        id: greetingTile

                        required property var modelData

                        stageHeight: 124
                        caption: Tr.t(greetingTile.modelData.label)
                        selected: SettingsService.greeting === greetingTile.modelData.id
                        onPicked: SettingsService.set("greeting", greetingTile.modelData.id)

                        GreetingPreview {
                            anchors.centerIn: parent
                            scene: greetingTile.modelData.id
                            version: ThemeService.greetingStamp
                        }
                    }
                }
            }
        }
    }

    // ── WINDOWS ─────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "windows"

        SettingGroup {
            title: Tr.t("Windows")
            note: Tr.t("How Hyprland draws every window, this one included.")
            hint: Tr.t("The preview below is live and at full size. The border stays at zero because gaps and rounding already separate windows; the inner gap applies to each side of a window, so two windows sit twice that apart.")

            SettingBlock {
                WindowsPreview {
                    Layout.fillWidth: true
                    rounding: root.live("decoration:rounding", 22)
                    borderWidth: root.live("general:border_size", 0)
                    gapsIn: root.live("general:gaps_in", 7)
                    gapsOut: root.live("general:gaps_out", 18)
                    inactiveOpacity: root.live("decoration:inactive_opacity", 1)
                    blur: root.blurOn ? root.live("decoration:blur:size", 6) : 0
                    glassed: SettingsService.windowGlass && CompositorService.glassAvailable
                    lifted: SettingsService.windowShadow
                    wallpaper: WallpaperService.currentWallpaper
                }
            }

            SettingSlider {
                label: Tr.t("Window rounding")
                value: CompositorService.value("decoration:rounding", 22)
                from: 0
                to: 30
                unit: " px"
                onMoved: value => CompositorService.remember("decoration:rounding", Math.round(value))
            }

            SettingSlider {
                label: Tr.t("Border width")
                value: CompositorService.value("general:border_size", 0)
                from: 0
                to: 6
                reading: CompositorService.value("general:border_size", 0) === 0
                    ? Tr.t("None") : `${CompositorService.value("general:border_size", 0)} px`
                onMoved: value => CompositorService.remember("general:border_size", Math.round(value))
            }

            SettingSlider {
                label: Tr.t("Inner gap")
                value: CompositorService.value("general:gaps_in", 7)
                from: 0
                to: 20
                unit: " px"
                onMoved: value => CompositorService.remember("general:gaps_in", Math.round(value))
            }

            SettingSlider {
                label: Tr.t("Outer gap")
                value: CompositorService.value("general:gaps_out", 18)
                from: 0
                to: 40
                unit: " px"
                onMoved: value => CompositorService.remember("general:gaps_out", Math.round(value))
            }

            SettingSlider {
                label: Tr.t("Inactive opacity")
                value: Math.round(CompositorService.value("decoration:inactive_opacity", 1) * 100)
                from: 60
                to: 100
                unit: "%"
                onMoved: value => CompositorService.remember(
                    "decoration:inactive_opacity", (Math.round(value) / 100).toFixed(2))
            }
        }

        SettingGroup {
            title: Tr.t("Depth")
            note: Tr.t("What shows through a window, and what it sits on.")
            hint: Tr.t("Blur shows behind anything translucent, such as the terminal. Glass (a Hyprland plugin, tuned in look.lua) frosts and refracts what is behind a window, and the shadow lifts windows and bar capsules off the wallpaper.")

            SettingSlider {
                label: Tr.t("Blur")
                value: CompositorService.value("decoration:blur:enabled", 0)
                    ? CompositorService.value("decoration:blur:size", 4) : 0
                from: 0
                to: 12
                reading: {
                    const on = CompositorService.value("decoration:blur:enabled", 0)
                    const size = CompositorService.value("decoration:blur:size", 4)
                    return on ? `${Tr.t("size")} ${size}` : Tr.t("Off")
                }
                onMoved: value => {
                    const size = Math.round(value)
                    CompositorService.remember("decoration:blur:enabled", size === 0 ? "false" : "true")
                    if (size > 0)
                        CompositorService.remember("decoration:blur:size", size)
                }
            }

            // Locked, with the reason, when the hyprglass plugin is not loaded.
            SettingRow {
                label: Tr.t("Glass")
                locked: !CompositorService.glassAvailable
                reason: Tr.t("Needs the glass plugin — run ./setup plugins")

                ToggleSwitch {
                    checked: SettingsService.windowGlass
                    onToggled: checked => SettingsService.set("windowGlass", checked)
                }
            }

            SettingRow {
                label: Tr.t("Shadow")
                reading: SettingsService.windowShadow
                    ? Tr.t("Lifted off the wallpaper") : Tr.t("Flat")

                ToggleSwitch {
                    checked: SettingsService.windowShadow
                    onToggled: checked => SettingsService.set("windowShadow", checked)
                }
            }
        }

        // ── WINDOW RULES ────────────────────────────────────────────────────
        //
        // Read-only and folded by default; the rules live in
        // `windowrules.lua`. `compositor.py rules` parses each into its match
        // and its effects.
        SettingGroup {
            id: rules

            property bool expanded: false

            title: Tr.t("Window rules")
            hint: Tr.t("Read from hypr/modules/windowrules.lua — changing them means editing that file.")

            SettingRow {
                label: Tr.t("Every rule")
                reading: `${CompositorService.windowRules.length} ${Tr.t("in windowrules.lua")}`

                PillButton {
                    text: rules.expanded ? Tr.t("Hide") : Tr.t("View")
                    icon: rules.expanded ? "󰅃" : "󰅀"
                    implicitWidth: 76
                    implicitHeight: 26
                    active: rules.expanded
                    onClicked: rules.expanded = !rules.expanded
                }
            }

            SettingBlock {
                visible: rules.expanded && CompositorService.windowRules.length === 0

                Text {
                    Layout.fillWidth: true
                    text: Tr.t("Nothing to show — the file is missing or empty.")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }

            Repeater {
                model: rules.expanded ? CompositorService.windowRules : []

                Item {
                    id: ruleRow

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: ruleBody.implicitHeight + 20

                    SettingDivider {}

                    ColumnLayout {
                        id: ruleBody

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: ruleRow.modelData.name
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.text
                            }

                            Item { Layout.fillWidth: true }

                            // One chip per effect, in Hyprland's terms.
                            Repeater {
                                model: ruleRow.modelData.effects

                                Rectangle {
                                    required property string modelData

                                    implicitWidth: effectLabel.implicitWidth + 16
                                    implicitHeight: 20
                                    radius: height / 2
                                    color: Theme.islandSurfaceHover
                                    border.color: Theme.islandBorder
                                    border.width: 1

                                    Text {
                                        id: effectLabel
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLabel
                                        color: Theme.accent
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: ruleRow.modelData.match
                            elide: Text.ElideRight
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }
    }

    // ── TYPE ────────────────────────────────────────────────────────────────
    //
    // Families come from fontconfig: Qt silently substitutes a family that is
    // not installed, so a typed name could look applied when it is not.

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "type"

        SettingGroup {
            title: Tr.t("Interface")
            note: Tr.t("Everything Quickshell draws.")

            SettingBlock {
                padding: 6

                FontPicker {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 132
                    families: FontService.sans
                    current: SettingsService.fontFamily
                    sample: "The quick brown fox 0123"
                    onPicked: family => SettingsService.set("fontFamily", family)
                }
            }
        }

        SettingGroup {
            title: Tr.t("Monospace")
            note: Tr.t("The bar's glyphs and readings, and the terminal.")
            hint: Tr.t("kitty is given the same family, so the terminal and the shell always match. It must be a Nerd Font, or the bar's icons show as empty boxes.")

            SettingBlock {
                padding: 6

                FontPicker {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 132
                    families: FontService.mono
                    current: SettingsService.fontMono
                    sample: "il1 O0 {} => 0123"
                    warning: Tr.t("Icons need a Nerd Font patched family.")
                    onPicked: family => SettingsService.set("fontMono", family)
                }
            }
        }
    }

    // ── MOTION ──────────────────────────────────────────────────────────────
    //
    // One row of presets per renderer: the island is animated by Qt and the
    // windows by Hyprland, and neither can use the other's curves.

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "motion"

        SettingGroup {
            title: Tr.t("The shell")
            note: Tr.t("The island, its panels, the chips — everything Qt draws.")

            // Named only when no preset matches, since the chosen tile
            // already says which it is.
            SettingTiles {
                label: Tr.t("Pace")
                reading: Theme.motionPresets.some(
                    row => row.scale === SettingsService.motionScale
                        && row.curve === SettingsService.motionCurve) ? "" : Tr.t("Custom")

                Repeater {
                    model: Theme.motionPresets

                    PreviewTile {
                        id: shellTile

                        required property var modelData

                        stageHeight: 52
                        caption: Tr.t(shellTile.modelData.label)
                        selected: SettingsService.motionScale === shellTile.modelData.scale
                            && SettingsService.motionCurve === shellTile.modelData.curve
                        onPicked: {
                            SettingsService.set("motionScale", shellTile.modelData.scale)
                            SettingsService.set("motionCurve", shellTile.modelData.curve)
                        }

                        IslandMotionPreview {
                            anchors.centerIn: parent
                            preset: shellTile.modelData
                        }
                    }
                }
            }
        }

        // The hint describes every preset, built from `Motion.presets`.
        SettingGroup {
            title: Tr.t("Windows")
            note: Tr.t("How Hyprland animates windows. Reapplied after every reload.")
            hint: Motion.presets.map(
                entry => `${Tr.t(entry.label)} — ${Tr.t(entry.note)}`).join(" ")

            SettingTiles {
                label: Tr.t("Preset")

                Repeater {
                    model: Motion.presets

                    PreviewTile {
                        id: tile

                        required property var modelData

                        stageHeight: 52
                        caption: Tr.t(tile.modelData.label)
                        selected: SettingsService.animationPreset === tile.modelData.id
                        onPicked: SettingsService.set("animationPreset", tile.modelData.id)

                        MotionPreview {
                            anchors.centerIn: parent
                            width: parent.width - 22
                            preset: tile.modelData
                        }
                    }
                }
            }
        }
    }
}
