// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W I D G E T S   S E C T I O N                                          │
// │   desktop · arranging, the widgets' look, and when they leave            │
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
import "../desktop"

// The desktop under the windows: the way into arranging it, the look every
// widget follows unless it has its own, and what leaves when a window opens.
// Widgets are placed, resized and styled on the desktop itself; this page
// only enters that mode.
SettingsSection {
    id: root

    // Unused: this page has no parts, but `SettingsPanel` sets it on all pages.
    property string tab: ""

    // `SettingsPanel` closes the window on this.
    signal arranging()

    SettingGroup {
        title: Tr.t("The desktop")
        note: Tr.t("Widgets are arranged directly on the wallpaper.")
        hint: Tr.t("Arranging brings the widgets in front of the windows, with a card of every module, moved by the space between them. Drag one onto the grid, pull a widget's corner to change its shape, click it for a look of its own, and drop it back on the card to take it off. Escape or the right button ends it, and the right button on any widget opens the same mode from the picture. This window closes meanwhile.")

        SettingRow {
            label: Tr.t("Arrange the desktop")
            reading: DesktopService.widgets.length > 0
                ? `${DesktopService.widgets.length} ${Tr.t("on the wallpaper")}`
                : Tr.t("Nothing on the wallpaper yet")

            PillButton {
                text: Tr.t("Edit")
                implicitHeight: 30
                onClicked: {
                    // The card opens on the screen this window is on.
                    DesktopService.edit(true, root.QsWindow.window?.screen?.name
                        || MonitorService.effectivePrimaryName)
                    root.arranging()
                }
            }
        }
    }

    SettingGroup {
        title: Tr.t("Look")
        note: Tr.t("Every widget follows these unless it was given a look of its own.")
        hint: Tr.t("While arranging, click a widget to override these for it alone. Modern shows a figure with a caption, Analogue draws an object such as a dial or a gauge, and Sticker cuts it out as coloured stickers on the wallpaper; the ground and the background set what the first two are made of and how opaque.")

        SettingTiles {
            label: Tr.t("Face")

            Repeater {
                model: DesktopService.themes

                PreviewTile {
                    id: themeTile

                    required property var modelData

                    stageHeight: 64
                    caption: Tr.t(themeTile.modelData.label)
                    selected: SettingsService.desktopTheme === themeTile.modelData.id
                    onPicked: SettingsService.set("desktopTheme", themeTile.modelData.id)

                    ThemeSwatch {
                        anchors.centerIn: parent
                        theme: themeTile.modelData.id
                        factor: 0.3
                    }
                }
            }
        }

        GroundRow {
            key: "desktopGround"
        }

        SettingSlider {
            label: Tr.t("Background")
            value: SettingsService.desktopOpacity
            from: 0
            to: 100
            stepSize: 5
            unit: "%"
            onMoved: value => SettingsService.set("desktopOpacity", Math.round(value))
        }

        SettingRow {
            label: Tr.t("Shadow")
            reading: SettingsService.widgetShadow
                ? Tr.t("Lifted off the wallpaper") : Tr.t("Flat")

            ToggleSwitch {
                checked: SettingsService.widgetShadow
                onToggled: checked => SettingsService.set("widgetShadow", checked)
            }
        }
    }

    SettingGroup {
        title: Tr.t("Behaviour")
        note: Tr.t("What makes way when a window opens on the workspace.")
        hint: Tr.t("The notes stuck on the screen's edges and the spectrum's bars leave when a window opens and come back when the last one closes; the spectrum stops listening meanwhile. Off, the notes stay over the windows and the bars under them.")

        SettingRow {
            label: Tr.t("Notes on the edges")
            reading: SettingsService.deckOnEmpty
                ? Tr.t("Gone while a window is open") : Tr.t("Over the windows")

            ToggleSwitch {
                checked: SettingsService.deckOnEmpty
                onToggled: checked => SettingsService.set("deckOnEmpty", checked)
            }
        }

        SettingRow {
            label: Tr.t("Spectrum")
            reading: SettingsService.spectrumOnEmpty
                ? Tr.t("Gone while a window is open") : Tr.t("Under the windows")

            ToggleSwitch {
                checked: SettingsService.spectrumOnEmpty
                onToggled: checked => SettingsService.set("spectrumOnEmpty", checked)
            }
        }
    }
}
