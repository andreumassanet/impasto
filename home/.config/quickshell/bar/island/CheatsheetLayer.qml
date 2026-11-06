// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C H E A T S H E E T   L A Y E R                                        │
// │   every key in cards, over the blurred desktop                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import "../../theme"
import "../../components"
import "../../services"

// The key sheet as a layer, beside the island's `KeysPanel`: every group of
// keys in its own card, stacked in columns. Type to filter; Escape or a click
// outside closes it. It slides up from the bottom over the blurred desktop
// behind its translucent sheet (the `impasto-cheatsheet` layer rule in
// `windowrules.lua`); only the sheet takes input.
PanelWindow {
    id: root
    CornerGuard {}

    signal dismissed()

    property string filter: ""

    readonly property int columnCount: 3

    // The island sheet's matching: every term of the filter begins a word.
    readonly property var terms: root.filter.toLowerCase().split(/[\s+]+/).filter(term => term !== "")

    // Each group once, rows that say the same thing with the same keys once
    // (Super_L and Super_R), narrowed by the filter.
    readonly property var groups: ShortcutService.sheet
        .map(group => {
            const seen = new Set()
            return {
                name: group.name,
                rows: group.rows.filter(row => {
                    const label = `${row.action}|${row.caps.join("+").replace(/_[LR]$/i, "")}`
                    if (seen.has(label))
                        return false
                    seen.add(label)
                    const words = ShortcutService.sheetWords(group, row)
                    return root.terms.every(term => words.some(word => word.startsWith(term)))
                })
            }
        })
        .filter(group => group.rows.length > 0)

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

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: sheet }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "impasto-cheatsheet"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Component.onCompleted: {
        HyprlandService.loadBinds()
        field.forceActiveFocus()
    }

    // A click outside the sheet closes it.
    HyprlandFocusGrab {
        active: true
        windows: [root]
        onCleared: root.dismissed()
    }

    Rectangle {
        id: sheet

        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 1320)
        height: Math.min(parent.height - 120, column.implicitHeight + 2 * 28)
        radius: Theme.radiusLarge + 8
        // Over the layer's ignore_alpha (0.3, windowrules.lua), so it is blurred.
        color: Qt.alpha(Theme.island, 0.62)
        border.color: Theme.islandBorder

        ColumnLayout {
            id: column

            anchors.fill: parent
            anchors.margins: 28
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Text {
                    text: "Keybinds"
                    font.family: Theme.fontDisplay
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Item { Layout.fillWidth: true }

                // Core and Custom (Settings → Keys → The key sheet).
                SegmentedControl {
                    visible: SettingsService.keysTabs
                    Layout.alignment: Qt.AlignVCenter
                    options: [
                        { id: "core", label: `${Tr.t("Core")} · ${ShortcutService.tabCount("core")}` },
                        { id: "custom", label: `${Tr.t("Custom")} · ${ShortcutService.tabCount("custom")}` }
                    ]
                    current: ShortcutService.sheetTab
                    onSelected: id => ShortcutService.sheetTab = id
                }

                Rectangle {
                    Layout.preferredWidth: 320
                    Layout.preferredHeight: 38
                    radius: 19
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
                                root.dismissed()
                            } else {
                                text = ""
                                root.filter = ""
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: field.text === ""
                            text: "Find a key or what it does…"
                            font: field.font
                            color: Theme.textMuted
                        }
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: columnsRow.implicitHeight
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
                                    color: Qt.alpha(Theme.islandSurface, 0.7)

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
                                                            radius: 7
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
