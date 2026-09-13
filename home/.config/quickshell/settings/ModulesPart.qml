// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O D U L E S   P A R T                                                │
// │   module chips · appearance and bar contents                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"
import "../bar/modules"

// The "The bar" part of Bar & Island: how every chip reads (one setting for
// the whole bar), then the bar layout itself (`LayoutEditor`). Settings that
// belong to individual modules are on the Desktop page.
ColumnLayout {
    id: root

    // ── HOW A CHIP READS ────────────────────────────────────────────────────

    SettingGroup {
        title: Tr.t("Chips")
        note: Tr.t("Every piece on the bar follows these unless it was given its own.")
        hint: Tr.t("Icon shows the module's symbol; Ring draws its gauge (charge, volume, countdown) as a circle around the symbol. The figure is the value itself, and On hover shows it only while the pointer is over the chip.")

        SettingTiles {
            label: Tr.t("Shape")
            reading: Tr.t((SettingsService.chipShapes.find(
                entry => entry.id === SettingsService.chipShape) ?? { note: "" }).note)

            Repeater {
                model: SettingsService.chipShapes

                PreviewTile {
                    id: shapeTile

                    required property var modelData

                    caption: Tr.t(shapeTile.modelData.label)
                    selected: SettingsService.chipShape === shapeTile.modelData.id
                    onPicked: SettingsService.set("chipShape", shapeTile.modelData.id)

                    Sample {
                        anchors.centerIn: parent
                        shape: shapeTile.modelData.id
                        ids: ["volume", "battery", "claude"]
                        reveal: SettingsService.chipFigure === "on"
                            || (SettingsService.chipFigure === "hover" && shapeTile.hovered) ? 1 : 0
                    }
                }
            }
        }

        // The hover tile opens when pointed at, demonstrating the setting.
        SettingTiles {
            label: Tr.t("Figure")
            reading: Tr.t((SettingsService.chipFigures.find(
                entry => entry.id === SettingsService.chipFigure) ?? { note: "" }).note)

            Repeater {
                model: SettingsService.chipFigures

                PreviewTile {
                    id: figureTile

                    required property var modelData

                    caption: Tr.t(figureTile.modelData.label)
                    selected: SettingsService.chipFigure === figureTile.modelData.id
                    onPicked: SettingsService.set("chipFigure", figureTile.modelData.id)

                    Sample {
                        anchors.centerIn: parent
                        shape: SettingsService.chipShape
                        ids: ["volume", "battery"]
                        reveal: figureTile.modelData.id === "on"
                            || (figureTile.modelData.id === "hover" && figureTile.hovered) ? 1 : 0
                    }
                }
            }
        }
    }

    // ── WHAT THE BAR CARRIES ────────────────────────────────────────────────
    //
    // The editor draws its own surfaces: the bar, and the catalogue under it.
    SettingGroup {
        title: Tr.t("Layout")
        note: Tr.t("Drag a piece from the catalogue onto the bar.")
        hint: Tr.t("Drop a piece on either half of the bar to place it on that side of the island; drag it along to move it or off the bar to remove it, and click it to give it its own shape and figure. Adjacent modules share a capsule, and a split starts a new one.")
        bare: true

        LayoutEditor {
            Layout.fillWidth: true
        }
    }

    // A capsule of real `ChipFace`s at a given shape and figure, so the
    // preview always matches the bar.
    component Sample: Rectangle {
        id: sample

        property string shape: "icon"
        property var ids: []
        property real reveal: 1

        Behavior on reveal {
            NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic }
        }

        implicitWidth: row.implicitWidth + 8
        implicitHeight: Theme.capsuleHeight
        radius: height / 2
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1

        Row {
            id: row

            x: 4
            height: parent.height

            Repeater {
                model: sample.ids

                ChipFace {
                    required property string modelData

                    anchors.verticalCenter: parent.verticalCenter
                    moduleId: modelData
                    shape: sample.shape
                    reveal: sample.reveal
                }
            }
        }
    }
}
