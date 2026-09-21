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
import "../components"
import "../bar/widgets"

// One screen of the lock: the desktop blurred behind, the battery in the top
// corner, the clock centred, the password field at the bottom, and the power
// buttons where the login screen has them. Blurred enough that text on the
// desktop cannot be read.
Item {
    id: root

    signal submitted(string password)

    // Focus lands here and stays.
    function claim(): void {
        field.forceActiveFocus()
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

    // The pointer moving is somebody there, and a reason to look for a face.
    HoverHandler {
        onPointChanged: LockService.wake()
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

    // The battery in the top corner, and nothing where the island goes, to
    // match the login screen.

    // A ring chip as on the bar: pure black with no border, since the ring is
    // the outline.
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

    // ── CLOCK ───────────────────────────────────────────────────────────────

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Shadowed rather than dimming the background, which would hide the
    // desktop.
    Item {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -60
        width: face.width
        height: face.height
        opacity: root.held

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowOpacity: 0.6
            shadowVerticalOffset: 2
            shadowColor: Theme.island
        }

    Column {
        id: face

        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, SettingsService.clockFormat)
            font.family: Theme.fontFamily
            font.pixelSize: 92
            font.weight: Font.Light
            color: Theme.text
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd d MMMM")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.text
            opacity: 0.75
        }
    }
    }

    // ── USER ────────────────────────────────────────────────────────────────
    //
    // The avatar and name, between the clock and the field. From the account
    // unless overridden in the settings, which is the same source the login
    // screen reads. Shadowed like the clock.
    Item {
        id: who

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: entry.top
        anchors.bottomMargin: 26
        width: identity.width
        height: identity.height
        opacity: root.held

        // A face not recognised shakes the picture, ring and all, the way a
        // wrong password shakes the field.
        SequentialAnimation {
            id: unknown

            loops: 2
            NumberAnimation { target: who; property: "anchors.horizontalCenterOffset"
                to: -9; duration: 55; easing.type: Easing.OutCubic }
            NumberAnimation { target: who; property: "anchors.horizontalCenterOffset"
                to: 9; duration: 55; easing.type: Easing.OutCubic }
            NumberAnimation { target: who; property: "anchors.horizontalCenterOffset"
                to: 0; duration: 55; easing.type: Easing.OutCubic }
        }

        Connections {
            target: LockService
            function onFaceMissed(): void {
                unknown.restart()
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.9
            shadowOpacity: 0.65
            shadowVerticalOffset: 2
            shadowColor: Theme.island
        }

        Column {
            id: identity

            spacing: 12

            Avatar {
                id: avatar

                anchors.horizontalCenter: parent.horizontalCenter
                width: 88
                height: 88
                source: AccountService.avatar
                initials: AccountService.initials
            }

            // The ring reaches past the gap below the picture, so the name
            // makes way while it is up.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: AccountService.name
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
                color: Theme.text
                opacity: 1 - ring.shown
            }
        }
    }

    // Outside the shadowed block above, whose layer would cut off whatever
    // reaches past its edges; it carries its own shadow instead.
    FaceRing {
        id: ring

        anchors.horizontalCenter: who.horizontalCenter
        anchors.verticalCenter: who.top
        anchors.verticalCenterOffset: avatar.height / 2
        diameter: avatar.width
        fade: root.held
    }

    // ── PASSWORD ────────────────────────────────────────────────────────────

    // The field holds focus from the start but stays invisible until the first
    // key, with a prompt shown in its place. Hidden by opacity, not `visible`:
    // an invisible item cannot hold keyboard focus.
    Item {
        id: entry

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 104
        width: 360
        height: 96
        opacity: root.held

        readonly property bool typing: field.text !== ""
            || LockService.authenticating
            || LockService.failed

        // ── PROMPT ──────────────────────────────────────────────────────────

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 12
            spacing: 10
            opacity: entry.typing ? 0 : 1
            visible: opacity > 0

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.8
                shadowOpacity: 0.7
                shadowColor: Theme.island
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌌"
                font.family: Theme.fontMono
                font.pixelSize: 17
                color: Theme.text
                opacity: 0.8
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Type your password to unlock"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.text
                opacity: 0.8
            }
        }

        // ── FIELD ───────────────────────────────────────────────────────────

        Rectangle {
            id: box

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: 320
            height: 50
            radius: Theme.radiusPill
            // Pure black, like the island: over a photograph only an opaque
            // capsule reads as a surface.
            color: Theme.island
            border.width: 1
            border.color: {
                if (LockService.failed)
                    return Theme.indicatorBad
                return field.activeFocus ? Theme.accent : Theme.islandBorder
            }

            opacity: entry.typing ? 1 : 0
            // Scales in from 94%, so it reads as the prompt turning into the
            // field.
            scale: entry.typing ? 1 : 0.94

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
            }
            Behavior on scale {
                NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
            }
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            // Shakes on a wrong password; the shake is seen before the text
            // below.
            SequentialAnimation {
                id: refusal

                loops: 2
                NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"
                    to: -9; duration: 55; easing.type: Easing.OutCubic }
                NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"
                    to: 9; duration: 55; easing.type: Easing.OutCubic }
                NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"
                    to: 0; duration: 55; easing.type: Easing.OutCubic }
            }

            Connections {
                target: LockService
                function onFailedChanged(): void {
                    if (LockService.failed)
                        refusal.restart()
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 19
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌾"
                font.family: Theme.fontMono
                font.pixelSize: 15
                color: LockService.failed ? Theme.indicatorBad : Theme.textMuted

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            TextInput {
                id: field

                anchors.left: parent.left
                anchors.leftMargin: 48
                anchors.right: parent.right
                anchors.rightMargin: 48
                anchors.verticalCenter: parent.verticalCenter

                echoMode: TextInput.Password
                passwordCharacter: "•"
                passwordMaskDelay: 0
                enabled: !LockService.authenticating && !LockService.leaving
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                clip: true

                onAccepted: {
                    root.submitted(field.text)
                    field.clear()
                }

                // Typing clears the error.
                onTextChanged: {
                    if (LockService.failed && field.text !== "")
                        LockService.failed = false
                }

                // Escape clears the field rather than leaving part of a
                // password on screen.
                Keys.onEscapePressed: field.clear()

                // Any key is somebody there; the key still reaches the field.
                Keys.onPressed: event => {
                    LockService.wake()
                    event.accepted = false
                }
            }

            // A spinner while PAM checks the password.
            Item {
                anchors.right: parent.right
                anchors.rightMargin: 17
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                visible: LockService.authenticating

                RingIndicator {
                    id: spinner

                    anchors.fill: parent
                    thickness: 2
                    progress: 0.28
                    trackColor: "transparent"
                    fillColor: Theme.accent

                    RotationAnimator {
                        target: spinner
                        running: LockService.authenticating
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: box.bottom
            anchors.topMargin: 14
            text: LockService.message
            visible: text !== ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.indicatorBad
        }
    }

    // ── POWER ───────────────────────────────────────────────────────────────
    //
    // Bottom left at the bar's margin, where the login screen has the same
    // buttons.

    LockPower {
        opacity: root.held
        anchors.left: parent.left
        anchors.leftMargin: Theme.barTopMargin + 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.barTopMargin + 6
    }
}
