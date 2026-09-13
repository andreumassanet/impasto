// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I N P U T   S E C T I O N                                              │
// │   keyboard and pointer settings                                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// Keyboard and pointer. Stored in the shell's settings and pushed to Hyprland
// at login and after every reload; `hypr/modules/input.lua` holds the
// defaults.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    Component.onCompleted: {
        CompositorService.load()
        CompositorService.loadLayouts()
        CompositorService.loadShake()
    }

    // "palette" follows the accent; the rest are fixed. compositor.py does the
    // recolouring.
    readonly property var cursorColors: [
        { id: "palette", label: Tr.t("Palette"), swatch: Theme.accent, palette: true },
        { id: "#000000", label: Tr.t("Black"),  swatch: "#000000" },
        { id: "#ffffff", label: Tr.t("White"),  swatch: "#ffffff" },
        { id: "#e5484d", label: Tr.t("Red"),    swatch: "#e5484d" },
        { id: "#f76b15", label: Tr.t("Orange"), swatch: "#f76b15" },
        { id: "#f5c518", label: Tr.t("Yellow"), swatch: "#f5c518" },
        { id: "#46a758", label: Tr.t("Green"),  swatch: "#46a758" },
        { id: "#3b82f6", label: Tr.t("Blue"),   swatch: "#3b82f6" },
        { id: "#8b5cf6", label: Tr.t("Purple"), swatch: "#8b5cf6" },
        { id: "#e93d82", label: Tr.t("Pink"),   swatch: "#e93d82" }
    ]

    readonly property string switchOption:
        CompositorService.value("input:kb_options", "")

    readonly property int layoutCount:
        CompositorService.value("input:kb_layout", "us")
            .split(",").filter(entry => entry.trim() !== "").length


    // ── KEYBOARD ────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "keyboard"
        spacing: root.spacing

        SettingGroup {
            title: Tr.t("Layouts")
            note: Tr.t("Loaded in this order; the first is active at login.")

            LayoutPicker {
                current: CompositorService.value("input:kb_layout", "us")
                onChanged: value => CompositorService.remember("input:kb_layout", value)
            }

            // Locked rather than hidden while only one layout is loaded.
            SettingRow {
                label: Tr.t("Switch between them")
                locked: root.layoutCount <= 1
                reason: Tr.t("Only one layout is loaded")

                SegmentedControl {
                    options: CompositorService.layoutSwitches.map(
                        entry => ({ id: entry.id, label: Tr.t(entry.label) }))
                    current: root.switchOption
                    onSelected: id => CompositorService.remember("input:kb_options", id)
                }
            }
        }

        SettingGroup {
            title: Tr.t("Typing")
            note: Tr.t("How fast a held key repeats, once it has started.")

            SettingSlider {
                label: Tr.t("Key repeat rate")
                value: CompositorService.value("input:repeat_rate", 25)
                from: 10
                to: 60
                unit: "/s"
                onMoved: value => CompositorService.remember("input:repeat_rate", Math.round(value))
            }
        }
    }


    // ── POINTER ─────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "pointer"
        spacing: root.spacing

        SettingGroup {
            title: Tr.t("Pointer")
            note: Tr.t("Zero is the device's native speed; either side adjusts libinput's acceleration.")

            SettingSlider {
                label: Tr.t("Sensitivity")
                value: CompositorService.value("input:sensitivity", 0)
                from: -1
                to: 1
                stepSize: 0.05
                decimals: 2
                onMoved: value => CompositorService.remember("input:sensitivity", value.toFixed(2))
            }
        }

        SettingGroup {
            title: Tr.t("The cursor")
            note: Tr.t("One vector shape, sharp at any size — Palette follows the wallpaper.")
            hint: Tr.t("Colour and size are applied with hyprctl setcursor, so every application updates at once and Palette follows wallpaper changes. Shake to find briefly enlarges the pointer when you shake the mouse; it needs the hypr-dynamic-cursors plugin (./setup plugins).")

            // Swatches, wrapping, rather than tiles; the chosen one is ringed.
            SettingTiles {
                label: Tr.t("Cursor colour")

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.cursorColors

                        Rectangle {
                            id: colourChip

                            required property var modelData

                            readonly property bool taken:
                                SettingsService.cursorColor === colourChip.modelData.id

                            width: chipRow.implicitWidth + 24
                            height: 30
                            radius: height / 2
                            color: chipMouse.containsMouse
                                ? Theme.islandSurfaceHover : Theme.island
                            border.color: colourChip.taken ? Theme.accent : Theme.islandBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                            Row {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: 7

                                // The Palette swatch gets a thicker ring to
                                // mark it as the live accent.
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
                                    radius: width / 2
                                    color: colourChip.modelData.swatch
                                    border.color: colourChip.modelData.palette
                                        ? Theme.accentText : Theme.hairline
                                    border.width: colourChip.modelData.palette ? 2 : 1
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: colourChip.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel
                                    color: colourChip.taken ? Theme.accent : Theme.text
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsService.set(
                                    "cursorColor", colourChip.modelData.id)
                            }
                        }
                    }
                }
            }

            SettingSlider {
                label: Tr.t("Cursor size")
                value: SettingsService.cursorSize
                from: 16
                to: 48
                unit: " px"
                reading: SettingsService.cursorSize === 24
                    ? Tr.t("24 px — the default")
                    : `${SettingsService.cursorSize} px`
                onMoved: value => SettingsService.set("cursorSize", Math.round(value))
            }

            // Locked, with the reason, when hypr-dynamic-cursors is not loaded.
            SettingRow {
                label: Tr.t("Shake to find")
                locked: !CompositorService.shakeAvailable
                reason: Tr.t("Needs the cursor plugin — run ./setup plugins")

                ToggleSwitch {
                    checked: SettingsService.shakeToFind
                    onToggled: checked => SettingsService.set("shakeToFind", checked)
                }
            }
        }
    }
}
