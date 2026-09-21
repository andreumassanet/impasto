// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L O C K   S U R F A C E                                                │
// │   lock surface for one screen · blurred desktop behind                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import Quickshell

import "../theme"
import "../services"
import "../bar/widgets"

// One screen of the lock: the desktop blurred behind, the island where the
// bar has it, the clock, and the battery in its corner. A key or a click wakes
// it: the clock rises and the account, the field and the power buttons come
// in underneath; Escape or a while untouched sends them away again. Blurred
// enough that text on the desktop cannot be read.
Item {
    id: root

    signal submitted(string password)

    // Focus lands here and stays.
    function claim(): void {
        account.claim()
    }

    // 1 while the lock holds, 0 once it is answered: the type goes and the
    // blur relaxes, so the desktop is what is left when the lock falls.
    property real held: LockService.leaving ? 0 : 1

    Behavior on held {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Easing.InOutCubic }
    }

    // The shot is every screen at once, so only a lone screen can show it
    // sharp; with more, the blur stays and only the type goes.
    readonly property real clearing: Quickshell.screens.length === 1 ? root.held : 1

    // 0 at rest, 1 awake: what only an awake screen shows fades and rises
    // with it.
    property real awake: LockService.awake ? 1 : 0

    Behavior on awake {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // A screen put back to rest takes its half-typed password with it.
    Connections {
        target: LockService
        function onAwakeChanged(): void {
            if (!LockService.awake)
                account.clear()
        }
    }

    // The pointer moving is somebody there, and a reason to look for a face;
    // a click wakes the screen as a key does.
    HoverHandler {
        onPointChanged: LockService.wake()
    }

    TapHandler {
        onTapped: {
            LockService.wake()
            LockService.rouse()
            account.claim()
        }
    }

    // ── BACKGROUND ──────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: Theme.island
    }

    Image {
        id: shot

        anchors.fill: parent
        source: LockService.shotSource
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
    }

    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        blurEnabled: true
        blur: root.clearing
        // Enough to make text unreadable while the desktop stays recognisable.
        blurMax: SettingsService.lockBlur
        // Barely darkened: a dark desktop dimmed further looks broken. The text
        // has its own shadow and every capsule is opaque, so the background
        // only needs to be blurred.
        brightness: -0.05 * root.clearing
        saturation: 0
    }

    // The lightest of washes, for separation rather than contrast.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.18 * root.clearing
    }

    // ── STATUS ──────────────────────────────────────────────────────────────

    // A ring chip as on the bar, in the bar's corner: pure black with no
    // border, since the ring is the outline.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: Theme.barTopMargin
        width: Theme.capsuleHeight
        height: Theme.capsuleHeight
        radius: Theme.radiusPill
        color: Theme.island
        visible: BatteryService.available
        opacity: root.held

        BatteryWidget {
            anchors.centerIn: parent
            size: Theme.capsuleHeight
        }
    }

    LockIsland {
        held: root.held
    }

    // ── CLOCK ───────────────────────────────────────────────────────────────
    //
    // Just above the middle at rest; awake, it rises under the island and
    // steps back a little for the account. Shadowed rather than dimming the
    // background, which would hide the desktop.

    Item {
        id: face

        readonly property real restY: Math.round((root.height - clock.height) / 2 - 40)
        readonly property real awakeY: Math.min(face.restY, 170)

        anchors.horizontalCenter: parent.horizontalCenter
        y: face.restY + (face.awakeY - face.restY) * root.awake
        width: clock.width
        height: clock.height
        opacity: root.held
        scale: 1 - 0.1 * root.awake
        transformOrigin: Item.Top

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowOpacity: 0.45
            shadowVerticalOffset: 3
            shadowColor: Theme.island
        }

        LockClock {
            id: clock
        }
    }

    // ── ACCOUNT ─────────────────────────────────────────────────────────────

    // Invisible at rest by opacity, never `visible`: the field inside holds
    // the keyboard from the start, so the first key is its first character.
    LockAccount {
        id: account

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60 - 24 * (1 - root.awake)
        opacity: root.awake * root.held

        onSubmitted: password => root.submitted(password)
    }

    // ── POWER ───────────────────────────────────────────────────────────────
    //
    // Bottom left at the bar's margin, where the login screen has the same
    // buttons, and only while awake.

    LockPower {
        opacity: root.awake * root.held
        visible: opacity > 0
        anchors.left: parent.left
        anchors.leftMargin: Theme.barTopMargin + 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.barTopMargin + 6
    }
}
