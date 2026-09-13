// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   K E Y S   P A N E L                                                    │
// │   keybinding cheat sheet                                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"

// A read-only sheet of key bindings: one field over one list, grouped, the
// action on the left and the keys as caps on the right. The field narrows the
// list by action, group or key. Rebinding happens in the settings window.
//
// Built from `ShortcutService.sheet` (the compositor's bind list, grouped).
ColumnLayout {
    id: root

    signal closed()

    spacing: 10

    readonly property var entries: ShortcutService.sheetFind(field.text)
    readonly property int shown: root.entries.filter(entry => !entry.heading).length

    // Reloaded on open, so rebinds made since startup show up.
    Component.onCompleted: {
        HyprlandService.loadBinds()
        field.forceActiveFocus()
    }

    // Nothing on the sheet is pressed, so the arrows scroll rather than select.
    function scroll(pixels: real): void {
        const bottom = Math.max(0, list.contentHeight - list.height)
        list.contentY = Math.max(0, Math.min(bottom, list.contentY + pixels))
    }

    // A key drawn as a keycap: the settings page's, one step smaller.
    component Cap: Rectangle {
        property string label: ""

        implicitWidth: Math.max(24, capText.implicitWidth + 14)
        implicitHeight: 22
        radius: Theme.radiusSmall - 2
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        Text {
            id: capText
            anchors.centerIn: parent
            text: parent.label
            // An arrow is a glyph from the icon font, which only the mono
            // face carries; everything else is a word or a letter.
            readonly property bool glyph: parent.label.codePointAt(0) >= 0xE000
            font.family: capText.glyph ? Theme.fontMono : Theme.fontFamily
            font.pixelSize: capText.glyph ? Theme.fontSizeRegular : Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.text
        }
    }

    // ── FIELD ───────────────────────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: ShortcutService.sheetFieldHeight
        spacing: 12

        Text {
            text: "󰌌"
            font.family: Theme.fontMono
            font.pixelSize: 17
            color: Theme.accent
        }

        TextInput {
            id: field

            Layout.fillWidth: true
            font.family: Theme.fontFamily
            font.pixelSize: 16
            color: Theme.text
            clip: true
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText

            onTextChanged: list.contentY = 0
            Keys.onUpPressed: root.scroll(-ShortcutService.sheetRowHeight)
            Keys.onDownPressed: root.scroll(ShortcutService.sheetRowHeight)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                    root.scroll((event.key === Qt.Key_PageUp ? -1 : 1) * list.height * 0.8)
                    event.accepted = true
                }
            }
            // Escape is handled by the island for every panel.

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text === ""
                text: "Find a key, or what it does…"
                color: Theme.textMuted
                font: field.font
            }
        }

        Text {
            text: field.text === "" ? `${ShortcutService.sheetCount} keys`
                : `${root.shown} of ${ShortcutService.sheetCount}`
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.islandBorder
    }

    // ── LIST ────────────────────────────────────────────────────────────────

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent
            visible: root.entries.length === 0
            text: HyprlandService.binds.length === 0 ? "Reading the keys…" : "No key does that."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular
            color: Theme.textMuted
        }

        // A few dozen rows, so a plain column rather than a view that builds
        // them as they scroll in.
        Flickable {
            id: list

            anchors.fill: parent
            clip: true
            contentHeight: column.height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: column

                width: list.width

                Repeater {
                    model: root.entries

                    Item {
                        id: entry

                        required property var modelData

                        width: column.width
                        height: entry.modelData.heading
                            ? ShortcutService.sheetHeadingHeight : ShortcutService.sheetRowHeight

                        Text {
                            visible: entry.modelData.heading
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: entry.modelData.heading ? entry.modelData.name.toUpperCase() : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                            color: Theme.accent
                        }

                        Rectangle {
                            visible: !entry.modelData.heading
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: rowHover.hovered ? Theme.islandSurface : "transparent"

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                            HoverHandler { id: rowHover }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 16

                                Text {
                                    Layout.fillWidth: true
                                    text: entry.modelData.action ?? ""
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeRegular
                                    color: Theme.text
                                }

                                Row {
                                    spacing: 4

                                    Repeater {
                                        model: entry.modelData.caps ?? []

                                        Cap {
                                            required property string modelData
                                            label: modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
