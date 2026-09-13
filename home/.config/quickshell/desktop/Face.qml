// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F   A   C   E                                                          │
// │   picks a widget face by module, family and theme                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../services"
import "./faces"
import "./faces/analogue"

// Picks the face for a module, a family (size) and a theme. Modern has one
// registry per family, falling back within that registry for modules without a
// row; Analogue has a single registry whose faces lay themselves out at any
// size. Notes always use NoteFace. Faces read their colours from the widget's
// resolved `ink`.
Item {
    id: root

    property string moduleId: ""
    property string family: "4x2"
    property string theme: DesktopService.themeOf(null)
    property var ink: DesktopService.inkFor(null)

    // The desktop row, for faces that draw something the row names (a note,
    // a picture). Null for tray tiles, which show the front of the deck or
    // an empty frame.
    property var row: null

    readonly property bool analogue: root.theme === "analogue" && root.moduleId !== "notes"

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (root.analogue)
                return analogue
            if (root.family === "2x2")
                return squares
            if (root.family === "4x4")
                return larges
            if (root.family === "8x2")
                return bands
            return wides
        }
    }

    Component {
        id: analogue
        Analogue { moduleId: root.moduleId; family: root.family; ink: root.ink; row: root.row }
    }

    Component {
        id: squares
        Squares { moduleId: root.moduleId; ink: root.ink; row: root.row }
    }

    Component {
        id: wides
        Wides { moduleId: root.moduleId; ink: root.ink; row: root.row }
    }

    Component {
        id: larges
        Larges { moduleId: root.moduleId; ink: root.ink; row: root.row }
    }

    Component {
        id: bands
        Bands { moduleId: root.moduleId; ink: root.ink; row: root.row }
    }
}
