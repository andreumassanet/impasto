// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A R   S E C T I O N                                                  │
// │   bar · island, layout, workspaces and notifications                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"
import "../services"
import "../components"

// Three parts: how the bar is drawn, what it carries (`ModulesPart`), and the
// workspaces its strip shows. What the island shows is `IslandSection`.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    // ── STYLE ───────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "style"

        SettingGroup {
            title: Tr.t("Shape")
            note: Tr.t("How the bar is drawn round the island.")
            hint: Tr.t("The style keeps what is on the bar and only changes how it is drawn: grouped round the island, spread to the two edges, all inside one capsule, or a bezel across the top edge. What each side carries is arranged in Layout. Rounded corners round every screen, and curve under the bezel's ends.")

            SettingTiles {
                label: Tr.t("Style")
                reading: Tr.t((SettingsService.barStyles.find(
                    entry => entry.id === SettingsService.barStyle) ?? { note: "" }).note)

                Repeater {
                    model: SettingsService.barStyles

                    PreviewTile {
                        id: styleTile

                        required property var modelData

                        caption: Tr.t(styleTile.modelData.label)
                        selected: SettingsService.barStyle === styleTile.modelData.id
                        onPicked: SettingsService.set("barStyle", styleTile.modelData.id)

                        BarPreview {
                            anchors.centerIn: parent
                            attached: SettingsService.islandAttached
                            barStyle: styleTile.modelData.id
                        }
                    }
                }
            }

            SettingRow {
                label: Tr.t("Rounded corners")
                reading: SettingsService.screenCorners
                    ? Tr.t("Every screen's corners curve like the windows")
                    : Tr.t("Square, as the panel is")

                ToggleSwitch {
                    checked: SettingsService.screenCorners
                    onToggled: checked => SettingsService.set("screenCorners", checked)
                }
            }

            // Locked in one capsule, where the sides sit on its band.
            SettingRow {
                label: Tr.t("Sides")
                reading: SettingsService.barSides === "bare"
                    ? Tr.t("The icons on the wallpaper")
                    : Tr.t("Each group in a capsule")
                locked: SettingsService.barStyle === "island" || SettingsService.barStyle === "bezel"
                reason: Tr.t("In one island the sides sit on its band")

                SegmentedControl {
                    options: [
                        { id: "capsule", label: Tr.t("In capsules") },
                        { id: "bare", label: Tr.t("On the wallpaper") }
                    ]
                    current: SettingsService.barSides
                    onSelected: id => SettingsService.set("barSides", id)
                }
            }

            SettingRow {
                label: Tr.t("On every screen")
                reading: SettingsService.barEverywhere
                    ? Tr.t("One on each, and the one you are on is the live one")
                    : Tr.t("Only on the screen you are on")
                locked: Quickshell.screens.length < 2
                reason: Tr.t("Only one screen is on")

                ToggleSwitch {
                    checked: SettingsService.barEverywhere
                    onToggled: checked => SettingsService.set("barEverywhere", checked)
                }
            }
        }

        SettingGroup {
            title: Tr.t("Scale")
            note: Tr.t("The bar itself is the preview: it repaints over this window as the sliders move.")
            hint: Tr.t("Everything on the bar scales with its height. The top margin is the gap to the screen edge (the island ignores it in notch mode), and the side margin is the inset from the left and right edges.")

            SettingSlider {
                label: Tr.t("Bar height")
                value: SettingsService.barHeight
                from: 24
                to: 48
                unit: " px"
                onMoved: value => SettingsService.set("barHeight", Math.round(value))
            }

            SettingSlider {
                label: Tr.t("Top margin")
                value: SettingsService.barMargin
                from: 0
                to: 32
                unit: " px"
                onMoved: value => SettingsService.set("barMargin", Math.round(value))
            }

            SettingSlider {
                label: Tr.t("Side margin")
                value: SettingsService.barSideMargin
                from: 0
                to: 48
                unit: " px"
                onMoved: value => SettingsService.set("barSideMargin", Math.round(value))
            }
        }

        SettingGroup {
            title: Tr.t("Look")
            note: Tr.t("What the bar and the island are made of.")
            hint: Tr.t("Classic is solid black, Glass the terminal's tinted ground over a blur of the wallpaper, and Liquid a clear frosted pane that lets the wallpaper's own colours through. The island is always the bar's.")

            GroundRow {
                key: "surfaceStyle"
            }

            SettingRow {
                label: Tr.t("Shadow")
                reading: SettingsService.barShadow
                    ? Tr.t("Lifted off the wallpaper") : Tr.t("Flat")

                ToggleSwitch {
                    checked: SettingsService.barShadow
                    onToggled: checked => SettingsService.set("barShadow", checked)
                }
            }
        }
    }

    // ── LAYOUT ──────────────────────────────────────────────────────────────

    ModulesPart {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "layout"
    }

    // ── WORKSPACES ──────────────────────────────────────────────────────────

    SettingGroup {
        visible: root.tab === "workspaces"
        title: Tr.t("Workspaces")
        note: Tr.t("The shown workspaces are always drawn; the rest, up to the available count, appear only while they have windows.")

        SettingBlock {
            WorkspaceStyles {
                Layout.fillWidth: true
            }
        }

        SettingRow {
            label: Tr.t("Icons")
            reading: SettingsService.workspaceIcons === "single" ? Tr.t("One per workspace, its last window")
                : SettingsService.workspaceIcons === "none" ? Tr.t("Numbers only")
                : Tr.t("The apps of the workspace you are on")

            SegmentedControl {
                options: [
                    { id: "group", label: Tr.t("All apps") },
                    { id: "single", label: Tr.t("One") },
                    { id: "none", label: Tr.t("None") }
                ]
                current: SettingsService.workspaceIcons
                onSelected: id => SettingsService.set("workspaceIcons", id)
            }
        }

        SettingRow {
            label: Tr.t("Apps beside the strip")
            reading: SettingsService.workspaceExtras
                ? Tr.t("The focused workspace's apps and the special workspace, after the strip")
                : Tr.t("Only the strip")
            locked: SettingsService.workspaceStyle === "pills"
            reason: Tr.t("The pills style always shows them")

            ToggleSwitch {
                checked: SettingsService.workspaceExtras
                onToggled: checked => SettingsService.set("workspaceExtras", checked)
            }
        }

        IconRules {}

        SettingSlider {
            label: Tr.t("Workspaces shown")
            value: HyprlandService.slots
            from: 1
            to: HyprlandService.maximum
            onMoved: value => SettingsService.set("workspaceCount", Math.round(value))
        }

        SettingSlider {
            label: Tr.t("Workspaces available")
            // Per screen, each screen has ten.
            value: HyprlandService.maximum
            from: 4
            to: HyprlandService.perScreen ? 10 : 20
            onMoved: value => {
                const max = Math.round(value)
                SettingsService.set("workspaceMax", max)
                // The ceiling cannot end up below the floor.
                if (SettingsService.workspaceCount > max)
                    SettingsService.set("workspaceCount", max)
            }
        }

        SettingRow {
            label: Tr.t("With more screens")
            reading: HyprlandService.perScreen
                ? Tr.t("Ten for each screen: the main one 1–10, the next 11–20")
                : Tr.t("Every screen shares the same ten")
            locked: Quickshell.screens.length < 2
            reason: Tr.t("Only one screen is on")

            SegmentedControl {
                options: [
                    { id: "shared", label: Tr.t("Shared") },
                    { id: "screen", label: Tr.t("Per screen") }
                ]
                current: SettingsService.workspaceMode
                onSelected: id => SettingsService.set("workspaceMode", id)
            }
        }
    }
}
