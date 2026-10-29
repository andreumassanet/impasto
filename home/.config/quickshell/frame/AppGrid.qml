// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A P P   G R I D                                                        │
// │   frame · every application as an icon, by category                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// A grid of applications: a search field, a row of categories and every
// application as an icon with its name. Typing filters, the arrows move, Enter
// opens, Tab steps the category.
FocusScope {
    id: root

    signal closed()

    readonly property var categories: [
        { id: "", label: Tr.t("All"), icon: "󰀻", match: [] },
        { id: "dev", label: Tr.t("Development"), icon: "󰅩", match: ["Development", "IDE"] },
        { id: "web", label: Tr.t("Internet"), icon: "󰖟", match: ["Network", "WebBrowser", "Email", "Chat"] },
        { id: "office", label: Tr.t("Office"), icon: "󰈙", match: ["Office", "Education", "Science"] },
        { id: "media", label: Tr.t("Media"), icon: "󰝚", match: ["AudioVideo", "Audio", "Video", "Graphics"] },
        { id: "games", label: Tr.t("Games"), icon: "󰊴", match: ["Game"] },
        { id: "system", label: Tr.t("System"), icon: "󰒓", match: ["System", "Settings", "Utility"] }
    ]

    property int category: 0
    property string term: ""
    readonly property int columns: 7

    readonly property var apps: {
        const wanted = root.term.toLowerCase()
        const match = root.categories[root.category].match
        return LauncherService.applications
            .filter(app => match.length === 0 || (app.categories ?? []).some(name => match.indexOf(name) >= 0))
            .filter(app => wanted === "" || app.name.toLowerCase().includes(wanted) || app.keywords.includes(wanted))
            .sort((first, second) => first.name.localeCompare(second.name))
    }

    function launch(index: int): void {
        const app = root.apps[index]
        if (!app)
            return
        LauncherService.activate(app)
        root.closed()
    }

    // Created on open, so this is where the field takes focus.
    Component.onCompleted: {
        field.forceActiveFocus()
        LauncherService.refresh()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            Layout.maximumHeight: 38
            Layout.fillHeight: false
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                radius: height / 2
                color: Theme.islandSurface

                TextInput {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.text
                    clip: true
                    onTextEdited: {
                        root.term = text
                        grid.currentIndex = 0
                    }

                    Keys.onReturnPressed: root.launch(grid.currentIndex)
                    Keys.onEnterPressed: root.launch(grid.currentIndex)
                    Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                    Keys.onRightPressed: grid.moveCurrentIndexRight()
                    Keys.onUpPressed: grid.moveCurrentIndexUp()
                    Keys.onDownPressed: grid.moveCurrentIndexDown()
                    Keys.onTabPressed: categoryTabs.step(1)
                    Keys.onBacktabPressed: categoryTabs.step(-1)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: Tr.t("Search applications…")
                        font: field.font
                        color: Theme.textMuted
                    }
                }
            }

            SegmentedControl {
                id: categoryTabs

                labelled: true
                options: root.categories
                current: root.categories[root.category].id
                onSelected: id => {
                    root.category = root.categories.findIndex(category => category.id === id)
                    field.forceActiveFocus()
                }
            }

            Item { Layout.fillWidth: true }
        }

        GridView {
            id: grid

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: width / root.columns
            cellHeight: 112
            model: root.apps
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            keyNavigationWraps: false

            delegate: Item {
                id: tile

                required property var modelData
                required property int index
                readonly property bool current: GridView.isCurrentItem
                readonly property string iconSource: tile.modelData.icon ? Theme.appIcon(tile.modelData.icon) : ""

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.radiusLarge
                    color: tile.current ? Theme.islandSurfaceHover : tileMouse.containsMouse ? Theme.islandSurface : "transparent"
                    border.color: tile.current ? Theme.accent : "transparent"
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 8

                    // The themed icon, or a glyph while the theme has none.
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 52
                        height: 52

                        Image {
                            id: appIcon

                            anchors.fill: parent
                            source: tile.iconSource
                            visible: tile.iconSource !== "" && status === Image.Ready
                            sourceSize.width: 104
                            sourceSize.height: 104
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !appIcon.visible
                            text: "󰀻"
                            font.family: Theme.fontMono
                            font.pixelSize: 34
                            color: Theme.textMuted
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: tile.modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }
                }

                MouseArea {
                    id: tileMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launch(tile.index)
                }
            }
        }
    }
}
