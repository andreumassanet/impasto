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
        title: Tr.t("Clicks and the clock")
        note: Tr.t("Two ways the control centre answers.")

        SettingRow {
            label: Tr.t("Menu on the label")
            reading: SettingsService.tileMenuOnLabel
                ? Tr.t("On a tile with a menu the icon toggles and the rest opens the menu")
                : Tr.t("A tile toggles wherever it is pressed; its arrow opens the menu")

            ToggleSwitch {
                checked: SettingsService.tileMenuOnLabel
                onToggled: checked => SettingsService.set("tileMenuOnLabel", checked)
            }
        }

        SettingRow {
            label: Tr.t("Time in the top row")
            reading: Tr.t("The time stays in view in the middle of the top row while the control centre is open")

            ToggleSwitch {
                checked: SettingsService.controlsClock
                onToggled: checked => SettingsService.set("controlsClock", checked)
            }
        }
    }

    SettingGroup {
        title: Tr.t("Extra tiles")
        note: Tr.t("Toggles that call tools outside the shell. A tile whose tool is not installed is not listed.")

        SettingRow {
            label: Tr.t("Search a region with Google Lens")
            reading: Tr.t("The region is uploaded to uguu.se, a temporary public host")

            ToggleSwitch {
                checked: SettingsService.lensUpload
                onToggled: checked => SettingsService.set("lensUpload", checked)
            }
        }
    }

    // ── THE TOP ROW ─────────────────────────────────────────────────────────

    SettingGroup {
        title: Tr.t("The top row")
        note: Tr.t("Small buttons over the grid, on either side. With none, there is no row.")

        SettingBlock {
            TopRowEditor {
                Layout.fillWidth: true
            }
        }
    }
}
