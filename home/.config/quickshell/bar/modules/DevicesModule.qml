// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D E V I C E S   M O D U L E                                            │
// │   the batteries of connected devices · a row each                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The devices that report a battery (`DeviceService`), a level bar each. A
// chip on the bar opens it. Its height is declared in `ModuleService.openSize`
// from the number of devices.
Item {
    id: root

    property bool compact: false

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    ModuleCard {
        id: card

        anchors.fill: parent
        title: "Devices"
        subtitle: DeviceService.devices.length === 1 ? "1 device with a battery"
            : `${DeviceService.devices.length} devices with a battery`

        mark: Text {
            anchors.centerIn: parent
            text: "󰂯"
            font.family: Theme.fontMono
            font.pixelSize: 20
            color: Theme.indicator
        }

        Repeater {
            model: DeviceService.devices

            CardLimit {
                required property var modelData

                name: `${modelData.glyph}  ${modelData.name}`
                fraction: modelData.level
                tint: modelData.level < 0.2 ? Theme.indicatorBad : Theme.indicatorGood
                // The row prints the level itself; the note is only for charging.
                note: modelData.charging ? "charging" : ""
            }
        }
    }
}
