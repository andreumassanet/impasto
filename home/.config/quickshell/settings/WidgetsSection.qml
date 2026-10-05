// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W I D G E T S   S E C T I O N                                          │
// │   desktop widgets · defaults and editing                                 │
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

// Two parts: settings that belong to the modules themselves (read by the bar
// chip as well as the widget), and the theme, style and opacity every desktop
// widget follows unless it has its own. Widgets are placed, resized and
// styled on the desktop itself; this page only enters that mode.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    // `SettingsPanel` closes the window on this.
    signal arranging()

    // ── MODULE SETTINGS ─────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "modules"

        SettingGroup {
            title: Tr.t("Weather")
            note: Tr.t("A city, a postcode or an airport code.")
            hint: Tr.t("Left empty, wttr.in guesses from your connection's IP address, which can be far off. A city, postcode or airport code is more reliable, and the bar uses the same place.")

            // wttr.in answers an unknown place with prose and the widget
            // keeps its last reading, so the error is shown here.
            SettingField {
                label: Tr.t("Location")
                reading: WeatherService.placeUnknown
                    ? Tr.t("No such place — the last reading is still showing") : ""
                alarm: WeatherService.placeUnknown
                placeholder: Tr.t("Wherever the request comes from")
                value: SettingsService.weatherPlace
                onEdited: value => SettingsService.set("weatherPlace", value.trim())
            }
        }

        SettingGroup {
            title: "GitHub"
            note: Tr.t("Whose public contribution graph to draw.")
            hint: Tr.t("The graph is read from the public profile page, so no token or account is needed. It stays empty until you enter a username.")

            // An unknown user returns a page with no calendar and the widget
            // keeps its last grid, so the error is shown here.
            SettingField {
                label: Tr.t("Username")
                reading: GithubService.userUnknown
                    ? Tr.t("No such profile — the last grid is still showing") : ""
                alarm: GithubService.userUnknown
                placeholder: Tr.t("Nobody yet")
                value: SettingsService.githubUser
                onEdited: value => SettingsService.set(
                    "githubUser", value.trim().replace(/^@/, ""))
            }
        }

        // The tiles draw the pet itself, one in each style, and blink while
        // the pointer is on them.
        SettingGroup {
            title: Tr.t("Pet")
            note: Tr.t("How the creature is drawn, wherever it is drawn.")
            hint: Tr.t("The species decides the colour and what the creature is; the style decides how it is drawn. The same drawing is used on the bar, in the pet's panel and on the desktop.")

            SettingTiles {
                label: Tr.t("Style")
                reading: Tr.t((PetService.styles.find(
                    entry => entry.id === SettingsService.petStyle) ?? { note: "" }).note)

                Repeater {
                    model: PetService.styles

                    PreviewTile {
                        id: petTile

                        required property var modelData

                        stageHeight: 78
                        caption: Tr.t(petTile.modelData.label)
                        selected: SettingsService.petStyle === petTile.modelData.id
                        onPicked: SettingsService.set("petStyle", petTile.modelData.id)

                        // An egg is an egg in three of the four styles, so
                        // the tiles draw the creature inside it.
                        PetFace {
                            anchors.centerIn: parent
                            size: 58
                            style: petTile.modelData.id
                            record: Object.assign({}, PetService.pet, { hatchedAt: 1 })
                            lively: petTile.hovered
                        }
                    }
                }
            }
        }

        SettingGroup {
            title: Tr.t("Notes")
            note: Tr.t("A note on the wallpaper is written the same way as one in the panel.")
            hint: Tr.t("The notes stuck on the screen's edges leave when a window opens on the workspace and come back when the last one closes. Off, they stay over the windows.")

            SettingRow {
                label: Tr.t("Handwriting")
                reading: SettingsService.notesHandwriting
                    ? Tr.t("The signature's script") : Tr.t("The interface face")

                ToggleSwitch {
                    checked: SettingsService.notesHandwriting
                    onToggled: checked => SettingsService.set("notesHandwriting", checked)
                }
            }

            SettingRow {
                label: Tr.t("Edges only on an empty workspace")
                reading: SettingsService.deckOnEmpty
                    ? Tr.t("Gone while a window is open") : Tr.t("Over the windows")

                ToggleSwitch {
                    checked: SettingsService.deckOnEmpty
                    onToggled: checked => SettingsService.set("deckOnEmpty", checked)
                }
            }
        }

        SettingGroup {
            title: Tr.t("Spectrum")
            note: Tr.t("Sound bars from whatever is playing, on the grid or along an edge.")
            hint: Tr.t("The bars leave when a window opens on the workspace and come back when the last one closes, and stop listening meanwhile. Off, they stay under the windows.")

            SettingRow {
                label: Tr.t("Only on an empty workspace")
                reading: SettingsService.spectrumOnEmpty
                    ? Tr.t("Gone while a window is open") : Tr.t("Under the windows")

                ToggleSwitch {
                    checked: SettingsService.spectrumOnEmpty
                    onToggled: checked => SettingsService.set("spectrumOnEmpty", checked)
                }
            }
        }
    }

    // ── THE WIDGETS ─────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "widgets"

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

            SettingRow {
                label: Tr.t("Hide the widgets")
                reading: SettingsService.desktopHidden
                    ? Tr.t("Off the wallpaper until you show them again")
                    : Tr.t("On the wallpaper")

                ToggleSwitch {
                    checked: SettingsService.desktopHidden
                    onToggled: checked => SettingsService.set("desktopHidden", checked)
                }
            }
        }

        SettingGroup {
            title: Tr.t("Look")
            note: Tr.t("Every widget follows these unless it was given a look of its own.")
            hint: Tr.t("While arranging, click a widget to override these for it alone. Modern shows a figure with a caption, Analogue draws an object such as a dial or a gauge, and Sticker cuts it out as coloured stickers on the wallpaper; the style and background set what sits behind the first two.")

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

            // The widgets' own ground, or the bar's.
            SettingTiles {
                label: Tr.t("Ground")
                reading: SettingsService.desktopGround === "" ? Tr.t("As the bar")
                    : Theme.deskGlass ? Tr.t("The terminal's glass, over a blur") : Tr.t("Solid black")
                locked: !DesktopService.capsuled
                reason: Tr.t("No widget on the desk has a capsule")

                Repeater {
                    model: [
                        { id: "", label: "As the bar" },
                        { id: "classic", label: "Classic" },
                        { id: "glass", label: "Glass" }
                    ]

                    PreviewTile {
                        id: deskTile

                        required property var modelData

                        stageHeight: 56
                        caption: Tr.t(deskTile.modelData.label)
                        selected: SettingsService.desktopGround === deskTile.modelData.id
                        onPicked: SettingsService.set("desktopGround", deskTile.modelData.id)

                        GroundSwatch {
                            anchors.centerIn: parent
                            style: deskTile.modelData.id === "" ? SettingsService.surfaceStyle
                                : deskTile.modelData.id
                        }
                    }
                }
            }

            SettingSlider {
                label: Tr.t("Background")
                value: SettingsService.desktopOpacity
                from: 0
                to: 100
                stepSize: 5
                unit: "%"
                // A see-through ground sets it: the capsules are the island's glass.
                locked: !DesktopService.capsuled || !Theme.deskSolid
                reason: !DesktopService.capsuled ? Tr.t("No widget on the desk has a capsule")
                    : Tr.t("Choose the Classic ground above to change it")
                onMoved: value => SettingsService.set("desktopOpacity", Math.round(value))
            }
        }
    }
}
