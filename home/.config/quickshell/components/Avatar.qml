// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A V A T A R                                                            │
// │   a face, or the letters that stand in for one                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell.Widgets

import "../theme"
import "../services"

// A round picture, or initials when there is none (the common case: most
// machines have no `~/.face`).
Item {
    id: root

    property string source: ""
    property string initials: "?"
    property color ring: Theme.hairline

    implicitWidth: 86
    implicitHeight: 86

    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.islandSurface
        border.color: root.ring
        border.width: 2
        contentUnderBorder: true

        Image {
            id: picture

            anchors.fill: parent
            // The revision is a fragment: a new key for the image cache, and
            // the same file read, so a picture replaced in place shows.
            source: root.source !== "" ? `file://${root.source}#${AccountService.revision}` : ""
            visible: root.source !== "" && picture.status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: Math.round(root.width * 2)
            sourceSize.height: Math.round(root.height * 2)
        }

        Text {
            anchors.centerIn: parent
            visible: !picture.visible
            text: root.initials
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(root.height * 0.36)
            font.weight: Font.Light
            color: Theme.text
        }
    }
}
