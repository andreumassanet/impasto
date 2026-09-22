// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   U   P   D   A   T   E   S       F   A   C   E                          │
// │   the pending updates as a parcel · the count on its label               │
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

    readonly property bool none: UpdatesService.count === 0

    line: UpdatesService.checking ? "Checking"
        : (!UpdatesService.available ? "Cannot check"
            : (face.none ? "Up to date" : `${UpdatesService.count} pending`))
    reading: UpdatesService.available || UpdatesService.checking ? `${UpdatesService.count}` : "—"
    note: UpdatesService.checking ? "checking"
        : !UpdatesService.available ? "cannot check"
        : `${face.none ? "up to date" : "pending"}${UpdatesService.age !== "" ? " · " + UpdatesService.age : ""}`
    tint: face.none ? face.ink.muted : face.ink.text
    filled: true

    Parcel {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height)
        count: `${UpdatesService.count}`
    }

    extra: [
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 1

            Repeater {
                model: ScriptModel {
                    values: (UpdatesService.packages ?? []).slice(0, 2)
                }

                Text {
                    required property var modelData

                    width: parent.width
                    text: typeof modelData === "string" ? modelData : (modelData.name ?? "")
                    elide: Text.ElideRight
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: face.ink.muted
                }
            }
        }
    ]
}
