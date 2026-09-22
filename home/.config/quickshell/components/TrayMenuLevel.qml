// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R A Y   M E N U   L E V E L                                          │
// │   one column of a DBus menu · recursive submenus                        │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.DBusMenu

import "../theme"

Item {
    id: root

    property var scope
    property point position
    property var window
    signal closed()

    readonly property int columnWidth: Theme.dockMenuWidth

    x: position.x
    y: position.y
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    readonly property QsMenuOpener opener: QsMenuOpener { menu: scope }

    // An entry's icon is one of several things: a theme name, an
    // `image://icon/…` URI (the `#` suffix is an accent), a file path, or one
    // of this config's text glyphs. Resolve the first three to a drawable,
    // leave the glyphs as text.
    function iconBase(icon) {
        let text = icon ?? ""
        if (text.startsWith("image://icon/"))
            text = text.substring("image://icon/".length).replace(/#.*$/, "")
        return text
    }

    function iconImage(icon) {
        const text = root.iconBase(icon)
        if (text.startsWith("/") || text.startsWith("file:"))
            return text
        return Quickshell.hasThemeIcon(text) ? Quickshell.iconPath(text) : ""
    }

    function iconGlyph(icon) {
        const text = root.iconBase(icon)
        return text.length <= 2 ? text : ""
    }

    property Item currentChild: null

    Loader {
        id: childLoader
        active: false
    }

    function openChild(entry, rowItem) {
        if (childLoader.active)
            childLoader.sourceComponent = undefined
        const p = mapToItem(window.contentItem, rowItem.x + rowItem.width, rowItem.y)
        childLoader.setSource(Qt.resolvedUrl("TrayMenuLevel.qml"), {
            scope: entry,
            position: Qt.point(p.x + 4, p.y - Theme.dockMenuPadding),
            window: window
        })
        if (childLoader.item)
            childLoader.item.closed.connect(() => root.closed())
    }

    function closeChild() {
        if (childLoader.active)
            childLoader.sourceComponent = undefined
    }

    Rectangle {
        id: card

        width: column.implicitWidth + 2 * Theme.dockMenuPadding
        height: column.implicitHeight + 2 * Theme.dockMenuPadding
        radius: Theme.radiusMedium
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1

        Column {
            id: column

            anchors.fill: parent
            anchors.margins: Theme.dockMenuPadding
            spacing: 0

            Repeater {
                model: root.opener.children

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    width: root.columnWidth - 2 * Theme.dockMenuPadding
                    height: modelData.isSeparator ? 1 : Theme.dockMenuRow
                    radius: modelData.isSeparator ? 0 : Theme.radiusSmall
                    color: modelData.isSeparator ? Theme.islandBorder
                        : rowMouse.containsMouse
                            ? (modelData.warn ? Theme.red : Theme.islandSurfaceHover)
                            : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10
                        visible: !modelData.isSeparator

                        Item {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            Layout.alignment: Qt.AlignVCenter

                            readonly property string uri: root.iconImage(modelData.icon)
                            readonly property string glyph: root.iconGlyph(modelData.icon)
                            visible: uri !== "" || glyph !== ""

                            Image {
                                anchors.fill: parent
                                visible: parent.uri !== ""
                                source: parent.uri
                                sourceSize.width: 16 * 2
                                sourceSize.height: 16 * 2
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.fill: parent
                                visible: parent.uri === "" && parent.glyph !== ""
                                text: parent.glyph
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                color: rowMouse.containsMouse
                                    ? (modelData.warn ? Theme.red : Theme.textMuted)
                                    : Theme.textMuted
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.text ?? ""
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: rowMouse.containsMouse
                                ? (modelData.warn ? Theme.red : Theme.text)
                                : Theme.text
                            opacity: modelData.enabled === false ? 0.4 : 1
                        }

                        Text {
                            Layout.preferredWidth: 12
                            horizontalAlignment: Text.AlignHCenter
                            visible: modelData.hasChildren
                            text: "▸"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }

                        Text {
                            Layout.preferredWidth: 16
                            horizontalAlignment: Text.AlignHCenter
                            visible: modelData.buttonType !== undefined
                                && modelData.buttonType !== 0
                            text: {
                                if (modelData.buttonType === 1) // CheckBox
                                    return modelData.checkState === 2 ? "✓" : ""
                                if (modelData.buttonType === 2) // RadioButton
                                    return modelData.checkState === 2 ? "●" : "○"
                                return ""
                            }
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            color: modelData.checkState === 2
                                ? Theme.accent : Theme.textMuted
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: !modelData.isSeparator
                        enabled: !modelData.isSeparator

                        onEntered: {
                            if (modelData.hasChildren)
                                root.openChild(modelData, row)
                        }

                        onClicked: (mouse) => {
                            if (!modelData.hasChildren && modelData.enabled !== false) {
                                modelData.triggered()
                                root.closed()
                            }
                        }
                    }
                }
            }
        }
    }
}