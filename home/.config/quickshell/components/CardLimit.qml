// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A R D   L I M I T                                                    │
// │   one limit on a card · its name, how much is used, when it renews       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"

// A share of something that renews: a usage window, a charge. An unknown
// share is a dash and an empty bar, never 0 %. `resets` (epoch seconds) is
// said as short as it can be — "2 h 05" within the day, "Thu 14:00" past it —
// unless a `note` says something else.
RowLayout {
    id: root

    property string name: ""
    property real fraction: 0
    property bool known: true
    property real resets: 0
    property string note: ""
    property color tint: Theme.indicator

    readonly property string when: {
        if (root.resets <= 0)
            return ""
        const left = root.resets * 1000 - clock.date.getTime()
        if (left <= 0)
            return Tr.t("renewed")
        const minutes = Math.ceil(left / 60000)
        if (minutes < 60)
            return `${minutes} min`
        if (minutes < 24 * 60)
            return `${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, "0")}`
        // To the nearest minute: a window ends at 16:59:59.
        return Qt.formatDateTime(new Date(Math.round(root.resets / 60) * 60000), "ddd HH:mm")
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.resets > 0
    }

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.cardRow
    spacing: 10

    Text {
        Layout.preferredWidth: Theme.cardLabel
        text: root.name
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.text
    }

    UsageBar {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 40
        implicitHeight: 6
        progress: root.known ? root.fraction : 0
        fillColor: root.tint
    }

    Text {
        Layout.preferredWidth: 36
        horizontalAlignment: Text.AlignRight
        text: root.known ? `${Math.round(root.fraction * 100)}%` : "—"
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.text
    }

    Text {
        Layout.preferredWidth: 66
        horizontalAlignment: Text.AlignRight
        text: root.note !== "" ? root.note : root.when
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        color: Theme.textMuted
    }
}
