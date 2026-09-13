// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P   H   O   T   O       F   A   C   E                                  │
// │   an instant print, or a strip of film · analogue                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell.Widgets

import "../../../theme"
import "../../../services"

// A picture of your own as an object on the desk. In the square, wide and
// large families it is an instant print: a paper border, a deep chin with the
// row's caption in the signature hand, and a strip of tape along the top. On
// the band it is a strip of film, the one picture running under three frames.
//
// Each widget leans its own way, derived from its key, so it keeps its angle
// across redraws and two photos side by side lean apart. The print's window is
// square-cornered, as a print's is, rather than `Theme.pictureCorner`.
Item {
    id: root

    property var ink: DesktopService.inkFor(null)
    property var row: null
    property string family: "2x2"

    readonly property string source: DesktopService.pictureOf(root.row)
    readonly property string caption:
        root.row && typeof root.row.caption === "string" ? root.row.caption : ""
    readonly property bool film: root.family === "8x2"

    // The analogue faces' paper: the text colour under the notes' wash.
    readonly property color paper: Qt.tint(root.ink.text, Theme.paperWash)

    // 0.8° to 2.6° either way. Keys that differ in their last character, as
    // photo-1 and photo-2 do, fall on opposite sides.
    readonly property real lean: {
        const key = root.row ? root.row.key : ""
        let hash = 0
        for (let index = 0; index < key.length; index++)
            hash = (hash * 31 + key.charCodeAt(index)) % 1000
        return (hash % 2 === 0 ? 1 : -1) * (0.8 + (hash % 100) / 100 * 1.8)
    }

    // The print's proportions for a card of this size: a border of 6% of its
    // short side, and a chin of 19% of its height.
    function frame(width: real, height: real): var {
        const side = Math.min(width, height) * 0.06
        const chin = height * 0.19
        return { side: side, chin: chin, width: width - 2 * side, height: height - side - chin }
    }

    // Decoded at the family's size rather than the animated one, so a resize
    // does not load the file again on every frame.
    readonly property var box: DesktopService.sizeFor(root.family)
    readonly property var still: root.film
        ? { width: root.box.width, height: root.box.height * 0.7 }
        : root.frame(root.box.width * 0.9, root.box.height * 0.9)

    Loader {
        anchors.fill: parent
        sourceComponent: root.film ? strip : instant
    }

    // At rest a click opens the picture in imv; disabled while arranging,
    // with the rest of the face.
    HoverHandler {
        enabled: root.row !== null && root.source !== ""
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.row !== null && root.source !== ""
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: DesktopService.openPicture(root.row)
    }

    // ── PRINT ───────────────────────────────────────────────────────────────

    Component {
        id: instant

        Item {
            Item {
                id: card

                readonly property var cut: root.frame(card.width, card.height)

                // A little inside the widget, so the corners stay on it when
                // the card leans.
                anchors.centerIn: parent
                width: parent.width * 0.9
                height: parent.height * 0.9
                rotation: root.lean
                antialiasing: true

                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: root.paper
                }

                ClippingRectangle {
                    x: card.cut.side
                    y: card.cut.side
                    width: card.cut.width
                    height: card.cut.height
                    radius: 1.5
                    color: Theme.paperLine

                    Image {
                        id: picture

                        anchors.fill: parent
                        source: root.source
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: root.still.width * 2
                        sourceSize.height: root.still.height * 2
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        visible: root.source === "" || picture.status === Image.Error
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: picture.status === Image.Error ? "Picture not found" : "No picture"
                        font.family: Theme.fontSignature
                        font.pixelSize: Math.min(26, parent.height * 0.16)
                        color: Theme.paperInkMuted
                    }
                }

                Text {
                    x: card.cut.side
                    y: card.height - card.cut.chin
                    width: card.cut.width
                    height: card.cut.chin
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: root.caption
                    font.family: Theme.fontSignature
                    font.pixelSize: Math.min(30, card.cut.chin * 0.62)
                    color: Theme.paperInk
                }

                // Tape, across the top edge and against the card's lean.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -height / 2
                    width: card.width * 0.26
                    height: Math.min(24, card.height * 0.11)
                    rotation: root.lean > 0 ? -4 : 4
                    antialiasing: true
                    color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.62)
                }
            }
        }
    }

    // ── FILM ────────────────────────────────────────────────────────────────

    Component {
        id: strip

        Item {
            Rectangle {
                id: base

                // The band of sprocket holes along each edge, and the holes'
                // pitch, evened out across the strip.
                readonly property real rebate: base.height * 0.16
                readonly property int holes: Math.max(1, Math.floor((base.width - 20) / 26))
                readonly property real pitch: (base.width - 20) / base.holes

                anchors.centerIn: parent
                width: parent.width * 0.98
                height: parent.height * 0.86
                rotation: root.lean * 0.35
                antialiasing: true
                radius: 3
                color: root.ink.ground

                Repeater {
                    model: base.holes * 2

                    Rectangle {
                        required property int index

                        x: 10 + (index % base.holes) * base.pitch + (base.pitch - width) / 2
                        y: (index < base.holes ? base.rebate : 2 * base.height - base.rebate) / 2
                            - height / 2
                        width: 10
                        height: 8
                        radius: 2
                        color: root.paper
                    }
                }

                ClippingRectangle {
                    x: 12
                    y: base.rebate
                    width: base.width - 24
                    height: base.height - 2 * base.rebate
                    radius: 1.5
                    color: root.ink.raised

                    Image {
                        id: exposure

                        anchors.fill: parent
                        source: root.source
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: root.still.width * 2
                        sourceSize.height: root.still.height * 2
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.source === "" || exposure.status === Image.Error
                        text: exposure.status === Image.Error ? "Picture not found" : "No picture"
                        font.family: Theme.fontSignature
                        font.pixelSize: Math.min(26, parent.height * 0.24)
                        color: root.ink.muted
                    }

                    // The bars between the three frames.
                    Repeater {
                        model: 2

                        Rectangle {
                            required property int index

                            x: (index + 1) * parent.width / 3 - width / 2
                            width: 8
                            height: parent.height
                            color: root.ink.ground
                        }
                    }
                }
            }
        }
    }
}
