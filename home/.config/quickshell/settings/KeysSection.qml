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

    // ── ADD A BINDING ─────────────────────────────────────────────────────────
    //
    // The form on the compositor's part. A new bind runs a command or opens
    // one of the shell's own actions, always unbound at first (setting the
    // combination on its row after it appears). The service keeps the name
    // unique, so a repeated name just gets a number.
    property string addName: ""
    property string addKind: "command"
    property string addTarget: ""
    property bool adding: false

    readonly property var addKinds: [
        { id: "command", label: Tr.t("Run a command") },
        { id: "shell", label: Tr.t("A shell action") }
    ]

    readonly property var shellActions:
        ShortcutService.catalogue.map(entry => ({ id: entry.name, label: Tr.t(entry.label) }))

    function addReady(): bool {
        if (root.addName.trim() === "")
            return false
        if (root.addKind === "command")
            return root.addTarget.trim() !== ""
        return root.addTarget !== ""
    }

    function clearAdd(): void {
        root.addName = ""
        root.addKind = "command"
        root.addTarget = ""
    }

    function add(): void {
        if (!root.addReady())
            return
        ShortcutService.addCustom(root.addName, root.addKind, root.addTarget)
        root.clearAdd()
    }

    // What the form would add, or why it cannot yet.
    function addStatus(): string {
        if (root.addName.trim() === "")
            return Tr.t("Give it a name.")
        if (root.addKind === "command")
            return root.addTarget.trim() === ""
                ? Tr.t("Write the command to run.")
                : root.addTarget
        return root.addTargetLabel() !== ""
            ? root.addTargetLabel() : Tr.t("Pick one of the shell's own actions.")
    }

    // The friendly name of the chosen shell action.
    function addTargetLabel(): string {
        const row = root.shellActions.find(entry => entry.id === root.addTarget)
        return row ? row.label : ""
    }

    // The shell's own binds matching the filter, by name or combination.
    readonly property var own: ShortcutService.catalogue.filter(entry => {
        const term = root.filter.trim().toLowerCase()
        if (term === "")
            return true
        return Tr.t(entry.label).toLowerCase().includes(term)
            || entry.label.toLowerCase().includes(term)
            || ShortcutService.current(entry.description).toLowerCase().includes(term)
    })

    // The binds "the ones you add" shows, matching the filter.
    readonly property var customs: ShortcutService.customs.map(custom => {
        const split = custom.description.indexOf(" · ")
        const name = split < 0 ? custom.description : custom.description.slice(split + 3)
        const term = root.filter.trim().toLowerCase()
        const shown = term === ""
            || name.toLowerCase().includes(term)
            || custom.combination.toLowerCase().includes(term)
            || custom.target.toLowerCase().includes(term)
        return { description: custom.description, label: name, shown: shown }
    }).filter(entry => entry.shown)

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
        property bool canAdd: false

        Layout.fillWidth: true
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            GroupHeading { id: heading; Layout.fillWidth: true }

            PillButton {
                visible: canAdd
                text: Tr.t("Add a binding")
                icon: "󰐕"
                active: root.adding
                onClicked: root.adding = !root.adding
            }
        }

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

    // Picks one of the shell's own actions for a new custom bind: a button
    // that drops a small searchable menu under it, drawn inside the page so
    // the card below scrolls it away.
    component ShellActionPicker: Item {
        id: picker

        property var actions: []
        property string chosen: ""
        property bool open: false
        property string query: ""

        readonly property string chosenLabel: {
            const row = picker.actions.find(entry => entry.id === picker.chosen)
            return row ? row.label : ""
        }

        readonly property var shown: picker.actions.filter(entry => {
            const term = picker.query.trim().toLowerCase()
            return term === "" || entry.label.toLowerCase().includes(term)
        })

        implicitWidth: 240
        implicitHeight: 28
        z: picker.open ? 8 : 0

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: picker.open || mouse.containsMouse ? Theme.islandSurfaceHover : Theme.island
            border.color: picker.open || mouse.containsMouse ? Theme.accent : Theme.islandBorder
            border.width: 1

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: picker.chosenLabel !== "" ? picker.chosenLabel
                        : Tr.t("Choose an action…")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: picker.chosenLabel !== "" ? Theme.text : Theme.textMuted
                }

                Text {
                    text: "󰅀"
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    color: Theme.textMuted
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    picker.open = !picker.open
                    picker.query = ""
                }
            }
        }

        // ── THE MENU ─────────────────────────────────────────────────────────

        Rectangle {
            visible: picker.open
            y: parent.height + 6
            width: 260
            height: Math.max(78, Math.min(34 + picker.shown.length * 29, 280))
            radius: Theme.radiusMedium
            color: Theme.island
            border.color: Theme.islandBorder
            border.width: 1
            clip: true

            ColumnLayout {
                id: menu

                anchors.fill: parent
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Layout.topMargin: 6
                    Layout.rightMargin: 6
                    implicitHeight: 24
                    radius: Theme.radiusSmall
                    color: field.activeFocus ? Theme.islandSurfaceHover : Theme.island
                    border.color: field.activeFocus ? Theme.accent : Theme.islandBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            text: "󰍉"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: Theme.textMuted
                        }

                        TextInput {
                            id: field
                            Layout.fillWidth: true
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.text
                            selectByMouse: true
                            clip: true
                            onTextEdited: picker.query = field.text
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.bottomMargin: 6
                    clip: true
                    spacing: 1
                    model: picker.shown
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: entry

                        required property var modelData

                        readonly property bool active:
                            entry.modelData.id === picker.chosen

                        width: ListView.view.width
                        height: 28
                        radius: Theme.radiusSmall - 2
                        color: entry.active || entryMouse.containsMouse
                            ? Theme.islandSurfaceHover : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.label
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: entry.active ? Font.DemiBold : Font.Normal
                            color: entry.active ? Theme.accent : Theme.text
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                picker.chosen = entry.modelData.id
                                picker.open = false
                                root.addTarget = entry.modelData.id
                            }
                        }
                    }
                }
            }
        }
    }

    // The form for a new custom bind: a name, whether it runs a command or
    // opens one of the shell's own actions, and the command or action itself.
    // Shown on the "ones you add" tab, opened from the heading's button.
    component AddBindingGroup: SettingGroup {
        title: Tr.t("Add a binding")
        note: Tr.t("A key you add yourself runs a command or opens one of the shell's own actions.")
        hint: Tr.t("The binding starts unbound; give it a key on its row once it appears. Binds you add belong to the profile in use and can be removed again.")

        visible: root.adding

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            // The name, which becomes the row's description.
            Item {
                Layout.fillWidth: true
                implicitHeight: 48

                SettingDivider {}

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    SettingLabel {
                        Layout.fillWidth: true
                        label: Tr.t("Name")
                        reading: root.addName === "" ? Tr.t("The name shown on the row") : ""
                    }

                    Rectangle {
                        implicitWidth: 240
                        implicitHeight: 28
                        radius: Theme.radiusSmall
                        color: nameField.activeFocus ? Theme.islandSurfaceHover : Theme.island
                        border.color: nameField.activeFocus ? Theme.accent : Theme.islandBorder
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        TextInput {
                            id: nameField
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            maximumLength: 40
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                            selectByMouse: true
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            clip: true
                            onTextEdited: root.addName = nameField.text
                            Keys.onReturnPressed: root.add()
                        }
                    }
                }
            }

            // What the binding does.
            Item {
                Layout.fillWidth: true
                implicitHeight: 48

                SettingDivider {}

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    SettingLabel {
                        Layout.fillWidth: true
                        label: Tr.t("What it does")
                        reading: root.addKind === "command"
                            ? Tr.t("Command") : Tr.t("A shell action")
                    }

                    SegmentedControl {
                        options: root.addKinds
                        current: root.addKind
                        onSelected: id => {
                            root.addKind = id
                            root.addTarget = ""
                        }
                    }
                }
            }

            // What to run, or which shell action to open.
            Item {
                Layout.fillWidth: true
                implicitHeight: 48

                SettingDivider {}

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    SettingLabel {
                        Layout.fillWidth: true
                        label: root.addKind === "command"
                            ? Tr.t("Command to run") : Tr.t("Which shell action")
                        reading: root.addTarget !== ""
                            ? (root.addKind === "command"
                                ? root.addTarget : root.addTargetLabel())
                            : (root.addKind === "command"
                                ? Tr.t("For example: kitty -e htop")
                                : Tr.t("For example: the launcher"))
                    }

                    // A command: a text field. A shell action: a picker.
                    Rectangle {
                        visible: root.addKind === "command"
                        implicitWidth: 240
                        implicitHeight: 28
                        radius: Theme.radiusSmall
                        color: cmdField.activeFocus ? Theme.islandSurfaceHover : Theme.island
                        border.color: cmdField.activeFocus ? Theme.accent : Theme.islandBorder
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        TextInput {
                            id: cmdField
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                            selectByMouse: true
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            clip: true
                            onTextEdited: root.addTarget = cmdField.text
                            Keys.onReturnPressed: root.add()
                        }
                    }

                    ShellActionPicker {
                        visible: root.addKind === "shell"
                        actions: root.shellActions
                        chosen: root.addTarget
                    }
                }
            }

            // What the form would add, and the buttons.
            Item {
                Layout.fillWidth: true
                implicitHeight: 46

                SettingDivider {}

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: root.addStatus()
                        elide: Text.ElideRight
                        font.family: root.addKind === "command"
                            && root.addTarget.trim() !== "" ? Theme.fontMono : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: root.addReady() ? Theme.textMuted : Theme.yellow
                    }

                    PillButton {
                        text: Tr.t("Clear")
                        onClicked: root.clearAdd()
                    }

                    PillButton {
                        text: Tr.t("Add")
                        icon: "󰐕"
                        active: true
                        enabled: root.addReady()
                        opacity: enabled ? 1 : 0.4
                        onClicked: root.add()
                    }
                }
            }
        }
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
            if (ShortcutService.customOf(text))
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


    // ── THE ONES YOU ADD ────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "custom"
        spacing: root.spacing

        PartHead {
            title: Tr.t("The ones you add")
            note: Tr.t("Binds you add yourself — a command, or one of the shell's own actions.")
            hint: Tr.t("A bind starts unbound; click its combination to give it a key, or Unbind to clear it. Deleting removes it for good.")
            canAdd: true
        }

        AddBindingGroup {}

        SettingGroup {
            visible: root.customs.length > 0

            Repeater {
                model: root.customs

                ShortcutRow {
                    required property var modelData

                    description: modelData.description
                    label: modelData.label
                    removable: true
                }
            }
        }

        NoMatch {
            visible: root.customs.length === 0 && !root.adding
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
