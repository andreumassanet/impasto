// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C   L   O   C   K       F   A   C   E                                  │
// │   a dial at every size · numerals and a date window at 4×4               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// An analogue dial at every size. 4×2 adds the weekday and the date beside it;
// 4×4 adds numerals, minute marks and a date window.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)

    Loader {
        anchors.fill: parent
        sourceComponent: root.family === "4x4" ? large : room
    }

    Component {
        id: room

        Instrument {
            family: root.family
            ink: root.ink
            reading: Tr.date(dial.now, "dddd")
            note: Tr.date(dial.now, "d MMMM yyyy")

            Dial {
                id: dial

                anchors.centerIn: parent
                ink: root.ink
                size: Math.min(parent.width, parent.height)
            }
        }
    }

    Component {
        id: large

        Item {
            Dial {
                anchors.centerIn: parent
                ink: root.ink
                size: Math.min(parent.width, parent.height) - 44
                numerals: true
                minuteTicks: true
                dateWindow: true
            }
        }
    }
}
