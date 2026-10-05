// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F L I P   C A R D                                                      │
// │   one card of the flip clock · halves that fold over a hinge             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick

import "../theme"

// A card split at a hinge. A new value shows its top half behind the old
// one, the old top folds down over the hinge, then the new bottom folds
// down onto the old bottom: four halves, two of them turning.
Item {
    id: root

    property string value: ""
    property int size: 200

    // What the card showed before `value`, until the fold is over.
    property string previous: ""

    readonly property int hinge: Math.max(2, Math.round(root.size / 90))
    readonly property int padding: Math.round(root.size * 0.16)
    readonly property int half: Math.round(face.implicitHeight * 0.5)

    implicitWidth: Math.max(face.implicitWidth + 2 * root.padding, root.size * 0.9)
    implicitHeight: 2 * root.half + root.hinge

    // Measures the figures; never drawn.
    Text {
        id: face

        visible: false
        text: root.value
        font.family: Theme.fontDisplay
        font.pixelSize: root.size
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
    }

    Component.onCompleted: root.previous = root.value

    onValueChanged: {
        if (root.previous === "" || Theme.motion === 0) {
            root.previous = root.value
            return
        }
        fold.restart()
    }

    // One half of the card at a given value: the whole card drawn, and the
    // half that is not this one cut away.
    component Half: Item {
        id: halfItem

        property bool upper: true
        property string shown: ""
        // Darker the further it has turned from facing the screen.
        property real shade: 0

        width: root.width
        height: root.half
        clip: true

        Rectangle {
            y: halfItem.upper ? 0 : -root.half - root.hinge
            width: root.width
            height: root.height
            radius: Math.round(root.size * 0.12)
            color: Theme.island
            border.color: Theme.islandBorder
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: halfItem.shown
                font: face.font
                color: Theme.text
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.island
            opacity: halfItem.shade
        }
    }

    // ── STILL ───────────────────────────────────────────────────────────────

    Half {
        upper: true
        shown: root.value
    }

    Half {
        y: root.half + root.hinge
        upper: false
        shown: fold.running ? root.previous : root.value
    }

    // ── FOLDING ─────────────────────────────────────────────────────────────

    Half {
        id: oldTop

        upper: true
        shown: root.previous
        visible: fold.running && oldTurn.angle < 90
        shade: oldTurn.angle / 90 * 0.6

        transform: Rotation {
            id: oldTurn

            origin.y: root.half + root.hinge / 2
            axis { x: 1; y: 0; z: 0 }
            angle: 0
        }
    }

    Half {
        id: newBottom

        y: root.half + root.hinge
        upper: false
        shown: root.value
        visible: fold.running && newTurn.angle > -90
        shade: -newTurn.angle / 90 * 0.6

        transform: Rotation {
            id: newTurn

            origin.y: -root.hinge / 2
            axis { x: 1; y: 0; z: 0 }
            angle: -90
        }
    }

    SequentialAnimation {
        id: fold

        PropertyAction { target: oldTurn; property: "angle"; value: 0 }
        PropertyAction { target: newTurn; property: "angle"; value: -90 }
        NumberAnimation {
            target: oldTurn
            property: "angle"
            to: 90
            duration: Theme.durationMorph
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: newTurn
            property: "angle"
            to: 0
            duration: Theme.durationMorph
            easing.type: Easing.OutBounce
        }
        ScriptAction { script: root.previous = root.value }
    }
}
