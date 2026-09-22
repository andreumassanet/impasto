// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O N T R I B U T I O N   G R I D                                      │
// │   github contribution grid                                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../theme"

// GitHub contribution graph, shared by the island detail and both desktop
// themes. Cell size follows the height (seven rows); the width decides how
// many of the most recent weeks are shown. Colours are fixed GitHub greens,
// not palette tokens.
Item {
    id: root

    // One array per week, seven levels each (Sunday first), 0-4, or null for
    // the partial weeks at either end.
    property var weeks: []

    // Upper bound; the width usually decides first.
    property int maxWeeks: 53

    property real spacing: 3
    property real radius: 2

    property var levels: Theme.githubLevels
    property real maxCell: 18

    // Analogue theme: embossed tiles instead of flat squares.
    property bool raised: false

    // Height alone sets the cell, capped by `maxCell`.
    readonly property real cell: {
        if (root.width <= 0 || root.height <= 0)
            return 0
        const byHeight = (root.height - 6 * root.spacing) / 7
        return Math.max(0, Math.min(byHeight, root.maxCell))
    }

    // Most recent weeks that fit at that cell size; older weeks are dropped.
    readonly property int columns: {
        const all = root.weeks ?? []
        if (root.cell <= 0 || all.length === 0)
            return 0
        const fit = Math.floor((root.width + root.spacing) / (root.cell + root.spacing))
        return Math.max(0, Math.min(fit, all.length, root.maxWeeks))
    }

    readonly property var shownWeeks: {
        const all = root.weeks ?? []
        return root.columns > 0 ? all.slice(all.length - root.columns) : []
    }

    Row {
        anchors.centerIn: parent
        spacing: root.spacing

        Repeater {
            model: ScriptModel {
                values: root.shownWeeks
            }

            // One week; `modelData` is its seven levels.
            Column {
                required property var modelData

                spacing: root.spacing

                Repeater {
                    model: modelData

                    // One day: a level 0-4, or null outside the range.
                    Rectangle {
                        required property var modelData

                        width: root.cell
                        height: root.cell
                        radius: root.radius
                        visible: root.cell > 0
                        color: modelData === null || modelData === undefined
                            ? "transparent"
                            : root.levels[modelData]

                        border.width: root.raised && color.a > 0 ? 1 : 0
                        border.color: Qt.lighter(color, 1.45)
                    }
                }
            }
        }
    }
}
