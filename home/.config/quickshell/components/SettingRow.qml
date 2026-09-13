// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G   R O W                                                  │
// │   one preference · its name, what it says now, and its control           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"

// One setting on one line: its name and what it says now on the left, its
// control on the right. Sits in a `SettingGroup`'s card.
//
// A `locked` row is dimmed and its control disabled, but it stays in place
// (and searchable); `reason` replaces the reading to say why.
Item {
    id: root

    property string label: ""

    // What the setting says right now. One clause, no full stop; empty when
    // the control already shows it.
    property string reading: ""

    // The reading is a problem rather than a state.
    property bool alarm: false

    property bool locked: false

    // Why it is locked. One clause, usually "Set by …".
    property string reason: ""

    default property alias control: holder.data

    Layout.fillWidth: true
    implicitHeight: Math.max(48, body.implicitHeight + 16)
    opacity: root.locked ? 0.55 : 1

    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

    SettingDivider {}

    RowLayout {
        id: body

        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 16

        SettingLabel {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            label: root.label
            reading: root.reading
            alarm: root.alarm
            locked: root.locked
            reason: root.reason
        }

        Item {
            id: holder

            Layout.alignment: Qt.AlignVCenter
            enabled: !root.locked
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
