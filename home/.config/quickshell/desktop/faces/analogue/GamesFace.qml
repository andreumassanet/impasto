// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G   A   M   E   S       F   A   C   E                                  │
// │   arcade as a joystick · best score and play                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

Instrument {
    id: face

    readonly property var last: GamesService.entry(GamesService.lastPlayed)

    line: face.last ? `${face.last.name} · ${Tr.t("best")} ${GamesService.bestOf(face.last.id)}` : Tr.t("Nothing played yet")
    reading: face.last ? `${GamesService.bestOf(face.last.id)}` : "—"
    note: face.last ? `${face.last.name} · ${Tr.t("best")}` : Tr.t("nothing played yet")
    filled: true

    Joystick {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height)
    }

    extra: [
        PillButton {
            anchors.left: parent.left
            anchors.top: parent.top
            text: Tr.t("Play")
            implicitHeight: 28
            onClicked: ModuleService.requestPanel("games")
        }
    ]
}
