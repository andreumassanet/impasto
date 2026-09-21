// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L O C K   I S L A N D                                                  │
// │   the island on the lock · the padlock, and the face scan under it       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"
import "../services"
import "../components"

// The bar's island, where the bar has it and at its resting size, holding a
// padlock. While the camera looks it grows under it with the ring round the
// padlock; a match closes the ring and opens the padlock, a miss turns both
// red and shakes the island. As the lock lets go the padlock gives way to the
// bar's own time, so the island left on screen is the bar's.
Item {
    id: root

    // For the surface to fade the padlock with the rest of the type while the
    // island itself stays.
    property real held: 1

    readonly property bool attached: SettingsService.islandAttached
    readonly property int notchPad: root.attached ? Theme.barTopMargin : 0

    readonly property bool scanning: LockService.faceScanning
    readonly property bool matched: LockService.faceMatched
    property bool missed: false

    // Back to rest as the lock lets go, so the island left is the bar's.
    readonly property bool open: !LockService.leaving
        && (root.scanning || root.matched || root.missed)

    readonly property int restWidth: ModuleService.restWidth
    readonly property int restHeight: Theme.capsuleHeight + root.notchPad
    readonly property int openWidth: 176
    readonly property int openHeight: 124 + root.notchPad

    property real shake: 0

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: root.shake
    y: root.attached ? 0 : Theme.barTopMargin
    width: root.open ? root.openWidth : root.restWidth
    height: root.open ? root.openHeight : root.restHeight

    Behavior on width {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }
    Behavior on height {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // Red for as long as the island shakes, then back to rest.
    Timer {
        id: missHold

        interval: Theme.durationMorph * 2
        onTriggered: root.missed = false
    }

    SequentialAnimation {
        id: refusal

        loops: 2
        NumberAnimation { target: root; property: "shake"; to: -10; duration: 55; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "shake"; to: 10; duration: 55; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: 55; easing.type: Easing.OutCubic }
    }

    Connections {
        target: LockService
        function onFaceMissed(): void {
            root.missed = true
            missHold.restart()
            refusal.restart()
        }
    }

    // ── SHAPE ───────────────────────────────────────────────────────────────

    NotchFillet {
        anchors.right: body.left
        anchors.top: parent.top
        visible: root.attached
        mirrored: true
    }

    NotchFillet {
        anchors.left: body.right
        anchors.top: parent.top
        visible: root.attached
    }

    Rectangle {
        id: body

        anchors.fill: parent
        color: Theme.island
        radius: root.open ? 2 * Theme.radiusLarge + 8
                          : Math.min(root.height / 2, Theme.radiusLarge + 4)
        topLeftRadius: root.attached ? 0 : body.radius
        topRightRadius: root.attached ? 0 : body.radius

        Behavior on radius {
            NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
        }
    }

    // ── CONTENT ─────────────────────────────────────────────────────────────
    //
    // Centred as the bar centres its own: half the notch's pad above, half
    // below.

    Item {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.notchPad / 2
        anchors.top: parent.top
        anchors.topMargin: root.notchPad / 2

        FaceRing {
            anchors.centerIn: parent
            diameter: 72
            scanning: root.scanning
            closed: root.matched
            hue: root.matched ? Theme.indicatorGood
                : root.missed ? Theme.indicatorBad
                : Theme.text
            shown: root.open ? 1 : 0

            Behavior on shown {
                NumberAnimation { duration: Theme.durationMorph; easing.type: Easing.OutCubic }
            }
        }

        Padlock {
            anchors.centerIn: parent
            scale: root.open ? 1.5 : 0.8
            opened: root.matched || LockService.leaving
            tint: root.missed ? Theme.indicatorBad : Theme.text
            opacity: root.held

            Behavior on scale {
                NumberAnimation { duration: Theme.durationMorph; easing.type: Easing.OutBack }
            }
        }

        // The bar's time, drawn as the bar's clock draws it, arriving as the
        // padlock goes.
        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Row {
            anchors.centerIn: parent
            spacing: 8
            opacity: 1 - root.held

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, SettingsService.clockShowsSeconds
                    ? SettingsService.clockFormat.replace("mm", "mm:ss")
                    : SettingsService.clockFormat)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: SettingsService.clockShowsDate
                text: Qt.formatDateTime(clock.date, "ddd d MMM")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }
        }
    }
}
