// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T I F I C A T I O N   L A Y E R                                    │
// │   an arriving notification · picture, text and actions                   │
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

// The island while a notification is shown, in one row as an incoming call is
// on a phone: the sender's picture with the app's mark on its corner, the
// title with the app and the time at its far end, up to two lines of body,
// and up to two short buttons at the end, the first in the accent. More or longer buttons share the width in a row underneath
// (`NotificationService.inlineButtons`). There is no close button: a click is
// the default action, or closes it when it has none, and a right click always
// closes it.
Item {
    id: root

    readonly property var notification: NotificationService.current
    readonly property bool critical: NotificationService.critical
    readonly property var defaultAction: NotificationService.defaultAction(root.notification)
    readonly property var buttons: NotificationService.buttonsOf(root.notification)
    readonly property bool inline: NotificationService.inlineButtons(root.notification)

    // The app's own icon: named or a path, else the one its desktop entry
    // names.
    readonly property string appIcon: {
        const n = root.notification
        if (!n)
            return ""
        return NotificationService.iconOf(n.appIcon || n.desktopEntry || "", n.appName ?? "")
    }

    // What the notification names as its icon, for the badge on the picture.
    readonly property string senderIcon: root.notification
        ? (root.notification.appIcon || root.notification.desktopEntry || "") : ""

    readonly property string picture: root.notification ? (root.notification.image ?? "") : ""

    // For a sender with no icon of its own: the icon set's notifications
    // icon, or its alert for a critical one.
    readonly property string standIn: NotificationService.standIn(root.critical)

    // ── THE ROW ─────────────────────────────────────────────────────────────

    Item {
        id: row

        width: parent.width
        height: NotificationService.toastRow

        // Under the row's controls, so the buttons keep their own clicks.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => {
                if (event.button === Qt.LeftButton && root.defaultAction !== null)
                    NotificationService.invoke(root.defaultAction)
                else
                    NotificationService.close()
            }
        }

        // The picture: the sender's, else the app's icon, else the icon set's
        // notifications icon, else the bell. A critical notification is ringed
        // in the warning hue.
        Item {
            id: face

            width: NotificationService.toastPicture
            height: width
            anchors.verticalCenter: parent.verticalCenter

            ClippingRectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.surfaceHoverIn(QsWindow.window)
                border.color: Theme.indicatorBad
                border.width: root.critical ? 2 : 0
                contentUnderBorder: true

                Image {
                    id: photo

                    anchors.fill: parent
                    source: root.picture
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 96
                    sourceSize.height: 96
                }

                Image {
                    id: mark

                    anchors.centerIn: parent
                    width: parent.width * 0.62
                    height: width
                    source: photo.visible ? "" : (root.appIcon || root.standIn)
                    visible: !photo.visible && status === Image.Ready
                    asynchronous: true
                    sourceSize.width: 64
                    sourceSize.height: 64
                }

                Text {
                    anchors.centerIn: parent
                    visible: !photo.visible && !mark.visible
                    text: root.critical ? "󰀪" : "󰂚"
                    font.family: Theme.fontMono
                    font.pixelSize: 17
                    color: root.critical ? Theme.indicatorBad : Theme.accent
                }
            }

            // The app's mark on the picture's corner, when the picture is the
            // sender's.
            NotificationBadge {
                shown: photo.visible
                x: -4
                y: parent.height - height + 4
                icon: root.senderIcon
                appName: root.notification?.appName ?? ""
                body: root.notification?.body ?? ""
            }
        }

        Column {
            anchors.left: face.right
            anchors.leftMargin: NotificationService.textGap
            anchors.right: actions.visible ? actions.left : parent.right
            anchors.rightMargin: actions.visible ? NotificationService.textGap : 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Item {
                width: parent.width
                height: title.implicitHeight

                Text {
                    id: title

                    width: parent.width - (meta.visible ? meta.implicitWidth + 10 : 0)
                    text: root.notification ? root.notification.summary : ""
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                // Which app, and that it is now. Not beside buttons, which
                // already fill the end of the row.
                Text {
                    id: meta

                    anchors.right: parent.right
                    anchors.baseline: title.baseline
                    visible: !actions.visible
                    text: [root.notification ? root.notification.appName : "", Tr.t("now")]
                        .filter(part => part !== "").join("  ·  ")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.notification ? (root.notification.body ?? "") : ""
                // Applications send Pango markup and the server advertises
                // support for it, so it is rendered rather than shown as tags.
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: Theme.textMuted
            }
        }

        Row {
            id: actions

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.inline && root.buttons.length > 0
            spacing: NotificationService.buttonGap

            Repeater {
                model: actions.visible ? root.buttons : []

                Rectangle {
                    id: button

                    required property var modelData
                    required property int index

                    readonly property bool first: button.index === 0

                    width: label.implicitWidth + NotificationService.buttonPad
                    height: NotificationService.buttonHeight
                    radius: height / 2
                    color: button.first
                        ? (press.containsMouse ? Theme.accentHover : Theme.accent)
                        : (press.containsMouse ? Theme.borderIn(QsWindow.window) : Theme.surfaceHoverIn(QsWindow.window))

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    Text {
                        id: label

                        anchors.centerIn: parent
                        text: button.modelData.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.weight: Font.Medium
                        color: button.first ? Theme.accentText : Theme.text
                    }

                    MouseArea {
                        id: press

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.invoke(button.modelData)
                    }
                }
            }
        }
    }

    // ── MORE BUTTONS ────────────────────────────────────────────────────────
    //
    // Under the row, sharing the width, split by hairlines.

    Item {
        y: row.height
        width: parent.width
        height: NotificationService.stackedRow
        visible: !root.inline

        Rectangle {
            width: parent.width
            height: 1
            y: 6
            color: Theme.borderIn(QsWindow.window)
        }

        Row {
            y: 7
            width: parent.width
            height: parent.height - 7

            Repeater {
                model: root.inline ? [] : root.buttons

                Item {
                    id: cell

                    required property var modelData
                    required property int index

                    width: parent.width / root.buttons.length
                    height: parent.height

                    Rectangle {
                        visible: cell.index > 0
                        width: 1
                        height: parent.height - 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.borderIn(QsWindow.window)
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: cell.modelData.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.weight: Font.Medium
                        color: cell.index === 0 ? Theme.accent
                            : cellMouse.containsMouse ? Theme.text : Theme.textMuted
                    }

                    MouseArea {
                        id: cellMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.invoke(cell.modelData)
                    }
                }
            }
        }
    }
}
