// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D E T A I L   F A C E                                                  │
// │   a module's expanded view · its card or its menu                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../modules"
import "./controls"

// A module opened from the bar: its detail card or, where the control centre
// has a list for it (the network), that list at its own size
// (`ModuleService.openSize`). The island draws this for every detail without
// knowing which modules have a menu.
Item {
    id: root

    property string moduleId: ""

    signal closed()

    readonly property string menu: root.moduleId === "network"
        ? "wifi" : (root.moduleId === "bluetooth" ? "bluetooth" : "")

    // The calendar reuses the control centre's month rather than drawing a
    // second one.
    readonly property bool month: root.moduleId === "calendar"

    // The music opens out round its lyrics once they are known.
    readonly property bool lyrics: root.moduleId === "media" && LyricsService.available

    Loader {
        anchors.fill: parent
        // A card brings its own margins; a menu takes the same ones.
        anchors.margins: root.menu !== "" ? Theme.cardPadding : 0
        sourceComponent: root.menu === "wifi" ? wifi
            : root.menu === "bluetooth" ? bluetooth
            : root.month ? calendar
            : root.lyrics ? lyrics : card
    }

    Component {
        id: calendar

        // Bare: the island is the card.
        CalendarCard {
            bare: true
            padding: Theme.cardPadding
            onPanelRequested: panel => ModuleService.requestPanel(panel)
        }
    }

    Component {
        id: wifi

        NetworkDetail {
            backable: false
            onBack: root.closed()
        }
    }

    Component {
        id: bluetooth

        BluetoothDetail {
            backable: false
            onBack: root.closed()
        }
    }

    Component {
        id: lyrics

        LyricsDetail {}
    }

    Component {
        id: card

        Module {
            moduleId: root.moduleId
            compact: false
        }
    }
}
