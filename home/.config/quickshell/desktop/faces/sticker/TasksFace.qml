// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T   A   S   K   S       F   A   C   E                                  │
// │   the count on a seal, the next tasks as tape                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"

// The count on a scalloped seal, green, or red with anything late. Wide, the
// next three tasks as strips of tape beside it; at 4×4 the seal sits in the
// corner and the next seven run down the face. A strip opens its task.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)
    property string seed: ""

    readonly property bool square: root.family === "2x2"
    readonly property bool large: root.family === "4x4"
    readonly property real side: Math.min(root.width, root.height)
    readonly property bool late: TasksService.overdue.length > 0
    readonly property var shown: TasksService.queue.slice(0, root.large ? 7 : 3)

    Tone { id: tone; hue: root.late ? root.ink.red : root.ink.green }

    Cut {
        id: seal

        width: root.side * (root.square ? 0.98 : (root.large ? 0.46 : 1))
        height: width
        x: root.square ? (root.width - width) / 2 : (root.large ? root.side * 0.04 : (root.height - height) / 2)
        y: root.square || !root.large ? (root.height - height) / 2 : root.side * 0.04
        shape: "cookie"
        lobes: 20
        depth: 0.035
        seed: root.seed
        fill: tone.fill

        Column {
            anchors.centerIn: parent

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: TasksService.pending > 0 ? `${TasksService.pending}` : "󰄬"
                font.family: TasksService.pending > 0 ? Theme.fontFamily : Theme.fontMono
                font.pixelSize: Math.round(seal.side * 0.34)
                font.weight: Font.Bold
                color: tone.deep
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: TasksService.pending > 0 ? (root.late ? Tr.t("%1 LATE").arg(TasksService.overdue.length) : Tr.t("TO DO"))
                    : (TasksService.count === 0 ? Tr.t("NOTHING YET") : Tr.t("ALL DONE"))
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(Theme.fontSizeLabel - 2, Math.round(seal.side * 0.075))
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: tone.deep
            }
        }
    }

    Column {
        id: strips

        readonly property real tall: root.large ? root.side * 0.12 : root.side * 0.28

        visible: !root.square
        x: root.large ? root.side * 0.08 : seal.x + seal.width + root.side * 0.06
        y: root.large ? seal.y + seal.height + root.side * 0.03 : (root.height - height) / 2
        width: root.width - x - root.side * 0.06
        spacing: root.side * 0.015

        Repeater {
            model: root.square ? [] : root.shown

            Cut {
                id: strip

                required property var modelData
                required property int index

                readonly property bool overdue: TasksService.isOverdue(strip.modelData)

                Tone { id: stripTone; hue: strip.overdue ? root.ink.red : root.ink.paper }

                width: Math.min(strips.width, words.implicitWidth + strip.height + 4)
                height: strips.tall
                shape: "pill"
                lean: Theme.stickerLean * 0.4
                seed: root.seed + strip.modelData.key
                fill: stripTone.fill

                Text {
                    id: words

                    anchors.verticalCenter: parent.verticalCenter
                    x: strip.height * 0.5
                    width: strip.width - 2 * x
                    text: strip.modelData.text
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(strip.height * 0.38)
                    font.weight: Font.DemiBold
                    color: stripTone.deep
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: TasksService.open(strip.modelData.key)
                }
            }
        }
    }

    // Nothing to list: a strip that opens the board.
    Cut {
        visible: !root.square && root.shown.length === 0
        x: strips.x
        y: root.large ? strips.y : (root.height - height) / 2
        width: open.implicitWidth + height
        height: strips.tall
        shape: "pill"
        seed: root.seed + "open"
        fill: tone.fill

        Text {
            id: open

            anchors.centerIn: parent
            text: Tr.t("Open the board")
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(parent.height * 0.38)
            font.weight: Font.DemiBold
            color: tone.deep
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: ModuleService.requestPanel("board")
        }
    }
}
