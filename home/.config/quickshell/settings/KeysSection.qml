// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   K E Y S   S E C T I O N                                                │
// │   every binding hyprland has, with what it does                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// Bindings are read from the running compositor. Lua binds are closures, so
// hyprctl reports their dispatcher as `__lua`; the description every bind in
// keybinds.lua carries is what identifies it.
//
// Every profile holds a combination for every bind and keybinds.lua binds the
// active profile's (`ShortcutService`), so the shell's and the compositor's
// keys are both edited here. Mouse binds are shown but not editable.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    Component.onCompleted: HyprlandService.loadBinds()

    // Whether a description belongs to one of the shell's own binds.
    function mine(description: string): bool {
        return ShortcutService.catalogue.some(entry => entry.description === description)
    }

    // Shared by the search field on both parts.
    property string filter: ""

    // The shell's own binds matching the filter, by name or combination.
    readonly property var own: ShortcutService.catalogue.filter(entry => {
        const term = root.filter.trim().toLowerCase()
        if (term === "")
            return true
        return Tr.t(entry.label).toLowerCase().includes(term)
            || entry.label.toLowerCase().includes(term)
            || ShortcutService.current(entry.description).toLowerCase().includes(term)
    })

    // ── SEARCH ──────────────────────────────────────────────────────────────
    //
    // Placed on both parts. Kept visually quieter than the sidebar's search,
    // which moves between sections rather than within one.
    component BindSearch: Rectangle {
        Layout.fillWidth: true
        Layout.maximumWidth: 280
        Layout.leftMargin: 4
        implicitHeight: 26
        radius: Theme.radiusSmall
        color: field.activeFocus ? Theme.island : "transparent"
        border.color: field.activeFocus ? Theme.accent : Theme.hairline
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            spacing: 8

            Text {
                text: "󰍉"
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: Theme.textMuted
            }

            TextInput {
                id: field

                Layout.fillWidth: true
                text: root.filter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.text
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                clip: true

                onTextEdited: root.filter = field.text
                Keys.onEscapePressed: { field.text = ""; root.filter = "" }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: Tr.t("Find a key or an action")
                    font: field.font
                    color: Theme.textMuted
                }
            }

            Text {
                visible: root.filter !== ""
                text: "󰅖"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.textMuted

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { field.text = ""; root.filter = "" }
                }
            }
        }
    }

    // The part's heading over the search field, closer to it than the gap
    // between groups.
    component PartHead: ColumnLayout {
        property alias title: heading.title
        property alias note: heading.note
        property alias hint: heading.hint

        Layout.fillWidth: true
        spacing: 7

        GroupHeading { id: heading }
        BindSearch {}
    }

    component NoMatch: Text {
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.bottomMargin: 12
        horizontalAlignment: Text.AlignHCenter
        text: Tr.t("No binding matches that")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted
    }

    function matches(combination: string, action: string, category: string): bool {
        const term = root.filter.trim().toLowerCase()
        if (term === "")
            return true
        // Matches the combination as well as the description.
        return action.toLowerCase().includes(term)
            || category.toLowerCase().includes(term)
            || combination.toLowerCase().includes(term)
    }

    // Built from `ShortcutService.table` rather than the compositor's list, so
    // a bind the profile leaves unbound still has a row. Descriptions are
    // "Category · Action".
    readonly property var groups: {
        const order = []
        const buckets = ({})
        for (const row of ShortcutService.table) {
            const text = row.description
            const split = text.indexOf(" · ")
            const category = split < 0 ? "Other" : text.slice(0, split)
            const action = split < 0 ? (text || "—") : text.slice(split + 3)
            if (root.mine(text))
                continue
            if (!root.matches(row.combination, action, category))
                continue
            if (!buckets[category]) {
                buckets[category] = []
                order.push(category)
            }
            buckets[category].push({ description: text, action: action })
        }
        return order.map(name => ({ name: name, items: buckets[name] }))
    }


    // ── THE SHELL'S OWN ─────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "shell"
        spacing: root.spacing

        PartHead {
            title: Tr.t("The shell's own")
            note: Tr.t("Click a combination to change it. Every key here belongs to the profile in use.")
            hint: Tr.t("Each profile has its own complete set of keys. A combination already in use is allowed, since Hyprland fires both binds, but the row warns you before you apply it.")
        }

        SettingGroup {
            visible: root.own.length > 0

            Repeater {
                model: root.own

                ShortcutRow {
                    required property var modelData

                    description: modelData.description
                    label: modelData.label
                }
            }
        }

        NoMatch {
            visible: root.own.length === 0
        }
    }


    // ── THE COMPOSITOR'S ────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "compositor"
        spacing: root.spacing

        PartHead {
            title: Tr.t("The compositor's")
            note: Tr.t("Windows, workspaces, the media keys, the screen off — changed the same way, and kept in the same profile.")
            hint: Tr.t("The shell writes these to a file keybinds.lua reads, so applying a change reloads Hyprland. Mouse bindings are shown but cannot be rebound here.")
        }

        NoMatch {
            visible: root.groups.length === 0
        }

        // A Repeater, not a ListView: the page already scrolls, and a nested
        // viewport would compete for the wheel.
        Repeater {
            model: root.groups

            SettingGroup {
                id: group

                required property var modelData

                title: Tr.t(group.modelData.name)

                Repeater {
                    model: group.modelData.items

                    ShortcutRow {
                        required property var modelData

                        description: modelData.description
                        label: modelData.action
                    }
                }
            }
        }
    }
}
