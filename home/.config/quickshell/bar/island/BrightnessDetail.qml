// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B R I G H T N E S S   D E T A I L                                      │
// │   every screen's brightness, one bar each                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"

// Opened from the control centre's brightness when more than one screen can
// be dimmed: a level for each, named, as the sound page is laid out. The
// slider in the control centre sets the focused screen. Sizes are
// `BrightnessService`'s.
ColumnLayout {
    id: root

    signal back()

    spacing: Theme.detailGap

    Component.onCompleted: BrightnessService.refresh()

    DetailHeading {
        title: Tr.t("Brightness")
        detail: Tr.t("%1 screens").arg(BrightnessService.dimmable.length)
        onBack: root.back()
    }

    DetailSection {
        title: Tr.t("Screens")

        Repeater {
            model: BrightnessService.dimmable

            LevelRow {
                id: screen

                required property var modelData

                glyph: screen.modelData.icon
                name: screen.modelData.title
                value: screen.modelData.slider
                from: BrightnessService.sliderMinimum
                onMoved: value => screen.modelData.setSlider(value)
            }
        }
    }

    Item { Layout.fillHeight: true }
}
