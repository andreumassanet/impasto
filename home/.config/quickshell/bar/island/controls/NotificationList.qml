// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T I F I C A T I O N   L I S T                                      │
// │   notification history                                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import Quickshell.Services.Notifications

import "../../../theme"
import "../../../services"
import "../../../components"

// Notification history kept by the shell's notification server.
Card {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: Tr.t("Notifications")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Rectangle {
                visible: NotificationService.history.length > 0
                implicitWidth: Math.max(18, count.implicitWidth + 10)
                implicitHeight: 17
                radius: height / 2
                color: Theme.surfaceHoverIn(QsWindow.window)

                Text {
                    id: count
                    anchors.centerIn: parent
                    text: NotificationService.history.length
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: NotificationService.history.length > 0
                text: Tr.t("Clear")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: clearMouse.containsMouse ? Theme.accent : Theme.textMuted

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.clearHistory()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: NotificationService.history.length === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Tr.t("Nothing new")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: NotificationService.history.length > 0
            clip: true
            spacing: 6
            model: ScriptModel {
                values: NotificationService.history
            }

            delegate: Rectangle {
                id: entry

                required property var modelData

                readonly property bool critical:
                    entry.modelData.urgency === NotificationUrgency.Critical
                readonly property bool opens: NotificationService.defaultAction(
                    NotificationService.openOf(entry.modelData)) !== null

                width: ListView.view.width
                height: 54
                radius: Theme.radiusSmall
                color: entryMouse.containsMouse ? Theme.surfaceHoverIn(QsWindow.window) : Qt.alpha(Theme.surfaceHoverIn(QsWindow.window), 0)

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 6
                    spacing: 9

                    ClippingRectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: width * Theme.pictureCorner
                        color: mark.visible ? "transparent"
                            : (entry.critical ? Theme.red : Theme.surfaceHoverIn(QsWindow.window))

                        Image {
                            id: image
                            anchors.fill: parent
                            source: entry.modelData.image ?? ""
                            visible: source != "" && status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 60
                            sourceSize.height: 60
                        }

                        // The sender's icon, else the icon set's stand-in.
                        Image {
                            id: mark
                            anchors.fill: parent
                            source: image.visible ? ""
                                : (NotificationService.iconOf(entry.modelData.icon ?? "",
                                        entry.modelData.appName ?? "")
                                    || NotificationService.standIn(entry.critical))
                            visible: !image.visible && status === Image.Ready
                            asynchronous: true
                            sourceSize.width: 60
                            sourceSize.height: 60
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !image.visible && !mark.visible
                            text: entry.critical ? "󰀪" : "󰂚"
                            font.family: Theme.fontMono
                            font.pixelSize: 13
                            color: entry.critical ? Theme.accentText : Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.summary
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: entry.modelData.body ?? ""
                            textFormat: Text.StyledText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.appName
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: Theme.textMuted
                            opacity: 0.7
                        }
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: entryMouse.containsMouse
                        icon: "󰅖"
                        iconSize: 11
                        onClicked: NotificationService.remove(entry.modelData)
                    }
                }

                MouseArea {
                    id: entryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    cursorShape: entry.opens ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                // While its notification is still open, a click is its default
                // action, and the island gets out of the way of the window it
                // brings up. One from an earlier session only has its text. A
                // handler, so the close button above keeps its own clicks.
                TapHandler {
                    enabled: entry.opens
                    onTapped: {
                        if (NotificationService.open(entry.modelData)
                                && ModuleService.shownPanel !== "")
                            ModuleService.togglePanel(ModuleService.shownPanel)
                    }
                }
            }
        }
    }
}
