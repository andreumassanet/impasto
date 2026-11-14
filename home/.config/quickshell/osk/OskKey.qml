// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O S K   K E Y                                                          │
// │   on-screen keyboard · one key, its label and what a press sends         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"

// Shift lasts one key; tapped twice quickly it stays down until tapped again.
// Ctrl, Alt and AltGr last one key, or are let go by a second press.
Rectangle {
    id: root

    required property var keyData

    readonly property string kind: root.keyData.kind ?? "key"
    readonly property real units: root.keyData.w ?? 1
    readonly property bool fn: root.keyData.fn === true
    readonly property int code: root.keyData.code ?? -1

    readonly property bool lit: mouse.pressed
        || (root.kind === "shift" && OskService.shiftMode > 0)
        || (root.kind === "latch" && OskService.latched[root.code] === true)

    readonly property string text: root.keyData.glyph
        ?? root.keyData.text
        ?? OskService.label(root.code)

    implicitWidth: root.units > 0 ? root.units * Theme.oskKey + (root.units - 1) * Theme.oskGap : Theme.oskKey
    implicitHeight: root.fn ? Theme.oskFnKey : Theme.oskKey
    Layout.fillWidth: root.units === 0
    radius: Theme.radiusMedium
    opacity: root.kind === "gap" ? 0 : 1
    color: root.lit ? Theme.accent : mouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface
    border.color: Theme.islandBorder

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    Text {
        anchors.centerIn: parent
        text: root.kind === "shift" && OskService.shiftMode === 2 ? "󰘲" : root.text
        font.family: root.keyData.glyph ? Theme.fontMono : Theme.fontFamily
        font.pixelSize: root.fn ? Theme.fontSizeSmall : Theme.fontSizeLarge
        color: root.lit ? Theme.accentText : Theme.text
    }

    // What AltGr would type, small in the corner.
    Text {
        anchors { top: parent.top; right: parent.right; margins: Theme.oskGap }
        visible: root.kind === "key" && !root.keyData.glyph && !root.keyData.text
        text: OskService.third(root.code)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        color: root.lit ? Theme.accentText : Theme.textMuted
    }

    Timer {
        id: doubleTap

        interval: 300
    }

    // Held, a key that repeats starts after a pause, like a real one.
    property bool repeated: false

    Timer {
        id: repeat

        interval: 400
        repeat: true
        onTriggered: {
            interval = 40
            root.repeated = true
            OskService.tap(root.code)
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.kind !== "gap"
        onPressed: {
            root.repeated = false
            if (root.kind === "key" && root.keyData.repeat) {
                repeat.interval = 400
                repeat.start()
            }
        }
        onCanceled: repeat.stop()
        onReleased: {
            repeat.stop()
            if (root.kind === "shift") {
                if (OskService.shiftMode === 1 && doubleTap.running)
                    OskService.setShift(2)
                else if (OskService.shiftMode === 0) {
                    OskService.setShift(1)
                    doubleTap.restart()
                } else
                    OskService.setShift(0)
            } else if (root.kind === "latch") {
                OskService.toggleLatch(root.code)
            } else if (containsMouse && !root.repeated) {
                OskService.tap(root.code)
            }
        }
    }
}
