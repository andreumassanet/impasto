// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A R   Z O N E                                                        │
// │   one side of the bar · its capsules in layout order                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects

import "../../theme"
import "../../services"
import "../modules"

// One side of the bar: the layout's ids drawn as capsules. The workspaces get
// a capsule of their own; everything else shares one until a `split` starts
// the next. A capsule holding a single item takes that item's shape
// (`BarChip.alone`). Clicks open in the island (`Bar.qml`).
Row {
    id: root

    // The layout's pieces, `{ id, shape, figure }`
    // (`SettingsService.barItems`).
    property var entries: []

    // Inside the one capsule, where the band is already the ground.
    property bool chromeless: false

    // The bar's screen, for windows the tray opens (menus).
    property var hostScreen: null
    readonly property var groups: {
        const out = []
        let chips = []
        const flush = () => {
            if (chips.length > 0)
                out.push({ kind: "chips", items: chips })
            chips = []
        }
        for (const item of root.entries) {
            if (item.id === "split") {
                flush()
            } else if (item.id === "workspaces") {
                flush()
                out.push({ kind: "workspaces", items: [] })
            } else if (item.id === "tray") {
                flush()
                out.push({ kind: "tray", items: [] })
            } else {
                chips.push(item)
            }
        }
        flush()
        return out
    }

    spacing: root.chromeless ? 14 : Theme.capsuleSpacing

    Repeater {
        model: root.groups

        Group {
            required property var modelData

            kind: modelData.kind
            items: modelData.items
            chromeless: root.chromeless
            hostScreen: root.hostScreen
        }
    }

    component Group: Item {
        id: group

        property string kind: "chips"
        property var items: []
        property bool chromeless: false
        property var hostScreen: null

        readonly property bool workspaces: group.kind === "workspaces"
        readonly property bool tray: group.kind === "tray"

        // The items this machine has. A capsule with none (no battery, no
        // backlight on a desktop) is not drawn.
        readonly property var present:
            group.items.filter(item => ModuleService.shows(item.id, item.when))

        readonly property bool alone: !group.workspaces && !group.tray && group.present.length === 1

        // A ring alone is its own outline; a capsule border a pixel outside it
        // would smudge. Not when its figure is always shown, which makes it a
        // pill.
        readonly property bool bare: {
            if (!group.alone)
                return false
            const item = group.present[0]
            return !ModuleService.isButton(item.id)
                && ModuleService.shapeOf(item.id, item.shape) === "ring"
                && ModuleService.figureOf(item.figure) !== "on"
        }

        readonly property int pad: group.chromeless || group.alone ? 0 : 4

        visible: group.workspaces
            ? strip.item
            : group.tray
                ? (trayStrip.item ? trayStrip.item.present : false)
                : group.present.length > 0
        width: group.workspaces
            ? (strip.item ? strip.item.implicitWidth : 0)
            : group.tray
                ? (trayStrip.item ? trayStrip.item.implicitWidth + 2 * group.pad : 0)
                : chips.implicitWidth + 2 * group.pad
        height: Theme.capsuleHeight

        // Per-capsule shadow. In the one-capsule style the bar casts a single
        // flattened one instead (`Bar.qml`).
        Item {
            id: shadow

            readonly property int reach: Theme.shadowBarRange + 4
            readonly property int spread: Theme.shadowBarSpread

            visible: SettingsService.windowShadow && !group.chromeless
            x: -shadow.reach
            y: -shadow.reach
            width: group.width + 2 * shadow.reach
            height: group.height + 2 * shadow.reach
            opacity: Theme.shadowOpacity

            layer.enabled: shadow.visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: Theme.shadowBarRange - Theme.shadowBarSpread
            }

            Rectangle {
                x: shadow.reach - shadow.spread
                y: shadow.reach - shadow.spread
                width: group.width + 2 * shadow.spread
                height: group.height + 2 * shadow.spread
                radius: group.height / 2 + shadow.spread
                color: Theme.shadowColor
            }
        }

        Loader {
            id: strip

            active: group.workspaces
            sourceComponent: WorkspacesWidget {
                chromeless: group.chromeless
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: !group.workspaces
            radius: height / 2
            color: group.chromeless ? "transparent" : Theme.island
            border.color: Theme.islandBorder
            border.width: group.chromeless || group.bare ? 0 : 1

            Row {
                id: chips

                x: group.pad
                height: Theme.capsuleHeight

                Repeater {
                    model: group.items

                    BarChip {
                        required property var modelData

                        anchors.verticalCenter: parent.verticalCenter
                        moduleId: modelData.id
                        ownShape: modelData.shape
                        ownFigure: modelData.figure
                        ownWhen: modelData.when ?? ""
                        alone: group.alone
                    }
                }
            }

            Loader {
                id: trayStrip

                active: group.tray
                x: group.pad
                height: Theme.capsuleHeight

                sourceComponent: TrayModule {
                    hostScreen: group.hostScreen
                }
            }
        }
    }
}
