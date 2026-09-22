// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N E T W O R K   D E T A I L                                            │
// │   wifi networks in range                                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// The list behind the Wi-Fi tile. A known network connects on click; a new
// one opens a password field in place.
ColumnLayout {
    id: root

    signal back()

    // No back arrow when opened from the bar, where there is nothing to go
    // back to.
    property bool backable: true

    property string expanded: ""

    spacing: 12

    Component.onCompleted: NetworkService.scan(false)

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        IconButton {
            icon: "󰅁"
            iconSize: 14
            visible: root.backable
            onClicked: root.back()
        }

        ColumnLayout {
            spacing: 1

            Text {
                text: "Wi-Fi"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                text: NetworkService.radioOn
                    ? (NetworkService.scanning ? "Scanning…" : NetworkService.connectionName)
                    : "Radio off"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: NetworkService.radioOn
            text: "Rescan"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: rescanMouse.containsMouse ? Theme.accent : Theme.textMuted

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            MouseArea {
                id: rescanMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                enabled: !NetworkService.scanning
                cursorShape: Qt.PointingHandCursor
                onClicked: NetworkService.scan(true)
            }
        }

        ToggleSwitch {
            checked: NetworkService.radioOn
            onToggled: checked => NetworkService.setWifi(checked)
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: NetworkService.networks.length === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: NetworkService.radioOn
            ? (NetworkService.scanning ? "Looking for networks…" : "Nothing in range")
            : "Turn Wi-Fi on to see what is around"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: NetworkService.networks.length > 0
        clip: true
        spacing: 4
        model: ScriptModel {
            values: NetworkService.networks
            objectProp: "ssid"
        }
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: entry

            required property var modelData
            readonly property bool open: root.expanded === entry.modelData.ssid
            readonly property bool busy: NetworkService.busySsid === entry.modelData.ssid

            width: ListView.view.width
            height: entry.open ? 88 : 48
            radius: Theme.radiusMedium
            color: entry.modelData.active || entryMouse.containsMouse || entry.open
                ? Theme.islandSurfaceHover : Theme.islandSurface
            border.color: entry.modelData.active ? Theme.accent : Theme.islandBorder
            border.width: 1
            clip: true

            Behavior on height {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 10

                    Text {
                        text: NetworkService.strengthIcon(entry.modelData.signal)
                        font.family: Theme.fontMono
                        font.pixelSize: 15
                        color: entry.modelData.active ? Theme.accent : Theme.textMuted
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.ssid
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: entry.modelData.active ? Font.DemiBold : Font.Normal
                            color: entry.modelData.active ? Theme.accent : Theme.text
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (entry.busy) return "Working…"
                                if (entry.modelData.active) return "Connected"
                                const bits = [`${entry.modelData.signal}%`]
                                if (entry.modelData.secure) bits.push("secured")
                                if (entry.modelData.known) bits.push("saved")
                                return bits.join(" · ")
                            }
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: Theme.textMuted
                        }
                    }

                    Text {
                        visible: entry.modelData.secure && !entry.modelData.active
                        text: "󰌾"
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        color: Theme.textMuted
                    }

                    Text {
                        visible: entry.modelData.active
                        text: "󰄬"
                        font.family: Theme.fontMono
                        font.pixelSize: 13
                        color: Theme.accent
                    }
                }

                // Only drawn once the row has opened for it.
                RowLayout {
                    Layout.fillWidth: true
                    visible: entry.open
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: Theme.radiusSmall
                        color: Theme.island
                        border.color: password.activeFocus ? Theme.accent : Theme.islandBorder
                        border.width: 1

                        TextInput {
                            id: password

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            selectByMouse: true

                            onAccepted: {
                                NetworkService.connect(entry.modelData.ssid, password.text)
                                root.expanded = ""
                            }
                            Keys.onEscapePressed: root.expanded = ""

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: password.text === ""
                                text: "Password"
                                font: password.font
                                color: Theme.textMuted
                            }
                        }
                    }

                    PillButton {
                        text: "Connect"
                        active: true
                        onClicked: {
                            NetworkService.connect(entry.modelData.ssid, password.text)
                            root.expanded = ""
                        }
                    }
                }
            }

            MouseArea {
                id: entryMouse
                anchors.fill: parent
                anchors.bottomMargin: entry.open ? 44 : 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (entry.modelData.active) {
                        NetworkService.disconnect(entry.modelData.ssid)
                    } else if (entry.modelData.known || !entry.modelData.secure) {
                        NetworkService.connect(entry.modelData.ssid)
                    } else {
                        root.expanded = entry.open ? "" : entry.modelData.ssid
                    }
                }
            }
        }
    }
}
