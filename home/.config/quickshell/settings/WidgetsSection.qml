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
                        DesktopService.edit(true)
                        root.arranging()
                    }
                }
            }
        }

        SettingGroup {
            title: Tr.t("Look")
            note: Tr.t("Every widget follows these unless it was given a look of its own.")
            hint: Tr.t("While arranging, click a widget to override these for it alone. Modern shows a figure with a caption and Analogue draws an object such as a dial or a gauge; the style and background set what sits behind it.")

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

            SettingTiles {
                label: Tr.t("Style")

                Repeater {
                    model: DesktopService.styles

                    PreviewTile {
                        id: styleTile

                        required property var modelData

                        stageHeight: 56
                        caption: Tr.t(styleTile.modelData.label)
                        selected: SettingsService.desktopStyle === styleTile.modelData.id
                        onPicked: SettingsService.set("desktopStyle", styleTile.modelData.id)

                        StyleSwatch {
                            anchors.centerIn: parent
                            factor: 1.6
                            style: styleTile.modelData.id
                            ink: DesktopService.inkFor({ style: styleTile.modelData.id })
                        }
                    }
                }
            }

            SettingSlider {
                label: Tr.t("Background")
                value: SettingsService.desktopOpacity
                from: 20
                to: 100
                stepSize: 5
                unit: "%"
                onMoved: value => SettingsService.set("desktopOpacity", Math.round(value))
            }
        }
    }
}
