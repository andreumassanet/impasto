// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S C R A T C H P A D S   S E C T I O N                                  │
// │   scratchpads · a special workspace, its key, icon and command           │
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

// A scratchpad is a special workspace with a name: its key shows or hides it,
// and starts its command on it first when it holds no window. They are stored
// in `overviewScratchpads`; `ShortcutService` writes them for Hyprland, and
// the overview shows each as a tile.
SettingsSection {
    id: root

    // Unused: this page has no parts, but `SettingsPanel` sets it on all pages.
    property string tab: ""

    readonly property var pads: Array.from(SettingsService.overviewScratchpads ?? [])

    function edit(index: int, field: string, value: string): void {
        const next = root.pads.map(pad => Object.assign({}, pad))
        next[index][field] = value
        SettingsService.set("overviewScratchpads", next)
    }

    function remove(index: int): void {
        SettingsService.set("overviewScratchpads", root.pads.filter((pad, at) => at !== index))
    }

    function add(): void {
        let number = root.pads.length + 1
        while (root.pads.some(pad => pad.name === `pad${number}`))
            number++
        const next = root.pads.map(pad => Object.assign({}, pad))
        next.push({ name: `pad${number}`, label: `Scratchpad ${number}`, glyph: "󰐕",
                    keys: "", command: "" })
        SettingsService.set("overviewScratchpads", next)
    }

    // The name is what Hyprland calls the workspace (`special:NAME`), so only
    // letters, digits, - and _ are kept, and no two share one.
    function clean(text: string): string {
        return text.replace(/[^A-Za-z0-9_-]/g, "")
    }

    SettingGroup {
        title: Tr.t("Scratchpads")
        note: Tr.t("Special workspaces you toggle with a key. Each has a name, an icon, a key and what to run.")
        hint: Tr.t("The key opens the scratchpad, or hides it when it is open; when it holds no window, the command starts first. A command is an app, or the path of a script, and runs through the shell, so arguments work. Write the key as Super+Ctrl+M or Super+grave. A key you set here replaces any other bind on it. Leave the command empty for a plain scratchpad you send windows to.")
    }

    Repeater {
        model: ScriptModel {
            values: root.pads
        }

        SettingGroup {
            id: card

            required property var modelData
            required property int index

            title: card.modelData.label || card.modelData.name
            note: `special:${card.modelData.name}`

            SettingField {
                label: Tr.t("Icon")
                reading: Tr.t("One glyph from the icon font, shown on its overview tile")
                value: card.modelData.glyph ?? ""
                onEdited: value => root.edit(card.index, "glyph", value)
            }

            SettingField {
                label: Tr.t("Label")
                reading: Tr.t("What the tile and the key sheet call it")
                value: card.modelData.label ?? ""
                onEdited: value => root.edit(card.index, "label", value)
            }

            SettingField {
                label: Tr.t("Workspace name")
                reading: Tr.t("Letters, digits, - and _; the workspace is special:name")
                alarm: root.pads.some((pad, at) => at !== card.index && pad.name === card.modelData.name)
                value: card.modelData.name ?? ""
                onEdited: value => {
                    const cleaned = root.clean(value)
                    if (cleaned !== "")
                        root.edit(card.index, "name", cleaned)
                }
            }

            SettingField {
                id: keysField

                readonly property string clashWith: ShortcutService.spell(card.modelData.keys) === ""
                    ? "" : ShortcutService.clash(ShortcutService.spell(card.modelData.keys),
                                                  `Workspaces · Scratchpad ${card.modelData.label || card.modelData.name}`)

                label: Tr.t("Key")
                reading: keysField.clashWith !== ""
                    ? Tr.t("Replaces %1").arg(keysField.clashWith)
                    : Tr.t("For example Super+Ctrl+M; empty for none")
                alarm: false
                value: card.modelData.keys ?? ""
                onEdited: value => root.edit(card.index, "keys", value)
            }

            SettingField {
                label: Tr.t("Command")
                reading: Tr.t("An app or the path of a script; empty for none")
                value: card.modelData.command ?? ""
                onEdited: value => root.edit(card.index, "command", value)
            }

            SettingRow {
                label: Tr.t("Open it now")

                PillButton {
                    text: Tr.t("Toggle")
                    icon: "󰖲"
                    implicitWidth: 100
                    implicitHeight: 30
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/scratchpad.sh"),
                                                        card.modelData.name, card.modelData.command ?? ""])
                }
            }

            SettingRow {
                label: Tr.t("Remove")

                PillButton {
                    text: Tr.t("Remove")
                    icon: "󰆴"
                    implicitWidth: 100
                    implicitHeight: 30
                    onClicked: root.remove(card.index)
                }
            }
        }
    }

    SettingGroup {
        title: Tr.t("Add")

        SettingRow {
            label: Tr.t("A new scratchpad")
            reading: Tr.t("Then give it a name, a key and a command")

            PillButton {
                text: Tr.t("Add")
                icon: "󰐕"
                implicitWidth: 100
                implicitHeight: 30
                onClicked: root.add()
            }
        }
    }
}
