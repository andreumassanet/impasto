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
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// One side of the bar: the layout's ids drawn as capsules. The workspaces and
// the tray get a capsule of their own; everything else shares one until a
// `split` starts the next. A capsule holding a single item takes that item's shape
// (`BarChip.alone`). Clicks open in the island (`Bar.qml`).
Row {
    id: root

    // The layout's pieces, `{ id, shape, figure }`
    // (`SettingsService.barItems`).
    property var entries: []

    // Inside the one capsule, where the band is already the ground.
    property bool chromeless: false
    // Straight on the wallpaper, with no ground of any kind under it.
    property bool overWallpaper: false

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
            } else if (item.id === "workspaces" || item.id === "tray") {
                flush()
                out.push({ kind: item.id, items: [] })
            } else {
                chips.push(item)
            }
        }
        flush()
        return out
    }

    spacing: root.chromeless ? 14 : Theme.capsuleSpacing

    Repeater {
        model: ScriptModel {
            values: root.groups
        }

        Group {
            required property var modelData

            kind: modelData.kind
            items: modelData.items
            chromeless: root.chromeless
            overWallpaper: root.overWallpaper
        }
    }

    component Group: Item {
        id: group

        property string kind: "chips"
        property var items: []
        property bool chromeless: false
        property bool overWallpaper: false

        readonly property bool workspaces: group.kind === "workspaces"
        readonly property bool tray: group.kind === "tray"
        // A capsule drawn by its own widget rather than of chips.
        readonly property bool own: group.workspaces || group.tray

        // The items this machine has. A capsule with none (no battery, no
        // backlight on a desktop) is not drawn.
        readonly property var present:
            group.items.filter(item => ModuleService.shows(item.id, item.when))

        readonly property bool alone: !group.own && group.present.length === 1

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

        // The tray with no icons in it is not drawn.
        visible: group.workspaces || (group.tray ? TrayService.items.length > 0
                                                 : group.present.length > 0)
        width: group.own
            ? (strip.item ? strip.item.implicitWidth : 0)
            : chips.implicitWidth + 2 * group.pad
        height: Theme.capsuleHeight

        // Per-capsule shadow. In the one-capsule style the bar casts a single
        // flattened one instead (`Bar.qml`). Under a ground that lets the
        // screen through, the capsule's own shape is cut out of it, so it
        // falls outside and does not show through.
        Item {
            id: cast

            visible: Theme.barShadowShown && !group.chromeless
            x: -shadow.reach
            y: -shadow.reach
            width: group.width + 2 * shadow.reach
            height: group.height + 2 * shadow.reach

            layer.enabled: cast.visible && !Theme.solid
            layer.effect: MultiEffect {
                maskEnabled: true
                maskInverted: true
                maskSource: cutout
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Item {
                id: shadow

                readonly property int reach: Theme.shadowBarRange + 4
                readonly property int spread: Theme.shadowBarSpread

                anchors.fill: parent
                opacity: Theme.shadowOpacity

                layer.enabled: cast.visible
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

            Item {
                id: cutout

                anchors.fill: parent
                visible: false
                layer.enabled: !Theme.solid

                Rectangle {
                    x: shadow.reach
                    y: shadow.reach
                    width: group.width
                    height: group.height
                    radius: group.height / 2
                }
            }
        }

        Loader {
            id: strip

            active: group.own
            sourceComponent: group.tray ? trayCapsule : workspaceStrip
        }

        Component {
            id: workspaceStrip
            WorkspacesWidget {
                chromeless: group.chromeless
                overWallpaper: group.overWallpaper
            }
        }

        Component {
            id: trayCapsule
            TrayWidget { chromeless: group.chromeless }
        }

        Rectangle {
            anchors.fill: parent
            visible: !group.own
            radius: height / 2
            color: group.chromeless ? "transparent" : Theme.islandGround
            border.color: Theme.islandRim
            border.width: group.chromeless || group.bare ? 0 : 1

            GlassSheen {
                shape: parent
                visible: Theme.glass && !group.chromeless && !group.bare
            }

            Row {
                id: chips

                x: group.pad
                height: Theme.capsuleHeight

                Repeater {
                    model: ScriptModel {
                        values: group.items
                    }

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
        }
    }
}
