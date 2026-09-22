// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T E S   P A N E L                                                  │
// │   notes · the deck and the note editor                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// The notes: a deck of every note, with New first. Opening a card fills the
// panel with that note. Escape goes back to the deck, then closes.
//
// Opens with the keyboard ring on New. A note closed blank is discarded.
// Arrows move between cards, Enter opens one, Delete archives it.
FocusScope {
    id: root

    signal closed()

    readonly property string opened: NotesService.opened
    readonly property var note: NotesService.entry(root.opened)

    // Three cards across the island's declared width. The panel is that size
    // from the first frame (the island clips what it has not reached yet), so
    // nothing reflows while it grows.
    readonly property int cardWidth: 160
    readonly property int cardHeight: 120
    readonly property int gap: 12
    readonly property int roomWidth: NotesService.panelWidth - 2 * Theme.panelPadding
    readonly property int roomHeight: NotesService.panelHeight - 2 * Theme.panelPadding

    Component.onCompleted: root.forceActiveFocus()

    // Closing the panel leaves the note (discarding it if blank), so it
    // reopens on the deck.
    Component.onDestruction: NotesService.leave()

    // Escape goes back to the deck when the note was opened there. Opened from
    // elsewhere (a widget, a tab, the detail, a menu), the event is left to
    // the island, which closes the panel.
    Keys.onEscapePressed: event => {
        if (root.opened === "" || NotesService.direct) {
            event.accepted = false
            return
        }
        NotesService.leave()
    }

    // Same rule, for the back arrow and the buttons.
    function back(): void {
        if (NotesService.direct)
            root.closed()
        else
            NotesService.leave()
    }

    // Not `anchors.fill`: a Loader resizes what it loads, and the pages
    // declare their own size (see `roomWidth`).
    Loader {
        focus: true
        sourceComponent: root.opened === "" ? deck : editor
    }

    // ── DECK ────────────────────────────────────────────────────────────────

    Component {
        id: deck

        ColumnLayout {
            id: page

            // At the room's size, not the island's: see `roomWidth`.
            width: root.roomWidth
            height: root.roomHeight

            // Whether archived notes are shown, dimmed. Reset every time the
            // panel opens.
            property bool showingArchived: false

            // New first, then the deck, then the drawer if it is open.
            readonly property var cards: [{ fresh: true }].concat(
                page.showingArchived
                    ? NotesService.live.concat(NotesService.archived)
                    : NotesService.live)

            spacing: 12

            // Focus the grid with the ring on New. Explicit: `focus: true`
            // down the chain does not reach an item inside a Loader.
            Component.onCompleted: {
                grid.currentIndex = 0
                grid.forceActiveFocus()
            }

            function openCurrent(): void {
                const card = page.cards[grid.currentIndex]
                if (!card)
                    return
                if (card.fresh)
                    NotesService.create("yellow", true)
                else
                    NotesService.open(card.key, true)
            }

            function archiveCurrent(): void {
                const card = page.cards[grid.currentIndex]
                if (card && !card.fresh && !card.archived)
                    NotesService.archive(card.key, true)
            }

            // Where a note is shown, for the mark in the card's corner.
            function placement(key: string): string {
                return DesktopService.placementOf(key)
            }

            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: ScriptModel {
                    values: page.cards
                    objectProp: "key"
                }
                cellWidth: root.cardWidth + root.gap
                cellHeight: root.cardHeight + root.gap
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: 0

                readonly property bool walking: grid.activeFocus

                Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                Keys.onRightPressed: grid.moveCurrentIndexRight()
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Keys.onUpPressed: grid.moveCurrentIndexUp()
                Keys.onReturnPressed: page.openCurrent()
                Keys.onEnterPressed: page.openCurrent()
                Keys.onSpacePressed: page.openCurrent()
                Keys.onDeletePressed: page.archiveCurrent()

                delegate: Item {
                    id: slot

                    required property var modelData
                    required property int index

                    readonly property var card: slot.modelData
                    readonly property bool fresh: slot.card.fresh === true
                    readonly property bool current: grid.walking && grid.currentIndex === slot.index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    // New: plain ground and a plus, ringed when the keyboard
                    // is on it.
                    Rectangle {
                        visible: slot.fresh
                        width: root.cardWidth
                        height: root.cardHeight
                        radius: Theme.paperRadius
                        color: freshMouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface
                        border.color: slot.current ? Theme.accent : Theme.islandBorder
                        border.width: slot.current ? 2 : 1

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰐕"
                                font.family: Theme.fontMono
                                font.pixelSize: 22
                                color: Theme.accent
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "New note"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                        }

                        MouseArea {
                            id: freshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotesService.create("yellow", true)
                        }
                    }

                    // A note in its paper colour, ringed when the keyboard is
                    // on it, with its placement in the corner.
                    Item {
                        visible: !slot.fresh
                        width: root.cardWidth
                        height: root.cardHeight
                        opacity: slot.card.archived ? 0.5 : 1

                        Sticky {
                            anchors.fill: parent
                            note: slot.fresh ? null : slot.card
                            bodySize: 14
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.paperRadius
                            color: "transparent"
                            border.color: slot.current ? Theme.accent : "transparent"
                            border.width: 2

                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            text: {
                                if (slot.fresh)
                                    return ""
                                if (slot.card.archived)
                                    return "󰁫"
                                const place = page.placement(slot.card.key)
                                if (place === "grid")
                                    return "󰕰"
                                return place !== "" ? "󰞘" : ""
                            }
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            color: Theme.paperInkMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotesService.open(slot.card.key, true)
                        }
                    }
                }
            }

            // ── FOOTER ──────────────────────────────────────────────────

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: {
                        const n = NotesService.count
                        const a = NotesService.archived.length
                        if (n === 0 && a === 0)
                            return "Nothing written down yet"
                        const parts = [`${n} ${n === 1 ? "note" : "notes"}`]
                        if (a > 0)
                            parts.push(`${a} archived`)
                        return parts.join(" · ")
                    }
                    elide: Text.ElideRight
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                PillButton {
                    visible: NotesService.archived.length > 0
                    text: page.showingArchived ? "Hide archived" : "Show archived"
                    icon: "󰁫"
                    active: page.showingArchived
                    onClicked: page.showingArchived = !page.showingArchived
                }
            }
        }
    }

    // ── NOTE ────────────────────────────────────────────────────────────────
    //
    // The island paints itself the note's colour and drops its padding while
    // a note is open (`DynamicIsland.paper`), so this draws no background and
    // keeps that padding inside. The title at the top, the body in
    // handwriting, and the colours, Archive and Delete along the bottom.

    Component {
        id: editor

        Item {
            id: sheet

            // The island's full width from the first frame, so the text does
            // not rewrap while it grows. Not `roomWidth`: the island drops its
            // padding for the paper and this sheet keeps it inside.
            width: NotesService.panelWidth
            height: NotesService.panelHeight

            readonly property string key: root.opened
            readonly property bool archived: root.note ? root.note.archived : false
            readonly property color paper: NotesService.paperOf(root.note ? root.note.tint : "yellow")

            // Set once, not bound: text goes to the service on every keystroke
            // and comes back, and a binding would move the caret to the end
            // each time. Read from the service rather than `root.note`, which
            // has not re-evaluated yet inside the change that built the sheet.
            // A new note focuses its title; one with a title, its body.
            Component.onCompleted: {
                const note = NotesService.entry(root.opened)
                heading.text = note ? note.title : ""
                writing.text = note ? note.text : ""
                writing.cursorPosition = writing.length
                if (heading.text === "")
                    heading.forceActiveFocus()
                else
                    writing.forceActiveFocus()
            }

            function toTitle(): void {
                heading.forceActiveFocus()
                heading.cursorPosition = heading.length
            }

            // The whole band above the line is the title's: a press anywhere on
            // it writes there, at the end.
            MouseArea {
                width: sheet.width
                height: Theme.panelPadding + divider.y
                cursorShape: Qt.IBeamCursor
                enabled: !sheet.archived
                onPressed: sheet.toTitle()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.panelPadding
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    TextInput {
                        id: heading

                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        color: Theme.paperInk
                        clip: true
                        selectByMouse: true
                        selectionColor: Theme.paperInk
                        selectedTextColor: sheet.paper
                        enabled: !sheet.archived

                        onTextEdited: NotesService.update(sheet.key, { title: heading.text })
                        // Enter, Tab or Down moves on to the body.
                        Keys.onReturnPressed: writing.forceActiveFocus()
                        Keys.onEnterPressed: writing.forceActiveFocus()
                        Keys.onTabPressed: writing.forceActiveFocus()
                        Keys.onDownPressed: writing.forceActiveFocus()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: heading.text === ""
                            text: "Title"
                            font: heading.font
                            color: Theme.paperInkMuted
                        }
                    }

                    Text {
                        text: root.note ? NotesService.ageOf(root.note.edited) : ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.paperInkMuted
                    }
                }

                Rectangle {
                    id: divider

                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.paperLine
                }

                Flickable {
                    id: scroller

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: writing.contentHeight + 8
                    boundsBehavior: Flickable.StopAtBounds

                    function follow(rectangle: rect): void {
                        if (rectangle.y < scroller.contentY)
                            scroller.contentY = rectangle.y
                        else if (rectangle.y + rectangle.height > scroller.contentY + scroller.height)
                            scroller.contentY = rectangle.y + rectangle.height - scroller.height
                    }

                    // At least the room's height, so a press anywhere below
                    // the text writes at its end.
                    TextEdit {
                        id: writing

                        width: scroller.width
                        height: Math.max(writing.contentHeight, scroller.height)
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        font.family: Theme.fontHand
                        font.pixelSize: 21
                        color: Theme.paperInk
                        selectByMouse: true
                        selectionColor: Theme.paperInk
                        selectedTextColor: sheet.paper
                        enabled: !sheet.archived

                        onTextChanged: {
                            if (root.note && writing.text !== root.note.text)
                                NotesService.update(sheet.key, { text: writing.text })
                        }
                        onCursorRectangleChanged: scroller.follow(writing.cursorRectangle)

                        // Back to the title: Shift+Tab, or Up on the first line.
                        // Not Backspace at the start: held to clear the body, it
                        // would go on into the title.
                        Keys.onUpPressed: event => {
                            if (writing.cursorRectangle.y < writing.cursorRectangle.height)
                                sheet.toTitle()
                            else
                                event.accepted = false
                        }
                        Keys.onPressed: event => {
                            const backtab = event.key === Qt.Key_Backtab
                                || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))
                            if (backtab) {
                                sheet.toTitle()
                                event.accepted = true
                            }
                        }

                        Text {
                            visible: writing.text === ""
                            text: "Write…  a line that starts [ ] is a box"
                            font: writing.font
                            color: Theme.paperInkMuted
                        }
                    }
                }

                // The colours and the actions. Back is the arrow, or Escape.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconButton {
                        icon: "󰁍"
                        iconSize: 14
                        iconColor: Theme.paperInk
                        onClicked: root.back()
                    }

                    Row {
                        Layout.leftMargin: 6
                        spacing: 8

                        Repeater {
                            model: NotesService.tints

                            Item {
                                id: swatch

                                required property string modelData

                                readonly property color colour: NotesService.tintColor(swatch.modelData)
                                readonly property bool current: root.note && root.note.tint === swatch.modelData

                                width: 22
                                height: 22

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: swatch.current ? 22 : 14
                                    height: width
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: Theme.paperInk
                                    border.width: swatch.current ? 2 : 0

                                    Behavior on width { NumberAnimation { duration: Theme.durationFast } }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: swatch.colour
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotesService.setTint(sheet.key, swatch.modelData)
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    PillButton {
                        text: sheet.archived ? "Restore" : "Archive"
                        icon: sheet.archived ? "󰁭" : "󰁫"
                        onClicked: {
                            NotesService.archive(sheet.key, !sheet.archived)
                            root.back()
                        }
                    }

                    PillButton {
                        text: "Delete"
                        icon: "󰆴"
                        onClicked: {
                            const direct = NotesService.direct
                            NotesService.remove(sheet.key)
                            if (direct)
                                root.closed()
                        }
                    }
                }
            }
        }
    }
}
