// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B U T T O N S   B L O C K                                              │
// │   a block of round buttons · the session's actions, or shortcuts         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import Quickshell
import "../../../theme"
import "../../../services"

// Round buttons on the black, as many as the block's cells hold, centred in
// them. `session` is `SessionService.actions`: one that ends the session arms
// on the first click (red) and runs on the second. `shortcuts` is the doors
// chosen for this block in its inspector (`ControlsService.doorsOf`), each
// opening its panel.
Item {
    id: root

    // "session" or "shortcuts"
    property string kind: "session"
    // The grid row this face draws, for a shortcuts block's own doors.
    property string blockKey: ""

    signal panelRequested(string panel)
    signal settingsRequested()
    // Every session action closes the panel; lock would photograph it.
    signal ran()

    readonly property var entries: root.kind === "session"
        ? SessionService.actions
        : ControlsService.doorsOf(root.blockKey)

    readonly property int button: Theme.centreButton
    readonly property int gap: Theme.centreButtonGap
    readonly property int across: Math.max(1, Math.floor((root.width + root.gap) / (root.button + root.gap)))
    readonly property int down: Math.max(1, Math.floor((root.height + root.gap) / (root.button + root.gap)))
    readonly property var shown: root.entries.slice(0, root.across * root.down)

    property string armed: ""

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    Grid {
        anchors.centerIn: parent
        columns: Math.min(root.across, root.shown.length)
        spacing: root.gap

        Repeater {
            model: root.shown

            Rectangle {
                id: round

                required property var modelData

                readonly property bool isArmed: root.armed !== "" && root.armed === round.modelData.id

                width: root.button
                height: root.button
                radius: width / 2
                color: round.isArmed ? Theme.red
                    : mouse.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : Theme.surfaceIn(QsWindow.window)

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Text {
                    anchors.centerIn: parent
                    text: round.modelData.icon
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLarge
                    color: round.isArmed ? Theme.accentText : Theme.text
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const entry = round.modelData
                        if (root.kind !== "session") {
                            if (entry.panel === "")
                                root.settingsRequested()
                            else
                                root.panelRequested(entry.panel)
                            return
                        }
                        if (entry.destructive && !round.isArmed) {
                            root.armed = entry.id
                            disarm.restart()
                            return
                        }
                        root.armed = ""
                        disarm.stop()
                        SessionService.run(entry.id)
                        root.ran()
                    }
                }

                // The label, over the button while pointed at or armed.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 6
                    visible: mouse.containsMouse || round.isArmed
                    width: tip.implicitWidth + 16
                    height: tip.implicitHeight + 8
                    radius: height / 2
                    color: round.isArmed ? Theme.red : Theme.surfaceHoverIn(QsWindow.window)
                    z: 3

                    Text {
                        id: tip
                        anchors.centerIn: parent
                        text: round.isArmed ? Tr.t("%1?").arg(Tr.t(round.modelData.label)) : Tr.t(round.modelData.label)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: round.isArmed ? Theme.accentText : Theme.text
                    }
                }
            }
        }
    }
}
