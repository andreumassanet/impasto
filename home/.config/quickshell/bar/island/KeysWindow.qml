// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   K E Y S   W I N D O W                                                  │
// │   every key in cards, in a window of its own                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../components"
import "../../services"

// The key sheet as a window, beside the island's `KeysPanel`: every group of
// keys in its own card, stacked in columns. Type to filter; the first Escape
// clears the filter, the next closes it. A regular toplevel like settings, so
// Hyprland closes, floats and tiles it like any other; `windowrules.lua`
// floats and sizes it, matched on the title.
FloatingWindow {
    id: root

    CornerGuard {}

    // Kept in sync with `visible` both ways, so closing the window from the
    // compositor resets it and it can be opened again.
    property bool shown: false

    function toggle(): void { root.shown = !root.shown }

    property string filter: ""

    readonly property int columnCount: 3

    readonly property var groups: ShortcutService.sheetGroups(root.filter)

    // Masonry: each group goes to the column with the fewest rows so far.
    readonly property var columns: {
        const columns = Array.from({ length: root.columnCount }, () => ({ groups: [], rows: 0 }))
        for (const group of root.groups) {
            const shortest = columns.reduce((best, column) => column.rows < best.rows ? column : best)
            shortest.groups.push(group)
            shortest.rows += group.rows.length + 2
        }
        return columns.map(column => column.groups)
    }

    // Matched by the window rule in `windowrules.lua`.
    title: "Keys"

    implicitWidth: 1240
    implicitHeight: 820

    color: Theme.island
    visible: root.shown

    onVisibleChanged: {
        if (root.visible) {
            HyprlandService.loadBinds()
            field.text = ""
            root.filter = ""
            field.forceActiveFocus()
        } else if (root.shown) {
            root.shown = false
        }
    }

    Item {
        anchors.fill: parent

        ColumnLayout {
            id: column

            anchors.fill: parent
            anchors.margins: Theme.panelPadding + Theme.radiusSmall
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Text {
                    text: Tr.t("Keys")
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSizeWidget
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                // impasto's keys and the user's own, when there are any of
                // the second.
                SegmentedControl {
                    visible: ShortcutService.sheetTabbed
                    Layout.leftMargin: Theme.panelPadding
                    options: ShortcutService.sheetTabs
                    current: ShortcutService.sheetTab
                    onSelected: id => ShortcutService.sheetTab = id
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 320
                    Layout.preferredHeight: ShortcutService.sheetFieldHeight
                    radius: Theme.radiusPill
                    color: Theme.islandSurface

                    TextInput {
                        id: field

                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.text
                        clip: true
                        onTextEdited: root.filter = text
                        // The first Escape clears the filter, the next closes.
                        Keys.onEscapePressed: {
                            if (root.filter === "") {
                                root.shown = false
                            } else {
                                text = ""
                                root.filter = ""
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: field.text === ""
                            text: Tr.t("Find a key, or what it does…")
                            font: field.font
                            color: Theme.textMuted
                        }
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: columnsRow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: columnsRow

                    width: parent.width
                    spacing: 16

                    Repeater {
                        model: root.columns

                        Column {
                            id: stack

                            required property var modelData

                            width: (columnsRow.width - (root.columnCount - 1) * columnsRow.spacing) / root.columnCount
                            spacing: 16

                            Repeater {
                                model: stack.modelData

                                Rectangle {
                                    id: card

                                    required property var modelData

                                    width: stack.width
                                    height: cardColumn.implicitHeight + 2 * 16
                                    radius: Theme.radiusLarge
                                    color: Theme.islandSurface

                                    ColumnLayout {
                                        id: cardColumn

                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 16
                                        spacing: 10

                                        Text {
                                            Layout.bottomMargin: 2
                                            text: card.modelData.name.toUpperCase()
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Bold
                                            font.letterSpacing: 1
                                            color: Theme.accent
                                        }

                                        Repeater {
                                            model: card.modelData.rows

                                            RowLayout {
                                                id: keyRow

                                                required property var modelData

                                                Layout.fillWidth: true
                                                spacing: 12

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: keyRow.modelData.action
                                                    wrapMode: Text.WordWrap
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Theme.text
                                                }

                                                Row {
                                                    spacing: 4

                                                    Repeater {
                                                        model: keyRow.modelData.caps

                                                        Rectangle {
                                                            required property string modelData

                                                            width: Math.max(26, capLabel.implicitWidth + 14)
                                                            height: 24
                                                            radius: Theme.radiusSmall
                                                            color: Theme.islandSurfaceHover
                                                            border.color: Theme.islandBorder

                                                            Text {
                                                                id: capLabel

                                                                anchors.centerIn: parent
                                                                text: parent.modelData
                                                                // An arrow is a glyph from the icon font,
                                                                // which only the mono face carries.
                                                                readonly property bool glyph: text.codePointAt(0) >= 0xE000
                                                                font.family: glyph ? Theme.fontMono : Theme.fontFamily
                                                                font.pixelSize: glyph ? Theme.fontSizeRegular : Theme.fontSizeLabel
                                                                font.weight: Font.DemiBold
                                                                color: Theme.text
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
                }
            }
        }
    }
}
