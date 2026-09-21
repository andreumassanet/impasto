// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C H I P   F A C E                                                      │
// │   module chip · symbol or ring, and its value                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// Draws a module's chip for the bar, the settings tiles and the settings' bar
// preview, so all three agree on width and typeface.
//
// A chip is a mark (the module's symbol or, in ring shape, its own gauge from
// `Module.compact`) and a figure (`ModuleService.valueOf`). `reveal` is how far
// the figure is out, from 0 to 1.
//
// The figure is its own width in tabular digits, so a ticking value never
// shifts the bar; only a new digit does. Text elides at its limit.
Item {
    id: root

    property string moduleId: ""
    property string shape: ModuleService.shapeOf(root.moduleId)
    property real reveal: 1

    // In a shared capsule the ring is drawn at 0.85 so it doesn't touch the
    // capsule outline; alone and closed, it is the capsule.
    property bool alone: false

    // Only a module that measures has a ring, whatever shape is asked for.
    readonly property bool ring: root.shape === "ring" && ModuleService.ringed.indexOf(root.moduleId) >= 0
    readonly property string value: ModuleService.valueOf(root.moduleId)
    readonly property bool figured: root.value !== ""
    readonly property int size: Math.round(Theme.capsuleHeight * 0.44)
    readonly property int pad: root.alone ? 11 : 8
    readonly property int spacing: 5
    readonly property int limit: ModuleService.figureLimit(root.moduleId)
    readonly property color tint: ModuleService.tintOf(root.moduleId)

    readonly property real markWidth: root.ring ? Theme.capsuleHeight : glyph.width
    readonly property real figureRoom: root.figured ? root.spacing + figure.width : 0

    // Equal spacing either side of the figure: from the ring's drawn edge (0.85
    // of its box, hence `inset`) to the figure, and from the figure to the
    // chip's end.
    readonly property real inset: Theme.capsuleHeight * 0.075
    readonly property int gap: root.alone ? 9 : 7

    // A ring starts flush with the capsule edge; a symbol gets padding on both
    // sides. The padding after the figure grows with the reveal.
    implicitWidth: root.ring
        ? root.markWidth
            + (root.figured ? figure.width + 2 * root.gap - root.inset : 0) * root.reveal
        : root.pad + root.markWidth + root.figureRoom * root.reveal + root.pad
    implicitHeight: Theme.capsuleHeight

    // ── MARK ────────────────────────────────────────────────────────────────

    Item {
        id: glyph

        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.ring
        width: root.moduleId === "pet" ? root.size + 2 : (symbol.visible ? symbol.implicitWidth : root.size)
        height: root.size + 2

        // Claude and the pet have no font glyph and draw their own mark at
        // glyph size.
        Loader {
            anchors.centerIn: parent
            active: !root.ring && root.moduleId === "claude"
            sourceComponent: ClaudeMark {
                width: root.size
                height: root.size
                color: root.tint
            }
        }

        Loader {
            anchors.centerIn: parent
            active: !root.ring && root.moduleId === "pet"
            sourceComponent: PetFace {
                width: root.size + 2
                height: root.size + 2
                size: root.size + 2
            }
        }

        Text {
            id: symbol

            anchors.centerIn: parent
            visible: root.moduleId !== "claude" && root.moduleId !== "pet"
            text: ModuleService.glyphOf(root.moduleId)
            font.family: Theme.fontMono
            font.pixelSize: root.size
            color: root.tint

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
    }

    Item {
        id: gauge

        visible: root.ring
        width: Theme.capsuleHeight
        height: Theme.capsuleHeight
        anchors.verticalCenter: parent.verticalCenter
        scale: root.alone ? 1 - 0.15 * (root.figured ? root.reveal : 0) : 0.85

        Loader {
            anchors.fill: parent
            active: root.ring && root.moduleId !== ""
            sourceComponent: Module {
                moduleId: root.moduleId
                compact: true
            }
        }
    }

    // ── FIGURE ──────────────────────────────────────────────────────────────
    //
    // Clipped to the width opened so far, and only faded in past a fifth of the
    // reveal so a half-open chip never shows half a word.

    Item {
        x: root.ring ? root.markWidth - root.inset + root.gap
            : root.pad + root.markWidth + root.spacing
        width: Math.max(0, (root.figured ? figure.width : 0) * root.reveal)
        height: parent.height
        visible: root.figured && root.reveal > 0
        clip: true

        Text {
            id: figure

            anchors.verticalCenter: parent.verticalCenter
            width: root.limit > 0
                ? Math.min(root.limit, figure.implicitWidth)
                : figure.implicitWidth
            opacity: Math.max(0, (root.reveal - 0.2) / 0.8)
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            text: root.value
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Theme.text
        }
    }
}
