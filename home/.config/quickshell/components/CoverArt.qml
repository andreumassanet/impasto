// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O V E R   A R T                                                      │
// │   the playing cover, in the one shape the shell uses                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Widgets

import "../theme"
import "../services"

// The cover of what is playing, as a rounded rectangle or as a circle
// (`SettingsService.mediaCover`), the same wherever the shell shows it. A
// circle may carry the equalizer (`CoverRing`, from cava) around it where
// there is room: `equalizer` is false where the neighbours already have bars.
// The size is the item's width and height; without a picture a tile and a note
// are drawn in its place.
Item {
    id: root

    property bool equalizer: true
    // Scales the rectangle's corner: a large cover wants a smaller radius.
    property real cornerScale: 1
    // A round cover turns while the music plays; a rectangle stays as it is.
    property bool spin: false
    // The edge the picture is decoded at, when the item is resized by an
    // animation: the picture is not reloaded per frame. 0 follows the size,
    // in steps of 64.
    property int sourceEdge: 0

    readonly property real size: Math.min(root.width, root.height)
    readonly property bool circle: SettingsService.mediaCover === "circle"
    // Whether a picture is on show, for a parent that draws its own stand-in.
    readonly property bool ready: MediaService.artUrl !== "" && art.status === Image.Ready

    Component.onCompleted: MediaService.subscribe()
    Component.onDestruction: MediaService.release()

    CoverRing {
        anchors.fill: parent
        active: root.circle && root.equalizer
        innerRadius: root.size / 2 + 3
        reach: Math.max(4, root.size * 0.14)
        barWidth: root.size < 40 ? 1.5 : root.size > 150 ? 4 : 2
    }

    // ClippingRectangle, because `clip` is rectangular and would square the
    // artwork's corners.
    ClippingRectangle {
        anchors.fill: parent
        radius: root.circle ? width / 2 : width * Theme.pictureCorner * root.cornerScale
        // None behind a picture: a player may send its logo on transparency.
        color: root.ready ? "transparent" : Theme.surfaceHoverIn(QsWindow.window)

        Image {
            id: art

            anchors.fill: parent
            source: MediaService.artUrl
            visible: root.ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: root.sourceEdge > 0 ? root.sourceEdge : Math.ceil(root.size * 2 / 64) * 64
            sourceSize.height: root.sourceEdge > 0 ? root.sourceEdge : Math.ceil(root.size * 2 / 64) * 64

            // Turns only a round cover that is spinning; any other stands upright.
            rotation: root.spin && root.circle ? turn.angle : 0
        }

        Item {
            id: turn

            property real angle: 0

            width: 0
            height: 0

            NumberAnimation on angle {
                from: 0
                to: 360
                duration: 24000
                loops: Animation.Infinite
                running: root.spin && root.circle && MediaService.playing
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !root.ready
            text: "󰎇"
            font.family: Theme.fontMono
            font.pixelSize: Math.round(root.size * 0.38)
            color: Theme.accent
        }
    }
}
