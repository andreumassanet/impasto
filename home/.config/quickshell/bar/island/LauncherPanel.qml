// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L A U N C H E R   P A N E L                                            │
// │   launcher · apps, calculator, windows, timer, clipboard                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// Application launcher. The first character picks the mode: arithmetic, open
// windows, a countdown, the clipboard history, or the shell's own actions.
ColumnLayout {
    id: root

    // The query lives in the service: with `launcherFits` on, the panel's
    // height depends on it, and the island needs that before the panel exists.
    readonly property var results: LauncherService.results
    readonly property var mode: LauncherService.modeFor(LauncherService.query)

    signal closed()
    // `>` lists panels as rows; picking one hands the island over.
    signal panelRequested(string panel)
    signal settingsRequested()

    spacing: LauncherService.gap

    // Created on open, so this is where the field takes focus; otherwise the
    // window is focusable but nothing inside receives keys.
    //
    // The window list and the application index are refreshed here too. The
    // index is otherwise built once, when `LauncherService` is first touched,
    // and would miss anything installed since. Refreshing on open is cheaper
    // than watching the XDG directories; the new list lands about 50 ms later.
    Component.onCompleted: {
        searchField.forceActiveFocus()
        HyprlandService.loadClients()
        LauncherService.refresh()
    }

    // Cleared on the way out, not on the way in: the island is sized from the
    // query a frame before this panel is built, so clearing it on open would
    // size the island for the last search and then resize it.
    Component.onDestruction: LauncherService.query = ""

    // Wraps around at both ends.
    function move(delta: int): void {
        const count = root.results.length
        if (count === 0)
            return
        resultList.currentIndex = (resultList.currentIndex + delta + count) % count
        resultList.positionViewAtIndex(resultList.currentIndex, ListView.Contain)
    }

    function kindColour(kind: string): color {
        switch (kind) {
        case "calculation": return Theme.green
        case "action": return Theme.yellow
        case "timer": return Theme.blue
        case "window": return Theme.blue
        default: return Theme.accent
        }
    }

    // Two kinds are not handed to the service. Panels and settings go up to
    // the island. A mode switches the field to that mode and keeps the
    // launcher open. Everything else the service runs, and the launcher closes.
    function run(entry: var): void {
        if (!entry)
            return
        if (entry.kind === "panel") {
            if (entry.panel === "")
                root.settingsRequested()
            else
                root.panelRequested(entry.panel)
            return
        }
        if (entry.kind === "mode") {
            LauncherService.query = entry.sigil
            searchField.forceActiveFocus()
            return
        }
        LauncherService.activate(entry)
        root.closed()
    }

    function activateSelected(): void {
        root.run(root.results[resultList.currentIndex])
    }

    // Only clipboard entries can be forgotten: they are recorded without being
    // chosen, so a mistake needs a way out. The panel stays open, since
    // deleting usually means deleting several.
    function forgetSelected(): void {
        if (root.mode.id !== "clipboard")
            return
        const entry = root.results[resultList.currentIndex]
        if (entry)
            ClipboardService.forget(entry.id)
    }

    // ── FIELD ───────────────────────────────────────────────────────────────
    //
    // Text on the panel's own black with a rule underneath, not a bordered
    // box: the field always has focus, so a focus ring would never turn off.
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: LauncherService.fieldHeight
        spacing: LauncherService.gap

        // The current mode's glyph rather than a magnifier.
        Text {
            text: root.mode.icon
            font.family: Theme.fontMono
            font.pixelSize: 17
            color: Theme.accent

            Behavior on text { enabled: false }
        }

        TextInput {
            id: searchField

            Layout.fillWidth: true
            text: LauncherService.query
            font.family: Theme.fontFamily
            font.pixelSize: 16
            color: Theme.text
            clip: true
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText

            onTextEdited: LauncherService.query = text
            Keys.onReturnPressed: root.activateSelected()
            Keys.onEnterPressed: root.activateSelected()
            Keys.onUpPressed: root.move(-1)
            Keys.onDownPressed: root.move(1)
            // Shift+Delete: plain Delete edits the text, and this cannot be
            // undone.
            Keys.onDeletePressed: event => {
                if (event.modifiers & Qt.ShiftModifier) {
                    root.forgetSelected()
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }
            // Escape is handled by the island for every panel.

            // The query can be set from outside (a key that opens the launcher
            // in a mode). Typing breaks the `text` binding, so it is resynced
            // here, or the field would show a stale query.
            Connections {
                target: LauncherService

                function onQueryChanged(): void {
                    if (searchField.text !== LauncherService.query)
                        searchField.text = LauncherService.query
                }
            }

            // Only while the field is empty; it would draw over a typed sigil.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Search…"
                visible: searchField.text === ""
                color: Theme.textMuted
                font: searchField.font
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.islandBorder
    }

    // Explicit empty state. In a sigil mode, usually only the sigil has been
    // typed so far.
    Text {
        Layout.fillWidth: true
        visible: root.results.length === 0 && LauncherService.query !== ""
        text: root.mode.empty
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted
    }

    ListView {
        id: resultList

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: LauncherService.rowSpacing
        model: ScriptModel {
            values: root.results

            // Back to the top once the rows have landed, not when the list
            // changes: a row inserted above the selection would shift it.
            // Something is always selected, so Enter always runs a result.
            onValuesChanged: {
                resultList.currentIndex = 0
                resultList.positionViewAtBeginning()
            }
        }
        boundsBehavior: Flickable.StopAtBounds
        // The delegate paints the selection itself; no separate highlight.
        currentIndex: 0

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index

            // Pointer and keyboard share one selection, so Enter always runs
            // what is lit.
            readonly property bool selected: ListView.view.currentIndex === row.index

            width: ListView.view.width
            height: LauncherService.rowHeight
            radius: Theme.radiusSmall
            color: row.selected ? Theme.islandSurfaceHover : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 12
                spacing: 12

                // Applications get their themed icon; other kinds get a glyph
                // in a tinted disc.
                Item {
                    id: badge

                    // Named rather than reached through `parent`, which inside
                    // this binding is the row.
                    readonly property bool isApp: row.modelData.kind === "app"
                    readonly property string iconSource: badge.isApp && row.modelData.icon
                        ? Quickshell.iconPath(row.modelData.icon, true) : ""

                    // Copied images show a thumbnail: two screenshots often
                    // share a name and a size.
                    readonly property string picture: row.modelData.picture ?? ""

                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        id: appIcon
                        anchors.fill: parent
                        source: badge.iconSource
                        visible: badge.iconSource !== "" && status === Image.Ready
                        sourceSize.width: 52
                        sourceSize.height: 52
                        asynchronous: true
                    }

                    // ClippingRectangle rather than `clip`, which is
                    // rectangular and would square off the corners.
                    ClippingRectangle {
                        anchors.fill: parent
                        visible: badge.picture !== "" && thumbnail.status === Image.Ready
                        radius: width * Theme.pictureCorner
                        color: Theme.islandSurfaceHover

                        Image {
                            id: thumbnail

                            anchors.fill: parent
                            source: badge.picture
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 52
                            sourceSize.height: 52
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !appIcon.visible && badge.picture === ""
                        radius: width / 2
                        color: Theme.islandSurfaceHover

                        Text {
                            anchors.centerIn: parent
                            text: badge.isApp ? "󰀻" : row.modelData.icon
                            font.family: Theme.fontMono
                            font.pixelSize: 14
                            color: root.kindColour(row.modelData.kind)
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.family: row.modelData.kind === "calculation"
                            ? Theme.fontMono : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeRegular
                        font.weight: row.modelData.kind === "calculation"
                            ? Font.DemiBold : Font.Normal
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.subtitle
                        visible: row.modelData.subtitle !== ""
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                // Marks apps kept on the dock, which is why they rank near the
                // top of an empty query.
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: row.modelData.kind === "app"
                        && LauncherService.favourites.indexOf(row.modelData.id) >= 0
                    text: "󱂩"
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    color: Theme.textMuted
                }

                // A mode row shows its sigil as a keycap, so it also teaches
                // the shortcut. The box gives every character the same size
                // and centre; bare, `'` is a thin stroke at the top of its
                // line.
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 20
                    visible: (row.modelData.sigil ?? "") !== ""
                    radius: Theme.radiusSmall - 2
                    color: Theme.island
                    border.color: Theme.islandBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: row.modelData.sigil ?? ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.accent
                    }
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // On movement, not hover: a row appearing under a resting
                // pointer would otherwise steal the selection on open.
                onPositionChanged: row.ListView.view.currentIndex = row.index
                onClicked: root.run(row.modelData)
            }
        }
    }
}
