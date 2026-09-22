// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L U E T O O T H   D E T A I L                                        │
// │   paired and nearby bluetooth devices                                    │
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

// The list behind the Bluetooth tile. `connected` is writable on a device, so
// connecting is a property assignment and the state comes back over D-Bus.
//
// Discovery runs only while this view exists: a lingering scan costs power and
// floods the list.
ColumnLayout {
    id: root

    signal back()

    // No back arrow when opened from the bar, where there is nothing to go
    // back to.
    property bool backable: true

    // Unnamed devices are folded away rather than dropped.
    property bool showUnnamed: false

    readonly property var listed: root.showUnnamed
        ? BluetoothService.devices.concat(BluetoothService.unnamedDevices)
        : BluetoothService.devices

    spacing: 12

    Component.onCompleted: {
        if (BluetoothService.enabled)
            BluetoothService.setDiscovering(true)
    }
    Component.onDestruction: BluetoothService.setDiscovering(false)

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
                text: "Bluetooth"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                text: BluetoothService.enabled
                    ? (BluetoothService.discovering ? "Looking for devices…" : BluetoothService.summary)
                    : "Adapter off"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }
        }

        Item { Layout.fillWidth: true }

        ToggleSwitch {
            checked: BluetoothService.enabled
            onToggled: checked => {
                BluetoothService.toggle()
                BluetoothService.setDiscovering(checked)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.listed.length === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: BluetoothService.enabled ? "Nothing found yet" : "Turn Bluetooth on to see devices"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.listed.length > 0
        clip: true
        spacing: 4
        model: ScriptModel {
            values: root.listed
            comparisonMode: ObjectComparison.Identity
        }
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: entry

            required property var modelData

            width: ListView.view.width
            height: 48
            radius: Theme.radiusMedium
            color: entry.modelData.connected || entryMouse.containsMouse
                ? Theme.islandSurfaceHover : Theme.islandSurface
            border.color: entry.modelData.connected ? Theme.accent : Theme.islandBorder
            border.width: 1

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: BluetoothService.deviceIcon(entry.modelData)
                    font.family: Theme.fontMono
                    font.pixelSize: 15
                    color: entry.modelData.connected ? Theme.accent : Theme.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        // The address rather than BlueZ's Alias, which for a
                        // device with no name is the address with dashes.
                        text: BluetoothService.isNamed(entry.modelData)
                            ? entry.modelData.name : entry.modelData.address
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: entry.modelData.connected ? Font.DemiBold : Font.Normal
                        color: entry.modelData.connected ? Theme.accent : Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (entry.modelData.pairing) return "Pairing…"
                            const bits = []
                            bits.push(entry.modelData.connected ? "Connected"
                                : (entry.modelData.paired ? "Paired" : "Available"))
                            if (entry.modelData.batteryAvailable)
                                bits.push(`${Math.round(entry.modelData.battery * 100)}%`)
                            return bits.join(" · ")
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: Theme.textMuted
                    }
                }

                Text {
                    visible: entry.modelData.connected
                    text: "󰄬"
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    color: Theme.accent
                }
            }

            MouseArea {
                id: entryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BluetoothService.connectDevice(entry.modelData)
            }
        }
    }

    // The fold for devices without a name.
    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: BluetoothService.unnamedCount > 0
        implicitWidth: unnamedRow.implicitWidth + 16
        implicitHeight: unnamedRow.implicitHeight + 8

        Row {
            id: unnamedRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: root.showUnnamed ? "󰅃" : "󰅀"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: unnamedMouse.containsMouse ? Theme.text : Theme.textMuted
            }

            Text {
                text: BluetoothService.unnamedCount === 1
                    ? "1 unnamed device nearby"
                    : `${BluetoothService.unnamedCount} unnamed devices nearby`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: unnamedMouse.containsMouse ? Theme.text : Theme.textMuted
            }
        }

        MouseArea {
            id: unnamedMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showUnnamed = !root.showUnnamed
        }
    }
}
