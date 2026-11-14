// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N   O   T   E       F   A   C   E                                      │
// │   a note as a desktop widget                                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// A note on the desktop, in any of the four families: the same paper the deck
// draws. The widget draws no capsule for notes (`DesktopService.bare`); the
// paper gets the bare style's shadow.
//
// Read-only: the desktop never takes the keyboard, so a click opens the note in
// the island.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)

    // The note the row names, or the front of the deck when it names none.
    property var row: null
    property string family: "2x2"

    readonly property var note: NotesService.noteFor(root.row)

    Sticky {
        anchors.fill: parent
        note: root.note
        placeholder: Tr.t("No notes yet")
        padding: root.width > 300 ? 18 : 14
        titleSize: root.family === "2x2" ? Theme.fontSizeSmall : Theme.fontSizeRegular
        bodySize: {
            if (root.family === "2x2")
                return 16
            if (root.family === "4x2")
                return 18
            return 20
        }
    }

    // Disabled while arranging, so dragging does not open the note.
    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            NotesService.open(root.note ? root.note.key : "")
            ModuleService.requestPanel("notes")
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
