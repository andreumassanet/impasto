// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P O W E R   D E T A I L                                                │
// │   the power profile · every one the machine has, one press each          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"

// Opened from the power tile, whose press only turns performance on and off:
// here every profile the daemon offers, the night light's presets in shape.
// Sizes are `SystemService`'s.
ColumnLayout {
    id: root

    signal back()

    spacing: Theme.detailGap

    DetailHeading {
        title: Tr.t("Power")
        detail: Tr.t(SystemService.powerLabel)
        onBack: root.back()
    }

    DetailSection {
        title: Tr.t("Profile")

        Repeater {
            model: SystemService.powerProfiles

            DetailChoice {
                required property var modelData

                text: `${modelData.icon}   ${Tr.t(modelData.label)}`
                chosen: SystemService.powerProfile === modelData.id
                onPicked: SystemService.setPowerProfile(modelData.id)
            }
        }
    }

    Item { Layout.fillHeight: true }
}
