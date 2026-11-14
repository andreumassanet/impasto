// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   K E Y B O A R D   M O D U L E                                          │
// │   the layouts the keyboard has · one row each, a click switches          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The keyboard's layouts, opened from the layout piece on the bar: a row for
// each layout the compositor has, the one in use marked, a click switching to
// another. The card's height is declared in `ModuleService.openSize` from the
// layout count.
Item {
    id: root

    property bool compact: false

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // A keyboard plugged in since the shell started brings its own layouts.
    Component.onCompleted: KeyboardService.refresh()

    ModuleCard {
        id: card

        anchors.fill: parent
        title: Tr.t("Keyboard")
        subtitle: KeyboardService.layout
        figure: KeyboardService.shortCode

        mark: Text {
            anchors.centerIn: parent
            text: "󰌌"
            font.family: Theme.fontMono
            font.pixelSize: 20
            color: Theme.indicator
        }

        Repeater {
            model: KeyboardService.layoutList

            CardChoice {
                required property var modelData
                required property int index

                text: modelData.name
                chosen: index === KeyboardService.activeIndex
                onPicked: KeyboardService.select(index)
            }
        }
    }
}
