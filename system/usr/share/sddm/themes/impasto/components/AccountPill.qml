// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A C C O U N T   P I L L                                                │
// │   the account and the password · one pill, and the list above it         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects

import "."

// The lock screen's pill: the picture, the name and how to get in; from the
// first character, the same pill stretched into the field with the dots and
// a button to send them. The field holds the keyboard all along, invisible
// until there is something in it. With more than one account the picture is
// the control, and the list opens above the pill rather than pushing it.
Item {
    id: root

    property var users: null
    property int currentIndex: 0
    property bool expanded: false

    property bool authenticating: false
    property bool failed: false
    property string message: ""
    property bool capsLock: false

    signal submitted(string password)
    // A failure is bound from outside, so the pill only asks for it to go.
    signal dismissed()
    signal chosen()
    // Any key but a lone Shift or Caps Lock, and any click on the pill.
    signal woke()
    signal escaped()

    function claim(): void {
        field.forceActiveFocus()
    }

    function clear(): void {
        field.clear()
    }

    readonly property bool typing: field.text !== ""
        || root.authenticating
        || root.failed

    readonly property int pillHeight: 60
    readonly property int face: 48
    readonly property int inset: 6
    readonly property int fieldWidth: 380

    // ── ACCOUNTS ────────────────────────────────────────────────────────────
    //
    // userModel is a C++ model with no get() (bindings silently evaluate to
    // undefined). An Instantiator exposes one object per row, and objectAt()
    // keeps the bindings below in sync with the selection.

    Instantiator {
        id: rows

        model: root.users

        delegate: QtObject {
            required property string name
            required property string realName
            required property url icon
        }
    }

    readonly property bool many: rows.count > 1

    readonly property var current: rows.count > 0
        ? rows.objectAt(Math.max(0, Math.min(root.currentIndex, rows.count - 1)))
        : null

    readonly property string userName: root.current !== null ? root.current.name : ""
    readonly property string displayName: {
        if (root.current === null)
            return ""
        const real = root.current.realName
        return real !== undefined && real !== "" ? real : root.current.name
    }

    // First and last initials, as in the shell's AccountService.
    function initialsOf(label: string): string {
        const words = String(label).trim().split(/\s+/).filter(w => w.length > 0)
        if (words.length === 0)
            return "?"
        if (words.length === 1)
            return words[0].charAt(0).toUpperCase()
        return (words[0].charAt(0) + words[words.length - 1].charAt(0)).toUpperCase()
    }

    implicitWidth: root.fieldWidth
    implicitHeight: root.pillHeight + 40

    // ── PILL ────────────────────────────────────────────────────────────────

    Item {
        id: holder

        anchors.horizontalCenter: parent.horizontalCenter
        width: pill.width
        height: pill.height

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowOpacity: 0.5
            shadowVerticalOffset: 4
            shadowColor: Theme.island
        }

        // Shakes on a failed attempt; the shake is seen before the text below.
        SequentialAnimation {
            id: refusal

            loops: 2
            NumberAnimation { target: holder; property: "anchors.horizontalCenterOffset"
                to: -9; duration: 55; easing.type: Easing.OutCubic }
            NumberAnimation { target: holder; property: "anchors.horizontalCenterOffset"
                to: 9; duration: 55; easing.type: Easing.OutCubic }
            NumberAnimation { target: holder; property: "anchors.horizontalCenterOffset"
                to: 0; duration: 55; easing.type: Easing.OutCubic }
        }

        // A refused password leaves the field empty for the next try; the
        // failure keeps the pill stretched, so the shake is not a resize.
        Connections {
            target: root
            function onFailedChanged(): void {
                if (!root.failed)
                    return
                refusal.restart()
                field.clear()
            }
        }

        Rectangle {
            id: pill

            width: root.typing
                ? root.fieldWidth
                : root.inset + root.face + 14 + resting.implicitWidth + 26
            height: root.pillHeight
            radius: Theme.radiusPill
            color: Theme.island
            border.width: 1
            border.color: {
                if (root.failed)
                    return Theme.indicatorBad
                return root.typing ? Theme.accent : Theme.islandBorder
            }

            Behavior on width {
                NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
            }
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            // Anywhere on the pill wakes the screen and puts the keyboard back
            // in the field.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    root.woke()
                    field.forceActiveFocus()
                }
            }

            Avatar {
                id: picture

                x: root.inset
                anchors.verticalCenter: parent.verticalCenter
                width: root.face
                height: root.face
                source: root.current !== null ? String(root.current.icon) : ""
                initials: root.initialsOf(root.displayName)
                ring: pick.containsMouse && root.many ? Theme.accent : Theme.islandBorder

                MouseArea {
                    id: pick

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.many
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.woke()
                        root.expanded = !root.expanded
                    }
                }
            }

            // ── AT REST ─────────────────────────────────────────────────────

            Column {
                id: resting

                anchors.left: picture.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                opacity: root.typing ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }

                Row {
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.displayName
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.many
                        text: "󰅀"
                        font.family: Theme.fontMono
                        font.pixelSize: 13
                        color: Theme.textMuted
                        rotation: root.expanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                        }
                    }
                }

                Text {
                    text: qsTr("Enter your password")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeRegular
                    color: Theme.textMuted
                }
            }

            // ── TYPING ──────────────────────────────────────────────────────

            TextInput {
                id: field

                anchors.left: picture.right
                anchors.leftMargin: 18
                anchors.right: send.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.typing ? 1 : 0

                echoMode: TextInput.Password
                passwordCharacter: "●"
                passwordMaskDelay: 0
                enabled: !root.authenticating
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.letterSpacing: 3
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                clip: true

                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }

                onAccepted: {
                    if (field.text === "")
                        return
                    root.submitted(field.text)
                }

                // Typing again clears the failure state.
                onTextChanged: {
                    if (root.failed && field.text !== "")
                        root.dismissed()
                }

                // Escape is the screen's to answer: a list closes first, then
                // the field clears and the clock comes back.
                Keys.onEscapePressed: root.escaped()

                // The key still reaches the field, so the first character is
                // kept.
                Keys.onPressed: event => {
                    if (event.key !== Qt.Key_Shift && event.key !== Qt.Key_CapsLock)
                        root.woke()
                    event.accepted = false
                }
            }

            Rectangle {
                id: send

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: width / 2
                color: root.authenticating ? "transparent"
                    : (press.containsMouse ? Theme.textMuted : Theme.text)
                opacity: root.typing ? 1 : 0
                scale: root.typing ? 1 : 0.6
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                }
                Behavior on scale {
                    NumberAnimation { duration: Theme.durationMedium; easing.type: Easing.OutBack }
                }
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Text {
                    anchors.centerIn: parent
                    visible: !root.authenticating
                    text: "󰁔"
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: Theme.island
                }

                RingSpinner {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    fillColor: Theme.text
                    visible: root.authenticating
                    running: root.authenticating
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.authenticating
                    onClicked: {
                        if (field.text !== "")
                            root.submitted(field.text)
                    }
                }
            }
        }
    }

    // ── STATUS ──────────────────────────────────────────────────────────────
    //
    // Caps Lock takes priority over the PAM message.

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: holder.bottom
        anchors.topMargin: 14
        text: root.capsLock ? qsTr("Caps Lock is on") : root.message
        visible: text !== ""
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        color: root.capsLock ? Theme.indicatorWarn : Theme.indicatorBad

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.8
            shadowOpacity: 0.7
            shadowColor: Theme.island
        }
    }

    // ── ACCOUNT LIST ────────────────────────────────────────────────────────

    Capsule {
        id: sheet

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: holder.top
        anchors.bottomMargin: 12
        width: 320
        height: list.height + 16
        radius: Theme.radiusLarge
        visible: opacity > 0
        opacity: root.expanded ? 1 : 0
        scale: root.expanded ? 1 : 0.96
        transformOrigin: Item.Bottom

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        Column {
            id: list

            anchors.centerIn: parent
            width: parent.width - 16

            Repeater {
                model: root.users

                Rectangle {
                    required property int index
                    required property string name
                    required property string realName
                    required property url icon

                    width: list.width
                    height: 52
                    radius: Theme.radiusMedium
                    color: row.containsMouse ? Theme.islandSurface : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    Avatar {
                        id: mark

                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        source: String(icon)
                        initials: root.initialsOf(realName !== "" ? realName : name)
                    }

                    // Anchored so the tick's column is always reserved.
                    Text {
                        anchors.left: mark.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 38
                        anchors.verticalCenter: parent.verticalCenter
                        text: realName !== "" ? realName : name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: index === root.currentIndex ? Font.DemiBold : Font.Normal
                        color: Theme.text
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: index === root.currentIndex
                        text: "󰄬"
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                        color: Theme.accent
                    }

                    MouseArea {
                        id: row

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentIndex = index
                            root.expanded = false
                            root.chosen()
                        }
                    }
                }
            }
        }
    }
}
