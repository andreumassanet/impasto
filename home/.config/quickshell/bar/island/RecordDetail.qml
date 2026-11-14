// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   R E C O R D   D E T A I L                                              │
// │   the record tile opened out · the newest takes and their folder         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import Quickshell
import "../../theme"
import "../../services"

// Opened from the record tile, whose press starts or stops a take: here the
// four newest takes, a click playing one, and the folder they are kept in.
// Stopping is the island's, which shows the running take wherever you are.
// Sizes are `RecorderService`'s.
ColumnLayout {
    id: root

    signal back()
    // A take or the folder opened, so the island gets out of its way.
    signal done()

    spacing: Theme.detailGap

    DetailHeading {
        title: Tr.t("Record")
        detail: RecorderService.recording
            ? `${Tr.t("Recording")} · ${RecorderService.display}`
            : Tr.t(RecorderService.subject)
        onBack: root.back()
    }

    DetailSection {
        title: Tr.t("Recent")

        Text {
            visible: RecorderService.recentShown === 0
            width: parent.width
            height: Theme.detailRow
            leftPadding: 30
            verticalAlignment: Text.AlignVCenter
            text: Tr.t("Nothing recorded yet")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular - 1
            color: Theme.textMuted
        }

        Repeater {
            model: RecorderService.recentShown

            TakeRow {
                required property int index

                glyph: "󰕧"
                // `get` notifies nothing; the count does, when a take lands.
                readonly property int landed: RecorderService.takes.count
                text: (landed, Tr.date(RecorderService.takes.get(index, "fileModified"), "d MMM · HH:mm"))
                aside: (landed, StatsService.bytes(RecorderService.takes.get(index, "fileSize")))
                onPicked: {
                    RecorderService.openTake(index)
                    root.done()
                }
            }
        }

        TakeRow {
            glyph: "󰉋"
            text: Tr.t("Open the folder")
            onPicked: {
                RecorderService.openFolder()
                root.done()
            }
        }
    }

    Item { Layout.fillHeight: true }

    // A `DetailChoice` with a glyph where its mark would be and a note on the
    // right where its check would be.
    component TakeRow: Rectangle {
        id: row

        property string glyph: ""
        property string text: ""
        property string aside: ""

        signal picked()

        width: parent ? parent.width : 0
        height: Theme.detailRow
        radius: Theme.radiusSmall
        color: pick.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : Qt.alpha(Theme.surfaceHoverIn(QsWindow.window), 0)

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Text {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.glyph
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeRegular
            color: Theme.accent
        }

        Text {
            x: 30
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 120
            elide: Text.ElideRight
            text: row.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular - 1
            color: Theme.text
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.aside
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            color: Theme.textMuted
        }

        MouseArea {
            id: pick

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked()
        }
    }
}
