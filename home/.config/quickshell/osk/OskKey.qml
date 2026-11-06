// One key of the on-screen keyboard (end_4 ii's OskKey, drawn the
// impasto way). A Shift tapped twice quickly locks it.

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"

Rectangle {
    id: root

    required property var keyData

    readonly property string label: root.keyData.label
    readonly property string keytype: root.keyData.keytype
    // Fn has none: it is drawn but sends nothing.
    readonly property int keycode: root.keyData.keycode ?? -1
    readonly property string shape: root.keyData.shape
    readonly property bool isShift: OskService.shiftKeys.includes(root.keycode)
    property bool latched: false
    readonly property bool lit: mouse.pressed || root.latched || (root.isShift && OskService.shiftMode > 0)

    readonly property real unit: 46
    readonly property var widths: ({ normal: 1, fn: 1, tab: 1.6, caps: 1.9, shift: 2.5, control: 1.3 })
    readonly property var heights: ({ fn: 0.7 })

    implicitWidth: root.unit * (root.widths[root.shape] ?? 1)
    implicitHeight: root.unit * (root.heights[root.shape] ?? 1)
    Layout.fillWidth: root.shape === "space" || root.shape === "expand"
    radius: Theme.radiusMedium
    visible: root.shape !== "empty"
    color: root.lit ? Theme.accent : mouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface
    border.color: Theme.islandBorder

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    Text {
        anchors.centerIn: parent
        text: {
            const lower = root.label.toLowerCase()
            if (lower === "backspace") return "󰁮"
            if (lower === "enter" || lower === "return") return "󰌑"
            if (OskService.shiftMode === 2) return root.keyData.labelCaps || root.keyData.labelShift || root.label
            if (OskService.shiftMode === 1) return root.keyData.labelShift || root.label
            return root.label
        }
        font.family: /^[󰁮󰌑]$/.test(text) ? Theme.fontMono : Theme.fontFamily
        font.pixelSize: root.shape === "fn" ? Theme.fontSizeSmall : Theme.fontSizeLarge
        color: root.lit ? Theme.accentText : Theme.text
    }

    Timer {
        id: doubleTap

        interval: 300
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.keycode >= 0
        onPressed: {
            OskService.press(root.keycode)
            if (root.isShift && OskService.shiftMode === 0)
                OskService.shiftMode = 1
        }
        onReleased: {
            if (root.keytype === "normal") {
                OskService.release(root.keycode)
                if (OskService.shiftMode === 1)
                    OskService.releaseShiftKeys()
            } else if (root.isShift) {
                if (OskService.shiftMode === 1 && doubleTap.running)
                    OskService.shiftMode = 2
                else if (OskService.shiftMode === 1)
                    doubleTap.restart()
                else
                    OskService.releaseShiftKeys()
            } else if (root.keytype === "modkey") {
                root.latched = !root.latched
                if (!root.latched)
                    OskService.release(root.keycode)
            }
        }
    }
}
