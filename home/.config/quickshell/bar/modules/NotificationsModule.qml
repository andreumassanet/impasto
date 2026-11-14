// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T I F I C A T I O N S   M O D U L E                                │
// │   notifications · unread count, history when open                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

import "../../theme"
import "../../services"
import "../../components"

// A bell (crossed out in Do Not Disturb) with the pending count. The detail is
// the kept history, one line each, with Do Not Disturb and Clear.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ModuleCard {
            id: card

            readonly property int kept: NotificationService.history.length
            // Rows shown before the list scrolls.
            readonly property int shown: Math.min(6, card.kept)

            title: Tr.t("Notifications")
            subtitle: {
                const parts = [card.kept === 0 ? Tr.t("Nothing new") : Tr.t("%1 kept").arg(card.kept)]
                if (NotificationService.doNotDisturb)
                    parts.push(Tr.t("Do Not Disturb"))
                return parts.join(" · ")
            }

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: 0
                trackColor: Theme.indicatorDim

                Text {
                    anchors.centerIn: parent
                    text: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: NotificationService.doNotDisturb ? Theme.textMuted : Theme.indicator
                }
            }

            // Rows of the card's height, so the list is a whole number of
            // rows tall and scrolls past six. It reaches past the card's
            // edges by the hover's overhang, so its text lines up with the
            // rows below.
            ListView {
                Layout.fillWidth: true
                Layout.leftMargin: -8
                Layout.rightMargin: -8
                Layout.preferredHeight: card.shown * Theme.cardRow
                    + Math.max(0, card.shown - 1) * Theme.cardRowGap
                visible: card.kept > 0
                clip: true
                spacing: Theme.cardRowGap
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: NotificationService.history
                }

                delegate: Item {
                    id: entry

                    required property var modelData

                    readonly property bool critical:
                        entry.modelData.urgency === NotificationUrgency.Critical
                    readonly property bool opens: NotificationService.defaultAction(
                        NotificationService.openOf(entry.modelData)) !== null

                    width: ListView.view.width
                    height: Theme.cardRow

                    HoverHandler {
                        id: hover
                        cursorShape: entry.opens ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }

                    // While its notification is still open, a click is its
                    // default action, and the island gets out of the way of
                    // the window it brings up. One from an earlier session
                    // only has its text.
                    TapHandler {
                        enabled: entry.opens
                        onTapped: {
                            if (NotificationService.open(entry.modelData)
                                    && ModuleService.shownPanel !== "")
                                ModuleService.togglePanel(ModuleService.shownPanel)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: Theme.surfaceHoverIn(QsWindow.window)
                        opacity: hover.hovered ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        ClippingRectangle {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            radius: width * Theme.pictureCorner
                            color: mark.visible ? "transparent"
                                : (entry.critical ? Theme.red : Theme.surfaceHoverIn(QsWindow.window))

                            Image {
                                id: image
                                anchors.fill: parent
                                source: entry.modelData.image ?? ""
                                visible: String(source) !== "" && status === Image.Ready
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 32
                                sourceSize.height: 32
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
                                sourceSize.width: 32
                                sourceSize.height: 32
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !image.visible && !mark.visible
                                text: entry.critical ? "󰀪" : "󰂚"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                color: entry.critical ? Theme.accentText : Theme.accent
                            }
                        }

                        Text {
                            Layout.maximumWidth: 150
                            text: entry.modelData.summary
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.body ?? ""
                            textFormat: Text.StyledText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }

                        // The application, or the way to drop the entry
                        // while the pointer is on it.
                        Text {
                            Layout.maximumWidth: 80
                            visible: !hover.hovered
                            text: entry.modelData.appName
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }

                        Text {
                            visible: hover.hovered
                            text: "󰅖"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: dropMouse.containsMouse ? Theme.accent : Theme.textMuted

                            MouseArea {
                                id: dropMouse
                                anchors.fill: parent
                                anchors.margins: -5
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotificationService.remove(entry.modelData)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow
                spacing: 8

                Item { Layout.fillWidth: true }

                PillButton {
                    implicitHeight: Theme.cardRow
                    text: Tr.t("Do Not Disturb")
                    active: NotificationService.doNotDisturb
                    onClicked: NotificationService.toggleDoNotDisturb()
                }

                PillButton {
                    implicitHeight: Theme.cardRow
                    text: Tr.t("Clear")
                    enabled: card.kept > 0
                    onClicked: NotificationService.clearHistory()
                }
            }
        }
    }
}
