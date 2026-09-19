// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   F A C E                                                        │
// │   one creature, drawn · the style the setting names                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"
import "./pets"

// One pet, drawn in one of the four styles. The record and mood are
// properties rather than read from PetService because the shelf and settings
// draw the whole family at once.
//
// An egg until it hatches, a star at level fifteen. The blink is timed here,
// so every style shares one clock and one set of moods.
Item {
    id: root

    property var record: PetService.pet
    property string mood: PetService.mood
    property real size: 40
    property bool lively: false

    // One of `PetService.styles`. A property rather than a read of the
    // setting, so the settings tiles can draw all four at once.
    property string style: SettingsService.petStyle

    readonly property bool egg: !(root.record && root.record.hatchedAt > 0)
    readonly property int level: (root.record && root.record.level) ?? 1
    readonly property bool asleep: root.mood === "asleep"
    readonly property var kind: PetService.speciesOf(root.record)

    readonly property color coat: ({
        accent: Theme.accent,
        green: Theme.green,
        yellow: Theme.yellow,
        red: Theme.red,
        blue: Theme.blue
    })[root.kind.tint] ?? Theme.accent

    // 1 open, 0 shut.
    property real blink: 1

    implicitWidth: root.size
    implicitHeight: root.size
    width: root.size
    height: root.size

    // Blink timing is part of the character, not a motion token.
    SequentialAnimation {
        running: root.lively && !root.asleep && !root.egg
        loops: Animation.Infinite

        PauseAnimation { duration: 2800 }
        NumberAnimation { target: root; property: "blink"; to: 0.15; duration: 70 }
        NumberAnimation { target: root; property: "blink"; to: 1; duration: 110 }
    }

    readonly property var styles: ({
        plush: plush,
        pixel: pixel,
        paper: paper,
        creature: creature
    })

    Loader {
        anchors.fill: parent
        sourceComponent: root.styles[root.style] ?? creature
    }

    Component {
        id: plush

        PetPlush {
            kind: root.kind; coat: root.coat; size: root.size
            mood: root.mood; egg: root.egg; blink: root.blink
        }
    }

    Component {
        id: pixel

        PetPixel {
            kind: root.kind; coat: root.coat; size: root.size
            mood: root.mood; egg: root.egg; blink: root.blink
        }
    }

    Component {
        id: paper

        PetPaper {
            kind: root.kind; coat: root.coat; size: root.size
            mood: root.mood; egg: root.egg; blink: root.blink
        }
    }

    Component {
        id: creature

        PetCreature {
            kind: root.kind; coat: root.coat; size: root.size
            mood: root.mood; egg: root.egg; blink: root.blink
        }
    }

    // Level-15 star, in a fixed indicator colour.
    Text {
        visible: !root.egg && root.level >= 15
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: -root.size * 0.06
        text: "★"
        font.pixelSize: Math.round(root.size * 0.26)
        color: Theme.indicatorWarn
    }

    Text {
        visible: root.asleep && !root.egg && root.lively
        anchors.left: parent.right
        anchors.leftMargin: -root.size * 0.14
        anchors.top: parent.top
        text: "z"
        font.family: Theme.fontMono
        font.pixelSize: Math.round(root.size * 0.24)
        color: Theme.textMuted
    }
}
