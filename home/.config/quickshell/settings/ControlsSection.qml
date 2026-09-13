// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O N T R O L S   S E C T I O N                                        │
// │   control centre · shortcut row and grid                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// The control centre's top row of panel buttons: which are shown, and in what
// order. The session actions are fixed at the left end. Blocks are arranged on
// the control centre itself; each toggles block picks its own switches in
// `BlockInspector`.
SettingsSection {
    id: root

    // Unused: this page has no parts, but `SettingsPanel` sets it on all pages.
    property string tab: ""

    // `SettingsPanel` opens the control centre, then closes the window.
    signal arranging()

    // A panel button: icon, name, reorder arrows and a switch. Not a
    // `SettingRow`, since the arrows only show while the row is on.
    component OrderRow: Item {
        id: row

        property string icon: ""
        property string label: ""
        property bool on: false
        property int at: -1
        property int count: 0

        signal moved(int delta)
        signal switched(bool on)

        Layout.fillWidth: true
        implicitHeight: 48

        SettingDivider {}

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Text {
                Layout.preferredWidth: 20
                horizontalAlignment: Text.AlignHCenter
                visible: row.icon !== ""
                text: row.icon
                font.family: Theme.fontMono
                font.pixelSize: 15
                color: row.on ? Theme.accent : Theme.textMuted
            }

            Text {
                Layout.fillWidth: true
                text: row.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: row.on ? Theme.text : Theme.textMuted
            }

            IconButton {
                icon: "󰅃"
                iconSize: 12
                visible: row.on
                enabled: row.at > 0
                opacity: row.at > 0 ? 1 : 0.3
                onClicked: row.moved(-1)
            }

            IconButton {
                icon: "󰅀"
                iconSize: 12
                visible: row.on
                enabled: row.at < row.count - 1
                opacity: row.at < row.count - 1 ? 1 : 0.3
                onClicked: row.moved(1)
            }

            ToggleSwitch {
                Layout.alignment: Qt.AlignVCenter
                checked: row.on
                onToggled: checked => row.switched(checked)
            }
        }
    }

    SettingGroup {
        title: Tr.t("The panel")
        note: Tr.t("A six by eight grid, arranged on the panel itself.")
        hint: Tr.t("Edit shows the grid with a card of every block, moved by the space between them: drag a block onto the cells, pull a corner or scroll to resize, and drop one on the card to remove it. Escape leaves this mode, the right button on the panel enters or leaves it without opening settings, and a click on a toggles block chooses its switches.")

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

    // ── THE TOP ROW ─────────────────────────────────────────────────────────

    SettingGroup {
        title: Tr.t("The top row")
        note: Tr.t("Session actions always sit on the left. These buttons, which open other panels and this window, fill the row from the right in this order.")

        Repeater {
            model: ControlsService.doorRows

            OrderRow {
                required property var modelData

                icon: modelData.icon
                label: Tr.t(modelData.label)
                on: ControlsService.showsDoor(modelData.id)
                at: ControlsService.buttons.indexOf(modelData.id)
                count: ControlsService.buttons.length
                onMoved: delta => ControlsService.moveDoor(modelData.id, delta)
                onSwitched: on => ControlsService.setDoor(modelData.id, on)
            }
        }
    }
}
