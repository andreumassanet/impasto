// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S H O R T C U T   R O W                                                │
// │   one key, and how it is changed                                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// Modifiers are toggled as chips and only the key itself is captured.
//
// Capturing the whole combination is not possible: Hyprland binds are global,
// so SUPER + T fires its bind and never reaches this window. An empty submap
// entered during capture would avoid that, but Hyprland cannot register one at
// runtime (`hl.submap` is nil and `dispatch submap` rejects undeclared names),
// and declaring one in keybinds.lua would strand the keyboard if the shell
// died mid-capture. A bare key is safe because nothing is bound to one.
//
// The row is one line at rest; clicking the combination opens the editor
// under it. Sits in a `SettingGroup`'s card.
Item {
    id: root

    // The bind's description, which is how the profile keys it.
    property string description: ""
    property string label: ""

    readonly property string current: ShortcutService.current(root.description)

    // A mouse button: shown, and not opened.
    readonly property bool fixed: ShortcutService.fixed(root.description)

    property bool editing: false

    // What is being built while the row is open, seeded from what is on it.
    property var mods: []
    property string key: ""

    readonly property string draft: root.mods.concat([root.key]).join(" + ")

    readonly property string clash:
        root.key === "" ? "" : ShortcutService.clash(root.draft, root.description)

    function begin(): void {
        const known = HyprlandService.modifierNames.map(entry => entry.name)
        const parts = root.current.split("+")
            .map(part => part.trim())
            .filter(part => part !== "")
        root.mods = parts.filter(part => known.indexOf(part.toUpperCase()) >= 0)
                         .map(part => part.toUpperCase())
        root.key = parts.filter(part => known.indexOf(part.toUpperCase()) < 0)[0] ?? ""
        root.editing = true
    }

    function toggleMod(mod: string): void {
        // Kept in the compositor's modifier order, so a combination is always
        // spelled the same way for the clash check.
        const has = root.mods.indexOf(mod) >= 0
        root.mods = HyprlandService.modifierNames
            .map(entry => entry.name)
            .filter(entry => entry === mod ? !has : root.mods.indexOf(entry) >= 0)
    }

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + (root.editing ? 28 : 18)

    SettingDivider {}

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: Tr.t(root.label)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.text
            }

            // The combination doubles as the edit button.
            Rectangle {
                id: combination

                readonly property bool lit:
                    root.editing || (comboMouse.containsMouse && !root.fixed)

                implicitWidth: Math.max(104, shown.implicitWidth + 18)
                implicitHeight: 22
                radius: Theme.radiusSmall - 2
                color: combination.lit ? Theme.islandSurfaceHover : Theme.island
                border.color: combination.lit ? Theme.accent : Theme.islandBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                Text {
                    id: shown

                    anchors.centerIn: parent
                    text: root.current !== "" ? root.current : Tr.t("unbound")
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: root.current !== "" ? Theme.text : Theme.textMuted
                }

                MouseArea {
                    id: comboMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.fixed
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.editing)
                            root.editing = false
                        else
                            root.begin()
                    }
                }
            }
        }

        // ── THE EDITOR ──────────────────────────────────────────────────────

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.editing
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Repeater {
                    model: HyprlandService.modifierNames

                    Rectangle {
                        id: chip

                        required property var modelData
                        readonly property bool on: root.mods.indexOf(chip.modelData.name) >= 0

                        implicitWidth: 64
                        implicitHeight: 28
                        radius: Theme.radiusSmall
                        color: chip.on ? Theme.accent
                            : (chipMouse.containsMouse ? Theme.islandSurfaceHover : Theme.island)
                        border.color: chip.on ? Theme.accent : Theme.islandBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: chip.modelData.name
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: chip.on ? Font.DemiBold : Font.Normal
                            color: chip.on ? Theme.accentText : Theme.textMuted
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleMod(chip.modelData.name)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: Theme.radiusSmall
                    color: keyInput.activeFocus ? Theme.islandSurfaceHover : Theme.island
                    border.color: keyInput.activeFocus ? Theme.accent : Theme.islandBorder
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (keyInput.activeFocus)
                                return Tr.t("Press a key…")
                            return root.key !== "" ? root.key
                                : Tr.t("Click, then press a key")
                        }
                        font.family: root.key !== "" && !keyInput.activeFocus
                            ? Theme.fontMono : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: keyInput.activeFocus ? Theme.accent
                            : (root.key !== "" ? Theme.text : Theme.textMuted)
                    }

                    Item {
                        id: keyInput

                        anchors.fill: parent

                        // `keyName` returns "" for modifiers, so holding Shift
                        // to reach a character does not end the capture.
                        Keys.onPressed: event => {
                            const named = ShortcutService.keyName(event.key)
                            if (named === "")
                                return
                            root.key = named
                            event.accepted = true
                            keyInput.focus = false
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: keyInput.forceActiveFocus()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (root.key === "")
                            return Tr.t("Pick the key, and any modifiers to hold with it.")
                        if (root.clash !== "")
                            return `${root.draft} ${Tr.t("is already")} ${root.clash}. ${Tr.t("Both would fire.")}`
                        return root.draft
                    }
                    wrapMode: Text.WordWrap
                    font.family: root.key === "" || root.clash !== ""
                        ? Theme.fontFamily : Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: root.clash !== "" ? Theme.yellow : Theme.textMuted
                }

                PillButton {
                    text: Tr.t("Cancel")
                    implicitWidth: 84
                    implicitHeight: 28
                    onClicked: root.editing = false
                }

                PillButton {
                    text: Tr.t("Apply")
                    icon: "󰄬"
                    active: true
                    implicitWidth: 92
                    implicitHeight: 28
                    enabled: root.key !== "" && root.draft !== root.current
                    opacity: enabled ? 1 : 0.4
                    onClicked: {
                        ShortcutService.rebind(root.description, root.draft)
                        root.editing = false
                    }
                }
            }
        }
    }
}
