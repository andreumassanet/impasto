// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A R   C H I P                                                        │
// │   one bar item, placed by the layout                                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../modules"

// One item on the bar. A module is drawn by `ChipFace` (symbol or ring, with
// its figure never, always or on hover), and a click asks the bar to open its
// detail in the island (`Bar.qml`). A button opens or closes its panel.
//
// Sharing a capsule, the chip is drawn inside it, the ring at 0.85 so it does
// not touch the capsule's outline. Alone, the chip is the capsule: a full-size
// ring, a circular button, or a pill just wide enough for symbol and figure.
//
// `reveal` is animated here and the Row reads the resulting width each frame,
// so each chip has exactly one clock.
Item {
    id: root

    property string moduleId: ""

    property bool alone: false

    // The piece's own look, "" for the bar's (`SettingsService.barItems`).
    property string ownShape: ""
    property string ownFigure: ""
    property string ownWhen: ""
    readonly property string figure: ModuleService.figureOf(root.ownFigure)

    readonly property bool button: ModuleService.isButton(root.moduleId)
    readonly property var door: ModuleService.buttons[root.moduleId] ?? null

    readonly property bool open: root.button
        ? ModuleService.shownPanel === root.door.panel
        : ModuleService.openId === root.moduleId

    // Out always, never, or while the pointer is on it.
    property real reveal: {
        if (root.figure === "on")
            return 1
        if (root.figure === "hover" && mouse.containsMouse)
            return 1
        return 0
    }

    // Fast, on a curve that starts quickly, so it answers the pointer at once.
    Behavior on reveal {
        NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutCubic }
    }

    // Hidden when the machine lacks the module, or when it is set to show only
    // while running and is not; the Row closes up.
    visible: ModuleService.shows(root.moduleId, root.ownWhen)
    implicitWidth: root.button ? Theme.capsuleHeight : face.implicitWidth
    implicitHeight: Theme.capsuleHeight
    width: root.implicitWidth
    height: root.implicitHeight

    // Highlight on hover and while its detail or panel is open. Alone, it
    // fills the capsule less its outline.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - (root.alone ? 2 : 4)
        height: root.alone ? parent.height - 2 : Theme.capsuleHeight - 8
        radius: height / 2
        color: Theme.islandSurfaceHover
        opacity: mouse.containsMouse || root.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    }

    Text {
        anchors.centerIn: parent
        visible: root.button
        text: root.door ? root.door.glyph : ""
        font.family: Theme.fontMono
        font.pixelSize: Math.round(Theme.capsuleHeight * 0.44)
        color: Theme.text
    }

    ChipFace {
        id: face

        visible: !root.button
        moduleId: root.button || !ModuleService.shows(root.moduleId, root.ownWhen) ? "" : root.moduleId
        shape: ModuleService.shapeOf(root.moduleId, root.ownShape)
        alone: root.alone
        reveal: root.reveal
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.button && root.door.panel)
                ModuleService.togglePanel(root.door.panel)
            else if (root.button)
                root.door.action()
            // The player with no player open has nothing to open onto.
            else if (ModuleService.has(root.moduleId))
                ModuleService.activate(root.moduleId)
        }
    }
}
