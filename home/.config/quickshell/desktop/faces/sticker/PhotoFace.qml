// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P   H   O   T   O       F   A   C   E                                  │
// │   the picture cut out as a sticker                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell.Widgets

import "../../../theme"
import "../../../services"

// The picture cut out as a sticker: a wide vinyl border round it, soft
// corners, tilted like the rest. Without one, a pale sticker that says so.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)
    property string seed: ""
    property var row: null

    readonly property string source: DesktopService.pictureOf(root.row)
    readonly property bool lost: picture.status === Image.Error
    readonly property bool empty: root.source === "" || root.lost
    readonly property real side: Math.min(root.width, root.height)

    // Decoded at the family's size rather than the animated one, so a resize
    // does not load the file again on every frame.
    readonly property var still: DesktopService.sizeFor(root.family)

    Tone { id: tone; hue: root.ink.accent }

    Cut {
        id: cut

        readonly property real border: cut.side * 0.06

        anchors.fill: parent
        anchors.margins: root.side * 0.02
        shape: "soft"
        lean: Theme.stickerLean * 0.5
        seed: root.seed
        fill: root.empty ? tone.fill : cut.paper

        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: cut.border
            visible: !root.empty
            radius: cut.side * 0.24 - cut.border
            color: tone.fill

            Image {
                id: picture

                anchors.fill: parent
                source: root.source
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: root.still.width * 2
                sourceSize.height: root.still.height * 2
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 24
            visible: root.empty
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰋩"
                font.family: Theme.fontMono
                font.pixelSize: Math.round(cut.side * 0.2)
                color: tone.deep
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.lost ? Tr.t("Picture not found") : Tr.t("No picture")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: tone.deep
            }
        }
    }
}
