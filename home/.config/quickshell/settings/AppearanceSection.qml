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

// The wallpaper and its palette, the terminal, type and the shell's motion.
// What Hyprland does to windows is `WindowsSection`.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    signal panelRequested(string panel)

    Component.onCompleted: FontService.load()

    // The names `theme_manager.py` takes in `themeTargets`.
    readonly property var themeApplications: [
        { id: "terminal", label: "kitty" }, { id: "greeting", label: Tr.t("Terminal greeting") },
        { id: "btop", label: "btop" }, { id: "cava", label: "cava" },
        { id: "yazi", label: "yazi" }, { id: "nvim", label: "Neovim" },
        { id: "imv", label: "imv" }, { id: "gtk", label: "GTK" },
        { id: "qt", label: "Qt and KDE" }, { id: "vesktop", label: "Vesktop" },
        { id: "spotify", label: "Spotify" }, { id: "vscodium", label: "VSCodium" },
        { id: "zen", label: "Zen" }, { id: "nautilus", label: "Nautilus" }
    ]

    function themeTargetOn(id: string): bool {
        const targets = SettingsService.themeTargets
        return SettingsService.shapeOf(targets) !== "list" || targets.indexOf(id) >= 0
    }

    // Null stays for "all", so a program added later is on by default.
    function setThemeTarget(id: string, on: bool): void {
        const kept = root.themeApplications.map(app => app.id)
            .filter(name => name === id ? on : root.themeTargetOn(name))
        SettingsService.set("themeTargets", kept.length === root.themeApplications.length ? null : kept)
    }

    // ── WALLPAPER ───────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "wallpaper"

        // Theme and wallpaper are chosen in the island's appearance panel;
        // this row only opens it.
        SettingGroup {
            title: Tr.t("Theme")
            note: Tr.t("The palette follows the wallpaper, and both are chosen in the island.")
            hint: Tr.t("This opens the island's appearance panel, where wallpapers and palettes are chosen together.")

            SettingRow {
                label: Tr.t("Theme and wallpaper")
                reading: Tr.t(Theme.activeName)

                PillButton {
                    text: Tr.t("Open")
                    icon: "󰏘"
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

        // What `theme_manager.py` writes when the palette changes. Left on,
        // each program gets a theme file in its own config folder.
        SettingGroup {
            title: Tr.t("Applications")
            note: Tr.t("The programs the palette is written to.")
            hint: Tr.t("Each program on this list gets a theme file in its own config folder when the palette changes. Turn one off to leave its files alone.")

            Repeater {
                model: root.themeApplications

                SettingRow {
                    id: applicationRow

                    required property var modelData

                    label: applicationRow.modelData.label

                    ToggleSwitch {
                        checked: root.themeTargetOn(applicationRow.modelData.id)
                        onToggled: checked => root.setThemeTarget(applicationRow.modelData.id, checked)
                    }
                }
            }
        }
    }

    // ── TERMINAL ────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "terminal"

        SettingGroup {
            title: Tr.t("Look")
            note: Tr.t("What kitty's window is made of.")
            hint: Tr.t("Classic is solid black, Glass the accent-tinted ground over a blur of the wallpaper, and Liquid a clear frosted pane. Its typeface is the monospace one, under Type.")

            GroundRow {
                key: "terminalGround"
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
                    sample: Tr.t("The quick brown fox 0123")
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
    // The shell's own pace; the windows' animation is Hyprland's, on the
    // Windows page, and neither can use the other's curves.

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "motion"

        SettingGroup {
            title: Tr.t("Game mode")
            note: Tr.t("Everything still, for a game or a slow machine.")
            hint: Tr.t("Stops the shell's animations, the spectrum and the pet, makes the island, the dock and the widgets solid without shadows, and turns off Hyprland's animations, blur, shadow and glass. The settings below are kept and come back when it is turned off.")

            SettingRow {
                label: Tr.t("Game mode")
                reading: ShortcutService.current("Shell · Turn game mode on or off")

                ToggleSwitch {
                    checked: SettingsService.gameMode
                    onToggled: checked => SettingsService.set("gameMode", checked)
                }
            }
        }

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
    }
}
