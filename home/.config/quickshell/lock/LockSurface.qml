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

import "../theme"
import "../services"
import "../bar/widgets"

// One screen of the lock: the desktop blurred behind, the island where the
// bar has it, the clock, and the battery in its corner; while music plays,
// the clock small at the top and the player in the middle, its cover blurred
// behind if that is the setting. A key or a click wakes
// it: the clock rises and the account, the field and the power buttons come
// in underneath; Escape or a while untouched sends them away again. Blurred
// enough that text on the desktop cannot be read.
Item {
    id: root

    signal submitted(string password)

    // The output this surface covers, whose own picture it shows.
    property string output: ""

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

    // 0 at rest, 1 awake: what only an awake screen shows fades and rises
    // with it.
    property real awake: LockService.awake ? 1 : 0

    Behavior on awake {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // 1 while something is playing and the lock is set to show it: the clock
    // steps up and small, and the player takes the middle.
    readonly property bool music: SettingsService.lockMusic !== "off" && MediaService.available
    property real musical: root.music ? 1 : 0

    Behavior on musical {
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

    // The pointer moving on an awake screen is a reason to look for a face
    // again; a click wakes the screen as a key does. Qt sends a hover at the resting
    // position whenever the scene repaints, so only a pointer that has moved
    // counts.
    HoverHandler {
        property point last: Qt.point(-1, -1)

        onPointChanged: {
            const at = point.position
            const moved = last.x >= 0 && Math.abs(at.x - last.x) + Math.abs(at.y - last.y)
                > Qt.styleHints.startDragDistance
            if (last.x < 0 || moved)
                last = at
            if (moved)
                LockService.wake()
        }
    }

    TapHandler {
        onTapped: {
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
        source: LockService.shotSource(root.output)
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
        blur: root.held
        // Enough to make text unreadable while the desktop stays recognisable.
        blurMax: SettingsService.lockBlur
        // Barely darkened: a dark desktop dimmed further looks broken. The text
        // has its own shadow and every capsule is opaque, so the background
        // only needs to be blurred.
        brightness: -0.05 * root.held
        saturation: 0
    }

    // While music plays, its cover can stand in for the desktop: blurred to a
    // wash of its colours, darkened enough for white type, and gone as the
    // lock lets go, so the desktop is still what is left. Drawn at a tenth of
    // the screen, blurred there and stretched, so the blur reaches ten times
    // as far.
    Item {
        id: wash

        width: Math.ceil(root.width / 10)
        height: Math.ceil(root.height / 10)
        scale: 10
        transformOrigin: Item.TopLeft
        visible: opacity > 0
        opacity: cover.status === Image.Ready ? root.musical * root.held : 0
        layer.enabled: true
        layer.smooth: true

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
        }

        Image {
            id: cover

            anchors.fill: parent
            source: SettingsService.lockMusicGround === "cover" && root.music ? MediaService.artUrl : ""
            visible: false
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 96
            sourceSize.height: 96
        }

        MultiEffect {
            anchors.fill: parent
            source: cover
            blurEnabled: true
            blur: 1
            blurMax: 24
            brightness: -0.28
            saturation: 0.25
            autoPaddingEnabled: false
        }
    }

    // The lightest of washes, for separation rather than contrast.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.18 * root.held
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
        readonly property real plainY: face.restY + (face.awakeY - face.restY) * root.awake
        readonly property real plainScale: 1 - 0.1 * root.awake
        // With music, where it is awake whether awake or not — below the
        // island opened for a face — and no taller than 380.
        readonly property real musicY: face.awakeY
        readonly property real musicScale: Math.min(0.9, 380 / Math.max(1, clock.height))

        anchors.horizontalCenter: parent.horizontalCenter
        y: face.plainY + (face.musicY - face.plainY) * root.musical
        width: clock.width
        height: clock.height
        opacity: root.held
        scale: face.plainScale + (face.musicScale - face.plainScale) * root.musical
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

    // ── MUSIC ───────────────────────────────────────────────────────────────
    //
    // In the room between the clock and the account, centred in it.

    Loader {
        id: music

        readonly property real roomTop: face.musicY + clock.height * face.musicScale
        readonly property real roomBottom: account.y

        active: root.music || root.musical > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(music.roomTop + (music.roomBottom - music.roomTop - height) / 2)
        opacity: root.musical * root.held
        visible: opacity > 0

        sourceComponent: LockMedia {
            lyrics: SettingsService.lockMusic === "lyrics" && SettingsService.lyrics
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
