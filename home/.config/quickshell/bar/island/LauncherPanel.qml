// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L A U N C H E R   P A N E L                                            │
// │   launcher · apps, calculator, windows, timer, clipboard, emoji          │
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
// windows, a countdown, the clipboard history, emoji, or the shell's own
// actions.
ColumnLayout {
    id: root

    // The query lives in the service: with `launcherFits` on, the panel's
    // height depends on it, and the island needs that before the panel exists.
    readonly property var results: LauncherService.results
    readonly property var mode: LauncherService.modeFor(LauncherService.query)

    // Emoji are a grid of glyphs; every other mode is a list of rows.
    readonly property bool grid: root.mode.id === "emoji"
    readonly property var view: root.grid ? emojiGrid : resultList

    // Loaded here rather than from the search, which runs inside a binding.
    onModeChanged: {
        if (root.mode.id === "emoji")
            EmojiService.load()
    }

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
        EmojiService.fresh = false
        if (root.mode.id === "emoji")
            EmojiService.load()
    }

    // Cleared on the way out, not on the way in: the island is sized from the
    // query a frame before this panel is built, so clearing it on open would
    // size the island for the last search and then resize it.
    Component.onDestruction: {
        LauncherService.query = ""
        EmojiService.group = ""
    }

    // The list wraps around at both ends. The grid stops at its edges, since
    // a line wrapped to the other end would land in a different column.
    function move(delta: int): void {
        const count = root.results.length
        if (count === 0)
            return
        if (root.grid) {
            const next = emojiGrid.currentIndex + delta
            if (next < 0 || next >= count)
                return
            emojiGrid.currentIndex = next
            emojiGrid.positionViewAtIndex(next, GridView.Contain)
            return
        }
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

    // Shift or Ctrl with Enter opens a copied image in imv instead of copying
    // it; on any other row it is a plain Enter.
    function confirm(entry: var, modifiers: int): void {
        if (entry && entry.kind === "clip" && entry.file
                && (modifiers & (Qt.ShiftModifier | Qt.ControlModifier))) {
            Quickshell.execDetached(["imv", entry.file])
            root.closed()
            return
        }
        root.run(entry)
    }

    // Only clipboard entries can be forgotten: they are recorded without being
    // chosen, so a mistake needs a way out. The panel stays open, since
    // deleting usually means deleting several.
    function forgetSelected(): void {
        if (root.mode.id !== "clipboard")
            return
        const entry = root.results[root.view.currentIndex]
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
            Keys.onReturnPressed: event => root.confirm(root.results[root.view.currentIndex], event.modifiers)
            Keys.onEnterPressed: event => root.confirm(root.results[root.view.currentIndex], event.modifiers)
            Keys.onUpPressed: root.move(root.grid ? -LauncherService.emojiColumns : -1)
            Keys.onDownPressed: root.move(root.grid ? LauncherService.emojiColumns : 1)
            // In the grid the arrows move along a line; the field is a search
            // term, rarely edited in the middle.
            Keys.onLeftPressed: event => {
                event.accepted = root.grid
                if (root.grid)
                    root.move(-1)
            }
            Keys.onRightPressed: event => {
                event.accepted = root.grid
                if (root.grid)
                    root.move(1)
            }
            // Tab steps through the emoji groups; elsewhere it does nothing.
            Keys.onTabPressed: {
                if (root.mode.id === "emoji")
                    EmojiService.stepGroup(1)
            }
            Keys.onBacktabPressed: {
                if (root.mode.id === "emoji")
                    EmojiService.stepGroup(-1)
            }
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
                text: Tr.t("Search…")
                visible: searchField.text === ""
                color: Theme.textMuted
                font: searchField.font
            }
        }

        // The skin tone every emoji that takes one is shown and copied in.
        // Its mark is the tone itself, on a raised hand; a click steps it.
        Text {
            visible: root.mode.id === "emoji"
            text: EmojiService.toneMarks[EmojiService.tone]
            font.family: Theme.fontFamily
            font.pixelSize: 18

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: EmojiService.stepTone()
            }
        }
    }

    // ── GROUPS ──────────────────────────────────────────────────────────────
    //
    // The emoji mode's nine groups and the recent picks, each marked by an
    // emoji and nothing else. Tab steps through them.
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: LauncherService.stripHeight
        visible: LauncherService.showsStrip
        spacing: 2

        Repeater {
            model: EmojiService.groups

            delegate: Rectangle {
                id: chip

                required property var modelData
                readonly property bool chosen: EmojiService.group === chip.modelData.id

                Layout.preferredWidth: LauncherService.stripHeight + 2
                Layout.preferredHeight: LauncherService.stripHeight
                radius: Theme.radiusSmall
                color: chip.chosen || chipMouse.containsMouse
                    ? Theme.surfaceHoverIn(QsWindow.window) : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Text {
                    anchors.centerIn: parent
                    text: chip.modelData.mark
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    opacity: chip.chosen ? 1 : 0.6
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        EmojiService.group = chip.modelData.id
                        searchField.forceActiveFocus()
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.borderIn(QsWindow.window)
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

    // ── EMOJI ───────────────────────────────────────────────────────────────
    //
    // The glyphs alone, as many to a line as fit; the name is only searched.
    GridView {
        id: emojiGrid

        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.grid
        clip: true
        cellWidth: LauncherService.emojiCell
        cellHeight: LauncherService.emojiCell
        model: ScriptModel {
            values: root.grid ? root.results : []

            onValuesChanged: {
                emojiGrid.currentIndex = 0
                emojiGrid.positionViewAtBeginning()
            }
        }
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: 0

        delegate: Rectangle {
            id: cell

            required property var modelData
            required property int index

            readonly property bool selected: GridView.view.currentIndex === cell.index

            width: LauncherService.emojiCell
            height: LauncherService.emojiCell
            radius: Theme.radiusSmall
            color: cell.selected ? Theme.surfaceHoverIn(QsWindow.window) : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            Text {
                anchors.centerIn: parent
                text: cell.modelData.glyph ?? ""
                font.family: Theme.fontFamily
                font.pixelSize: 28
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: cell.GridView.view.currentIndex = cell.index
                onClicked: root.run(cell.modelData)
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !root.grid

        ListView {
            id: resultList

            anchors.fill: parent
            anchors.rightMargin: letterStrip.visible ? letterStrip.width + 6 : 0
            clip: true
            spacing: LauncherService.rowSpacing
            model: ScriptModel {
                values: root.grid ? [] : root.results

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
                color: row.selected ? Theme.surfaceHoverIn(QsWindow.window) : "transparent"

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
                            ? Theme.appIcon(row.modelData.icon) : ""

                        // Copied images show a thumbnail: two screenshots often
                        // share a name and a size.
                        readonly property string picture: row.modelData.picture ?? ""

                        // An emoji is its own mark, drawn in colour.
                        readonly property string glyph: row.modelData.glyph ?? ""

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
                            color: Theme.surfaceHoverIn(QsWindow.window)

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

                        Text {
                            anchors.centerIn: parent
                            visible: badge.glyph !== ""
                            text: badge.glyph
                            font.family: Theme.fontFamily
                            font.pixelSize: 22
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !appIcon.visible && badge.picture === "" && badge.glyph === ""
                            radius: width / 2
                            color: Theme.surfaceHoverIn(QsWindow.window)

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
                        border.color: Theme.borderIn(QsWindow.window)
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
                    onClicked: mouse => root.confirm(row.modelData, mouse.modifiers)
                }
            }
        }

        // The phone book's A–Z, with the letter of the lit row large in
        // the accent. A press jumps to the first application under it.
        Column {
            id: letterStrip

            readonly property string current: resultList.currentIndex >= 0
                && resultList.currentIndex < root.results.length
                ? LauncherService.letterOf(root.results[resultList.currentIndex].name) : ""
            readonly property real cell: LauncherService.letters.length > 0
                ? Math.min(Theme.fontSizeRegular + 4, height / LauncherService.letters.length) : 0

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Theme.fontSizeRegular + 6
            visible: LauncherService.indexed && root.mode.id === "apps"

            Repeater {
                model: LauncherService.letters

                Text {
                    id: letter

                    required property var modelData
                    readonly property bool lit: letterStrip.current === letter.modelData.letter

                    width: letterStrip.width
                    height: letterStrip.cell
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: letter.modelData.letter
                    font.family: Theme.fontFamily
                    font.pixelSize: letter.lit ? Theme.fontSizeRegular + 2 : Theme.fontSizeLabel
                    font.weight: letter.lit ? Font.Bold : Font.Medium
                    color: letter.lit ? Theme.accent
                        : press.containsMouse ? Theme.text : Theme.textMuted

                    Behavior on font.pixelSize { NumberAnimation { duration: Theme.durationFast } }

                    MouseArea {
                        id: press

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            resultList.currentIndex = letter.modelData.index
                            resultList.positionViewAtIndex(letter.modelData.index, ListView.Beginning)
                        }
                    }
                }
            }
        }
    }
}
