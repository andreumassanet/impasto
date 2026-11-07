// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A P T U R E   P A N E L                                              │
// │   recordings · the newest takes, stop and open the folder                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell

import "../../theme"
import "../../services"

// The newest recordings, one click to play. While a take is running the
// header shows its clock and the link stops it. Starting a capture is the
// capture surface's job (`CaptureService`), not this panel's.
ColumnLayout {
    id: root

    signal closed()

    spacing: Theme.cardGap

    readonly property int rows: 4
    readonly property string directory: RecorderService.tools.directory ?? ""
    // What the scripts put after the time in a name (`IMPASTO_CAPTURE_SUFFIX`);
    // with none, every video in the folder is a take.
    readonly property string suffix: Quickshell.env("IMPASTO_CAPTURE_SUFFIX") ?? "_impasto"

    // `record.py` names its takes by the time they began, so the newest sorts
    // last by name; reversed, they lead.
    FolderListModel {
        id: takes

        folder: root.directory === "" ? "" : DesktopService.urlOf(root.directory)
        nameFilters: [`*${root.suffix}.mp4`]
        showDirs: false
        sortField: FolderListModel.Name
        sortReversed: true
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: RecorderService.recording
                ? `${Tr.t("RECORDING")} · ${RecorderService.display}`
                : Tr.t("RECENT RECORDINGS")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            font.weight: Font.DemiBold
            color: RecorderService.recording ? Theme.indicatorBad : Theme.textMuted
        }

        Text {
            visible: RecorderService.recording || root.directory !== ""
            text: RecorderService.recording ? Tr.t("Stop") : Tr.t("Folder")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: linkMouse.containsMouse ? Theme.accent : Theme.textMuted

            MouseArea {
                id: linkMouse

                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (RecorderService.recording) {
                        RecorderService.stop()
                        return
                    }
                    root.closed()
                    Qt.openUrlExternally(DesktopService.urlOf(root.directory))
                }
            }
        }
    }

    Text {
        visible: takes.count === 0
        text: Tr.t("Nothing recorded yet")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted
    }

    Repeater {
        model: Math.min(root.rows, takes.count)

        Rectangle {
            id: row

            required property int index

            readonly property string label: takes.get(row.index, "fileName") ?? ""
            readonly property var modified: takes.get(row.index, "fileModified")

            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Theme.radiusMedium
            color: rowMouse.containsMouse
                ? Theme.surfaceHoverIn(QsWindow.window) : Theme.surfaceIn(QsWindow.window)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: "󰕧"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeRegular
                    color: Theme.accent
                }

                Text {
                    Layout.fillWidth: true
                    text: row.label
                    elide: Text.ElideMiddle
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                }

                Text {
                    text: Qt.formatDateTime(row.modified, "d MMM · HH:mm")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }

            MouseArea {
                id: rowMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.closed()
                    Qt.openUrlExternally(takes.get(row.index, "fileUrl"))
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
