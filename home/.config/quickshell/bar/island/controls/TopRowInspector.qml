// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T O P   R O W   I N S P E C T O R                                      │
// │   the top row's card while arranging · which buttons, in what order      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// The row chosen while arranging, as a block is: every button there is,
// ticked when it is on the row, with arrows along it. The settings page arranges the same
// row by dragging (`TopRowEditor`).
Rectangle {
    id: root

    readonly property int pad: 14
    // The room it has, the grid's height; past it the list scrolls.
    property real limit: 100000

    // Every button in a fixed order, the session's first, so a line stays
    // put under the pointer when it is ticked; the row above shows the order.
    readonly property var rows: ControlsService.topCatalogue.map(entry => entry.id)

    width: 268
    height: Math.min(column.implicitHeight + 2 * root.pad, root.limit)
    radius: Theme.radiusLarge
    color: Theme.island
    border.color: Theme.borderIn(QsWindow.window)
    border.width: 1

    // Exclusive from the press, or the ground's tap underneath would close
    // the card.
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 12

        Text {
            height: 28
            verticalAlignment: Text.AlignVCenter
            text: Tr.t("The top row")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Rectangle { width: parent.width; height: 1; color: Theme.hairline }

        Flickable {
            width: parent.width
            height: Math.min(list.implicitHeight,
                root.limit - 2 * root.pad - 28 - 1 - 2 * column.spacing)
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list

                width: parent.width
                spacing: 2

                Repeater {
                    model: root.rows

                    Rectangle {
                        id: line

                        required property string modelData

                        readonly property var entry: ControlsService.topEntry(line.modelData)
                        readonly property var list: ControlsService.topIds
                        readonly property int at: line.list.indexOf(line.modelData)
                        readonly property bool on: line.at >= 0

                        width: parent.width
                        height: 24
                        radius: Theme.radiusSmall
                        color: lineHover.hovered ? Theme.surfaceHoverIn(QsWindow.window) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 4
                                color: line.on ? Theme.accent : "transparent"
                                border.color: line.on ? Theme.accent : Theme.textMuted
                                border.width: 1.5

                                Text {
                                    anchors.centerIn: parent
                                    visible: line.on
                                    text: "󰄬"
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    color: Theme.accentText
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                horizontalAlignment: Text.AlignHCenter
                                text: line.entry ? line.entry.icon : ""
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                color: line.on ? Theme.accent : Theme.textMuted
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: line.width - 46 - (line.on ? 46 : 0)
                                text: line.entry ? Tr.t(line.entry.label) : ""
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: line.on ? Theme.text : Theme.textMuted
                            }
                        }

                        HoverHandler { id: lineHover; cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: ControlsService.toggleTop(line.modelData)
                        }

                        // Declared after the line's tap so a press here goes here.
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: line.on
                            spacing: 2

                            Repeater {
                                model: [{ glyph: "󰅃", delta: -1 }, { glyph: "󰅀", delta: 1 }]

                                Rectangle {
                                    id: arrow

                                    required property var modelData

                                    readonly property bool usable: arrow.modelData.delta < 0
                                        ? line.at > 0 : line.at < line.list.length - 1

                                    width: 20
                                    height: 20
                                    radius: Theme.radiusSmall
                                    color: arrowHover.hovered && arrow.usable
                                        ? Theme.surfaceIn(QsWindow.window) : "transparent"
                                    opacity: arrow.usable ? 1 : 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: arrow.modelData.glyph
                                        font.family: Theme.fontMono
                                        font.pixelSize: 11
                                        color: Theme.text
                                    }

                                    HoverHandler { id: arrowHover }

                                    // Always takes the press, so a tap never falls
                                    // through to the line and takes it off.
                                    TapHandler {
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        onTapped: {
                                            if (arrow.usable)
                                                ControlsService.nudgeTop(line.modelData, arrow.modelData.delta)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
