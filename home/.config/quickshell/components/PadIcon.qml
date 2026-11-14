// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P A D   I C O N                                                        │
// │   a scratchpad's icon · an application, an image or a glyph              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Widgets

import "../theme"

// What a scratchpad's icon field holds, drawn: the path of an image (`/…`,
// `~/…` or `file://…`), else the name of an icon in the icon theme (an
// application's, `firefox`), else the text itself, which is a glyph of the
// icon font.
Item {
    id: root

    property string value: ""
    property int size: 20
    property color color: Theme.textMuted

    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string trimmed: String(root.value ?? "").trim()
    readonly property bool isPath: root.trimmed.startsWith("/") || root.trimmed.startsWith("~/")
        || root.trimmed.startsWith("file://")
    readonly property string pathSource: {
        if (!root.isPath)
            return ""
        if (root.trimmed.startsWith("file://"))
            return root.trimmed
        return "file://" + (root.trimmed.startsWith("~/")
            ? root.home + root.trimmed.slice(1) : root.trimmed)
    }
    // Empty when the theme has no icon of that name; a glyph is never one.
    readonly property string themed: root.isPath || root.trimmed === ""
        ? "" : Quickshell.iconPath(root.trimmed, true)

    implicitWidth: root.pathSource !== "" || root.themed !== "" ? root.size : glyph.implicitWidth
    implicitHeight: root.size

    Image {
        anchors.fill: parent
        visible: root.pathSource !== ""
        source: root.pathSource
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    IconImage {
        anchors.fill: parent
        visible: root.themed !== ""
        source: root.themed
    }

    Text {
        id: glyph

        anchors.centerIn: parent
        visible: root.pathSource === "" && root.themed === ""
        text: root.trimmed
        font.family: Theme.fontMono
        font.pixelSize: root.size - 2
        color: root.color
    }
}
