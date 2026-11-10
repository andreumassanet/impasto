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

    spacing: Theme.cardGap

    Component.onCompleted: {
        if (BluetoothService.enabled)
            BluetoothService.setDiscovering(true)
    }
    Component.onDestruction: BluetoothService.setDiscovering(false)

    // The heading a module's card has (`ModuleCard`), with the back arrow in
    // front of it when there is somewhere to go back to.
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.cardMark
        spacing: 12

        IconButton {
            icon: "󰅁"
            iconSize: 14
            visible: root.backable
            onClicked: root.back()
        }

        RingIndicator {
            Layout.preferredWidth: Theme.cardMark
            Layout.preferredHeight: Theme.cardMark
            thickness: 3
            progress: 0
            trackColor: Theme.indicatorDim

            Text {
                anchors.centerIn: parent
                text: BluetoothService.icon
                font.family: Theme.fontMono
                font.pixelSize: 18
                color: BluetoothService.enabled ? Theme.indicator : Theme.textMuted
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: "Bluetooth"
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                Layout.fillWidth: true
                text: BluetoothService.enabled
                    ? (BluetoothService.discovering ? Tr.t("Looking for devices…") : BluetoothService.summary)
                    : Tr.t("Adapter off")
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }
        }

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
        text: BluetoothService.enabled ? Tr.t("Nothing found yet") : Tr.t("Turn Bluetooth on to see devices")
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
                ? Theme.surfaceHoverIn(QsWindow.window) : Theme.surfaceIn(QsWindow.window)
            border.color: entry.modelData.connected ? Theme.accent : Theme.borderIn(QsWindow.window)
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
                            if (entry.modelData.pairing) return Tr.t("Pairing…")
                            const bits = []
                            bits.push(Tr.t(entry.modelData.connected ? "Connected"
                                : (entry.modelData.paired ? "Paired" : "Available")))
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

            // A device paired from here connects once the pairing is done.
            property bool wasPairing: false

            Connections {
                target: entry.modelData

                function onPairedChanged(): void {
                    if (entry.wasPairing && entry.modelData.paired) {
                        entry.wasPairing = false
                        entry.modelData.connected = true
                    }
                }
            }

            MouseArea {
                id: entryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // The right button forgets a paired device, as the bin does.
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        if (entry.modelData.paired)
                            BluetoothService.forgetDevice(entry.modelData)
                        return
                    }
                    if (!entry.modelData.paired)
                        entry.wasPairing = true
                    BluetoothService.connectDevice(entry.modelData)
                }
            }

            // Forget, on a paired device under the pointer. Declared after
            // the row's area so a click here goes here.
            Text {
                anchors.right: parent.right
                anchors.rightMargin: entry.modelData.connected ? 34 : 12
                anchors.verticalCenter: parent.verticalCenter
                visible: entry.modelData.paired && (entryMouse.containsMouse || forgetMouse.containsMouse)
                text: "󰆴"
                font.family: Theme.fontMono
                font.pixelSize: 14
                color: forgetMouse.containsMouse ? Theme.red : Theme.textMuted

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                MouseArea {
                    id: forgetMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BluetoothService.forgetDevice(entry.modelData)
                }
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
                    ? Tr.t("1 unnamed device nearby")
                    : Tr.t("%1 unnamed devices nearby").arg(BluetoothService.unnamedCount)
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
