// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A T T E R Y   M O D U L E                                            │
// │   battery · charge ring, time remaining when open                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"
import "../widgets"

// The ring shows the charge; the detail adds what UPower reports beyond it:
// time remaining, charge direction, power draw and cell health, and the power
// profile of power-profiles-daemon, which the card can change.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face; `ChipFace` draws the percentage beside it.
    Component {
        id: chip

        Item {
            BatteryWidget {
                id: mark
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.capsuleHeight
            }
        }
    }

    Component {
        id: detail

        ModuleCard {
            title: "Battery"
            // The estimate is blank for a minute or two after the cable
            // changes, so the state stands on its own until it arrives.
            subtitle: BatteryService.estimate !== ""
                ? `${BatteryService.stateWord} · ${BatteryService.estimate}`
                : BatteryService.stateWord
            figure: `${BatteryService.percent}%`
            figureColor: ModuleService.tintOf("battery")

            mark: BatteryWidget {
                anchors.fill: parent
                size: Theme.cardMark
            }

            CardFact {
                name: BatteryService.charging ? "Going in" : "Coming out"
                value: BatteryService.watts > 0 ? `${BatteryService.watts.toFixed(1)} W` : "—"
            }

            CardFact {
                name: "Energy"
                value: BatteryService.energyCapacity > 0
                    ? `${BatteryService.energy.toFixed(1)} of ${BatteryService.energyCapacity.toFixed(1)} Wh`
                    : `${BatteryService.energy.toFixed(1)} Wh`
            }

            // Cells that don't report health get nothing here, not a guess.
            CardLimit {
                visible: BatteryService.healthKnown
                name: "Health"
                fraction: BatteryService.health / 100
                tint: BatteryService.health < 60 ? Theme.indicatorWarn : Theme.indicatorGood
                note: "of new"
            }

            // Only where power-profiles-daemon answers.
            SegmentedControl {
                visible: SystemService.powerAvailable
                Layout.fillWidth: true
                stretch: true
                labelled: true
                options: SystemService.powerProfiles.map(profile =>
                    ({ id: profile.id, label: Tr.t(profile.label), icon: profile.icon }))
                current: SystemService.powerProfile
                onSelected: id => SystemService.setPowerProfile(id)
            }
        }
    }
}
