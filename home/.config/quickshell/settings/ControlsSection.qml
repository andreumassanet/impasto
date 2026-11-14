// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O N T R O L S   S E C T I O N                                        │
// │   control centre · its grid, and the buttons over it                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"
import "../bar/island/controls"

// The control centre: its grid's size (also under the island while
// arranging), the way into arranging it and back to its default, and the
// buttons of its top row. A toggles or shortcuts block picks what it carries
// in `BlockInspector`.
SettingsSection {
    id: root

    // Unused: this page has no parts, but `SettingsPanel` sets it on all pages.
    property string tab: ""

    // `SettingsPanel` opens the control centre, then closes the window.
    signal arranging()

    SettingGroup {
        title: Tr.t("Sound")
        note: Tr.t("What the volume sliders reach.")
        hint: Tr.t("Above 100 % the sound is amplified and can distort. The sliders, the volume key and the volume command all stop at the same place.")

        SettingRow {
            label: Tr.t("Volume above 100 %")
            reading: SettingsService.volumeMax > 100
                ? Tr.t("The sliders go to 150 %") : Tr.t("The sliders stop at 100 %")

            ToggleSwitch {
                checked: SettingsService.volumeMax > 100
                onToggled: checked => SettingsService.set("volumeMax", checked ? 150 : 100)
            }
        }
    }

    SettingGroup {
        title: Tr.t("The panel")
        note: Tr.t("A grid of the size chosen here, arranged on the panel itself.")
        hint: Tr.t("Edit shows the grid, its columns and rows under the island, and a card of every block under them. Drag a block onto the cells, pull a corner or scroll to resize it, and drop it on the card to remove it; a click on a toggles or shortcuts block chooses what it carries. Columns come and go on both sides alike, so the blocks stay centred. Escape leaves, and the right button on the panel enters or leaves without opening settings.")

        // The same picker as under the island while arranging.
        SettingRow {
            label: Tr.t("Size")
            reading: Tr.t("Click the cell that should be the grid's corner")

            GridSize {
                bare: true
            }
        }

        SettingRow {
            label: Tr.t("Arrange the control centre")

            Row {
                spacing: 8

                PillButton {
                    text: Tr.t("Default layout")
                    implicitHeight: 30
                    onClicked: ControlsService.restore()
                }

                PillButton {
                    text: Tr.t("Edit")
                    implicitHeight: 30
                    onClicked: {
                        ControlsService.edit(true)
                        root.arranging()
                    }
                }
            }
        }
    }

    SettingGroup {
        title: Tr.t("The song tile")
        note: Tr.t("Song sends a short fingerprint of 12 seconds of what the speakers play, a call included, to Shazam through songrec. Without songrec the tile is not listed.")
    }

    // ── THE TOP ROW ─────────────────────────────────────────────────────────

    SettingGroup {
        title: Tr.t("The top row")
        note: Tr.t("Small buttons over the grid, on the right; the time and the battery go on the left. With none of them, there is no row.")

        SettingBlock {
            TopRowEditor {
                Layout.fillWidth: true
            }
        }
    }
}
