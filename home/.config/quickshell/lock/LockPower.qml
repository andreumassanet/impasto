// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L O C K   P O W E R                                                    │
// │   power actions on the lock screen                                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"

// Power off and restart on the lock screen, matching the login screen. No
// suspend: it already has a shortcut and a button in the session panel.
//
// Armed on the first click and run on the second, SessionService's rule for
// anything that ends a session: there is unsaved work behind this surface.
Row {
    id: root

    property string armed: ""

    spacing: 8

    readonly property Timer disarm: Timer {
        interval: 3000
        onTriggered: root.armed = ""
    }

    component Chip: Rectangle {
        id: chip

        property string action: ""
        property string glyph: ""
        property string caption: ""

        readonly property bool isArmed: root.armed === chip.action

        width: chip.isArmed ? name.implicitWidth + Theme.capsuleHeight + 16
                            : Theme.capsuleHeight
        height: Theme.capsuleHeight
        radius: Theme.radiusPill

        // Pure black, like the clock's chip and the greeter's buttons. Hover
        // lifts the fill and the outline stays fixed: animating `islandBorder`
        // to `hairline` passes through a brighter 50% white and flashes.
        color: {
            if (chip.isArmed)
                return Theme.indicatorBad
            return area.containsMouse ? Theme.islandSurfaceHover : Theme.island
        }
        border.width: 1
        border.color: chip.isArmed ? Theme.indicatorBad : Theme.islandBorder

        Behavior on width {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

        Row {
            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                font.family: Theme.fontMono
                font.pixelSize: 15
                color: Theme.text
                opacity: chip.isArmed || area.containsMouse ? 1 : 0.75

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }

            Text {
                id: name

                anchors.verticalCenter: parent.verticalCenter
                visible: chip.isArmed
                text: chip.caption
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (chip.isArmed) {
                    root.armed = ""
                    root.disarm.stop()
                    SessionService.run(chip.action)
                    return
                }
                root.armed = chip.action
                root.disarm.restart()
            }
        }
    }

    Chip {
        action: "reboot"
        glyph: "󰜉"
        caption: Tr.t("Restart")
    }

    Chip {
        action: "shutdown"
        glyph: "󰐥"
        caption: Tr.t("Shut down")
    }
}
