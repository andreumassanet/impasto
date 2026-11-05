// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A G E N D A   P A N E L                                                │
// │   calendar · the next two weeks, a heading per day                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"

// What is coming up, read-only, from the calendars khal knows. A heading per
// day, its events under it with the time, title and place.
ColumnLayout {
    id: root

    signal closed()

    spacing: Theme.cardGap

    Component.onCompleted: AgendaService.subscribe()
    Component.onDestruction: AgendaService.release()

    function dayLabel(isoDate: string): string {
        if (isoDate === AgendaService.today)
            return Tr.t("Today")
        const tomorrow = Qt.formatDate(new Date(Date.now() + 86400000), "yyyy-MM-dd")
        if (isoDate === tomorrow)
            return Tr.t("Tomorrow")
        return Qt.formatDate(new Date(isoDate + "T00:00:00"), "dddd d MMMM")
    }

    // A heading per day, then its events.
    readonly property var rows: {
        const out = []
        let day = ""
        for (const event of AgendaService.upcoming) {
            if (event.date !== day) {
                day = event.date
                out.push({ heading: true, key: `day:${day}`, text: root.dayLabel(day) })
            }
            out.push({ heading: false, key: `${event.start}:${event.title}`, event: event })
        }
        return out
    }

    Text {
        text: Tr.t("AGENDA")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        font.weight: Font.DemiBold
        color: Theme.textMuted
    }

    Text {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.rows.length === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: !AgendaService.loaded ? "…"
            : AgendaService.error !== "" ? AgendaService.error
            : !AgendaService.configured ? Tr.t("No calendars yet: set up khal (vdirsyncer or a folder of .ics files)")
            : Tr.t("Nothing in the next two weeks")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.rows.length > 0
        clip: true
        spacing: 4
        model: ScriptModel {
            objectProp: "key"
            values: root.rows
        }

        delegate: Item {
            id: row

            required property var modelData

            width: ListView.view.width
            implicitHeight: row.modelData.heading ? 26 : 38

            Text {
                visible: row.modelData.heading
                anchors.bottom: parent.bottom
                text: row.modelData.text ?? ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.accent
            }

            RowLayout {
                visible: !row.modelData.heading
                anchors.fill: parent
                spacing: 12

                Text {
                    Layout.preferredWidth: 64
                    text: row.modelData.event?.allDay ? Tr.t("All day") : (row.modelData.event?.time ?? "")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.features: { "tnum": 1 }
                    color: Theme.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.event?.title ?? ""
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: [row.modelData.event?.location ?? "", row.modelData.event?.calendar ?? ""]
                            .filter(part => part !== "").join(" · ")
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
