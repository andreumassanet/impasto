// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O D U L E S   S E C T I O N                                          │
// │   modules · what they know, wherever they are shown                      │
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

// The modules' own settings: read by a chip on the bar, a widget on the
// desktop and a panel alike, so they belong to none of those pages.
SettingsSection {
    id: root

    // Unused: this page has no parts, but `SettingsPanel` sets it on all pages.
    property string tab: ""

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
        title: Tr.t("Markets")
        note: Tr.t("The coins and currencies to follow, separated by commas.")
        hint: Tr.t("A coin alone is priced in US dollars and BTC/EUR in euros; two currencies, such as EUR/USD, follow the European Central Bank's daily rate. Prices come from CoinGecko and Frankfurter, which see what you follow but need no account. The bar shows the first one.")

        // A symbol neither source knows is dropped from the widget, so
        // it is named here.
        SettingField {
            label: Tr.t("Follow")
            reading: MarketsService.unknown.length > 0
                ? `${Tr.t("Not found:")} ${MarketsService.unknown.join(", ")}` : ""
            alarm: MarketsService.unknown.length > 0
            placeholder: "BTC, ETH, EUR/USD"
            value: SettingsService.markets
            onEdited: value => SettingsService.set("markets", value.trim())
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
        title: Tr.t("Lyrics")
        note: Tr.t("The words of whatever is playing, wherever they are shown.")
        hint: Tr.t("Looked up on lrclib.net by title and artist, which needs no account. They show in the island's glance and its media card, in the desktop's lyrics widget and on the lock screen when it is set to show them.")

        SettingRow {
            label: Tr.t("Look them up")
            reading: SettingsService.lyrics
                ? Tr.t("The playing track's lyrics are looked up on lrclib.net")
                : Tr.t("No lyrics, and nothing is looked up")

            ToggleSwitch {
                checked: SettingsService.lyrics
                onToggled: checked => SettingsService.set("lyrics", checked)
            }
        }
    }

    SettingGroup {
        title: Tr.t("Media cover")
        note: Tr.t("The picture of what is playing, in the control centre, the island, the media card and the lyrics.")
        hint: Tr.t("The bars around a circle come from cava, which listens to the sound only while a cover with bars is visible. Without cava installed the circle stays plain.")

        SettingRow {
            label: Tr.t("Shape")
            reading: SettingsService.mediaCover === "circle"
                ? Tr.t("A round cover, with bars around it where there is room") : Tr.t("A rounded rectangle")

            SegmentedControl {
                options: [
                    { id: "rectangle", label: Tr.t("Rectangle") },
                    { id: "circle", label: Tr.t("Circle") }
                ]
                current: SettingsService.mediaCover
                onSelected: id => SettingsService.set("mediaCover", id)
            }
        }
    }

    SettingGroup {
        title: Tr.t("Media player")
        note: Tr.t("What opens from the media piece, from its chip, the island and the control centre.")

        SettingRow {
            label: Tr.t("Design")
            reading: SettingsService.mediaDesign === "panel"
                ? Tr.t("A wide panel: the cover, the controls and the lyrics side by side")
                : Tr.t("A card under the piece, with the lyrics opening out beside it")

            SegmentedControl {
                options: [
                    { id: "card", label: Tr.t("Card") },
                    { id: "panel", label: Tr.t("Panel") }
                ]
                current: SettingsService.mediaDesign
                onSelected: id => SettingsService.set("mediaDesign", id)
            }
        }
    }

    SettingGroup {
        title: Tr.t("Notes")
        note: Tr.t("A note on the wallpaper is written the same way as one in the panel.")

        SettingRow {
            label: Tr.t("Handwriting")
            reading: SettingsService.notesHandwriting
                ? Tr.t("The signature's script") : Tr.t("The interface face")

            ToggleSwitch {
                checked: SettingsService.notesHandwriting
                onToggled: checked => SettingsService.set("notesHandwriting", checked)
            }
        }
    }
}
