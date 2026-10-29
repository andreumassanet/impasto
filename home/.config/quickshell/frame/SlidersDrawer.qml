// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S L I D E R S   D R A W E R                                            │
// │   frame · volume, brightness and input on a side edge                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"
import "../services"
import "../components"

// Tall volume, brightness and input sliders in one column on a side edge: the
// right one, or the left when the dock is on the right. They come out when a
// level changes (a key, an app) or when the pointer reaches the edge, and go
// back a moment after; pinned, they stay out and the windows keep clear.
// With `edgeOpen` "click" the edge does nothing and the bar's corner button
// opens them instead. Mouse only: it never takes the keyboard.
EdgeDrawer {
    id: root

    // Whether this is the screen being worked on (`shell.qml`).
    property bool live: false
    property bool dragging: false

    edge: SettingsService.dockEdge === "right" ? "left" : "right"
    readonly property bool clickOpens: SettingsService.edgeOpen === "click"
    readonly property bool opened: root.clickOpens && DrawerService.slidersOpen
        && DrawerService.edgeScreen === root.screen.name
    // This screen's own brightness, looked up by name among the displays.
    readonly property var display: BrightnessService.displays.find(
        candidate => candidate.name === root.screen.name) ?? null

    reach: root.clickOpens ? 0 : 3
    along: column.implicitHeight + 2 * 16
    depth: 76
    // Pinned, it is on every screen, so the room it keeps never moves with
    // the live one.
    shown: SettingsService.slidersPinned || ((root.live || root.opened)
        && (root.opened || (!root.clickOpens && (root.edgeHovered || root.hovered))
            || linger.running || root.dragging))
    framed: root.shown && !SettingsService.slidersPinned
    reserve: SettingsService.slidersPinned ? root.depth : 0

    onShownChanged: {
        if (root.shown)
            BrightnessService.refresh()
    }

    // Opened by click, it goes back once the pointer has been in it and
    // left, or after a while if it never came.
    property bool visited: false
    onOpenedChanged: root.visited = false

    Timer {
        running: root.opened && !root.hovered && !root.dragging
        interval: root.visited ? 900 : 4000
        onTriggered: DrawerService.slidersOpen = false
    }

    Timer {
        id: linger

        interval: 1600
    }

    // A level changed somewhere else (a key, an application): show it a
    // moment. Not before the shell has settled, nor while a device is
    // reporting its own volume.
    Connections {
        target: AudioService
        enabled: root.live && OsdService.armed && !OsdService.audioSuppressed

        function onVolumeChanged(): void { linger.restart() }
        function onMutedChanged(): void { linger.restart() }
    }

    Connections {
        target: BrightnessService
        enabled: root.live && OsdService.armed

        function onAdjusted(adjusted): void { linger.restart() }
    }

    // Keeps the drawer out while the pointer leaves it slowly.
    onHoveredChanged: {
        if (root.hovered)
            root.visited = true
        else
            linger.restart()
    }

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        spacing: 14

        Level {
            glyph: AudioService.icon
            value: AudioService.volume
            dimmed: AudioService.muted
            onMoved: value => AudioService.setVolume(value)
            onGlyphClicked: AudioService.toggleMute()
        }

        Level {
            visible: root.display?.available ?? false
            glyph: root.display?.icon ?? "󰃠"
            value: root.display?.percent ?? 0
            onMoved: value => root.display?.setPercent(value)
        }

        Level {
            visible: AudioService.sourceReady
            glyph: AudioService.sourceIcon
            value: AudioService.sourceVolume
            dimmed: AudioService.sourceMuted
            onMoved: value => AudioService.setSourceVolume(value)
            onGlyphClicked: AudioService.toggleSourceMute()
        }
    }

    // A tall pill filled from the bottom, its glyph at the foot; drag or
    // scroll to set it.
    component Level: Item {
        id: level

        property string glyph: ""
        property int value: 0
        property int limit: 100
        property bool dimmed: false

        signal moved(int value)
        signal glyphClicked()

        readonly property real fraction: Math.max(0, Math.min(1, level.value / level.limit))
        // The foot holds the glyph (a click there is `glyphClicked`); the
        // value runs over the track above it, so all of it can be reached.
        readonly property int foot: 40
        readonly property real travel: level.height - level.foot

        function valueAt(y: real): int {
            return Math.round(Math.max(0, Math.min(1, 1 - y / level.travel)) * level.limit)
        }

        implicitWidth: 44
        implicitHeight: 180

        Rectangle {
            id: track

            anchors.fill: parent
            radius: width / 2
            color: Theme.islandSurface

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: level.foot + level.travel * level.fraction
                radius: width / 2
                color: level.dimmed ? Theme.indicatorDim : Theme.accent

                Behavior on height { NumberAnimation { duration: Theme.durationFast } }
            }

            Text {
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                text: level.value
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.features: { "tnum": 1 }
                color: level.fraction > 0.85 && !level.dimmed ? Theme.accentText : Theme.text
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                text: level.glyph
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLarge
                color: level.fraction > 0.12 && !level.dimmed ? Theme.accentText : Theme.text
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            // A press on the foot is the glyph's click; a drag that started
            // on the track runs on past the foot, to 0.
            property bool onFoot: false
            onPressed: mouse => {
                root.dragging = true
                onFoot = mouse.y > level.travel
                if (!onFoot)
                    level.moved(level.valueAt(mouse.y))
            }
            onPositionChanged: mouse => {
                if (pressed && !onFoot)
                    level.moved(level.valueAt(mouse.y))
            }
            onClicked: mouse => {
                if (onFoot && mouse.y > level.travel)
                    level.glyphClicked()
            }
            onReleased: {
                root.dragging = false
                linger.restart()
            }
            onWheel: wheel => {
                level.moved(Math.max(0, Math.min(level.limit, level.value + (wheel.angleDelta.y > 0 ? 5 : -5))))
                linger.restart()
            }
        }
    }
}
