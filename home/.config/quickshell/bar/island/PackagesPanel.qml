// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P A C K A G E S   P A N E L                                            │
// │   package browser · updates, installed and search                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// Three lists under one field: updates, installed, and what the repositories
// and the AUR offer, switched on the right of the field or with Tab. The field
// filters the first two and searches the third. Laid out like the launcher,
// plus a status line at the bottom.
//
// Install, Remove and Update run in a terminal (`PackagesService.open`);
// nothing here changes the system directly.
ColumnLayout {
    id: root

    signal closed()

    spacing: 10

    readonly property string view: PackagesService.view
    readonly property var rows: PackagesService.rows

    Component.onCompleted: {
        field.forceActiveFocus()
        UpdatesService.subscribe()
        PackagesService.load()
    }

    Component.onDestruction: {
        UpdatesService.release()
        PackagesService.query = ""
    }

    function move(delta: int): void {
        const count = root.rows.length
        if (count === 0)
            return
        list.currentIndex = (list.currentIndex + delta + count) % count
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }

    // The terminal takes the keyboard, so the island closes.
    function act(action: var): void {
        action()
        root.closed()
    }

    // Enter installs from Find and does nothing elsewhere. Removing takes a
    // click on the row's button, and updates are applied all at once from the
    // status line.
    function activateSelected(): void {
        const row = root.rows[list.currentIndex]
        if (root.view === "find" && PackagesService.installable(row))
            root.act(() => PackagesService.install(row))
    }

    readonly property var viewIcons: ({ updates: "󰚰", installed: "󰏗", find: "󰍉" })

    // ── FIELD ───────────────────────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: PackagesService.fieldHeight
        spacing: 12

        Text {
            text: root.viewIcons[root.view] ?? "󰍉"
            font.family: Theme.fontMono
            font.pixelSize: 17
            color: Theme.accent
        }

        TextInput {
            id: field

            Layout.fillWidth: true
            text: PackagesService.query
            font.family: Theme.fontFamily
            font.pixelSize: 16
            color: Theme.text
            clip: true
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText

            onTextEdited: PackagesService.query = text
            Keys.onReturnPressed: root.activateSelected()
            Keys.onEnterPressed: root.activateSelected()
            Keys.onUpPressed: root.move(-1)
            Keys.onDownPressed: root.move(1)
            Keys.onTabPressed: PackagesService.step(1)
            Keys.onBacktabPressed: PackagesService.step(-1)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text === ""
                text: root.view === "find" ? "Find a package…"
                    : (root.view === "updates" ? "Filter the updates…" : "Filter what is installed…")
                color: Theme.textMuted
                font: field.font
            }
        }

        SegmentedControl {
            Layout.alignment: Qt.AlignVCenter
            current: root.view
            options: PackagesService.views.map(entry => ({
                id: entry.id,
                label: entry.id === "updates" && UpdatesService.count > 0
                    ? `${entry.label} · ${UpdatesService.count}` : entry.label
            }))
            onSelected: id => {
                PackagesService.view = id
                field.forceActiveFocus()
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.islandBorder
    }

    // ── ROWS ────────────────────────────────────────────────────────────────

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // Explicit empty state.
        Text {
            anchors.centerIn: parent
            width: parent.width - 80
            visible: root.rows.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: {
                const term = PackagesService.term
                if (root.view === "updates")
                    return term === "" ? "Everything is up to date." : "No pending update is called that."
                if (root.view === "installed")
                    return !PackagesService.loaded ? "Reading the database…" : "Nothing installed is called that."
                if (term === "")
                    return "Type a name — the repositories and the AUR both answer."
                if (term.length < 2)
                    return "Two letters at least."
                if (PackagesService.searching || term !== PackagesService.foundTerm)
                    return "Searching…"
                return "Nothing is called that."
            }
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular
            color: Theme.textMuted
        }

        ListView {
            id: list

            anchors.fill: parent
            clip: true
            spacing: 2
            model: ScriptModel {
                values: root.rows

                // Back to the top once the rows have landed, not when the list
                // changes: a row inserted above the selection would shift it.
                onValuesChanged: {
                    list.currentIndex = 0
                    list.positionViewAtBeginning()
                }
            }
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: 0

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                readonly property bool selected: ListView.view.currentIndex === row.index
                readonly property bool aur: row.modelData.source === "aur"
                readonly property bool update: root.view === "updates"
                readonly property bool isInstalled: row.modelData.installed === true
                readonly property bool hovered: rowHover.hovered

                width: ListView.view.width
                height: PackagesService.rowHeight
                radius: Theme.radiusSmall
                color: row.selected ? Theme.islandSurfaceHover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                HoverHandler { id: rowHover }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    // On movement, not hover, so a row appearing under a
                    // resting pointer does not take the selection.
                    onPositionChanged: row.ListView.view.currentIndex = row.index
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 12

                    // The row's kind in a disc: pending, installed or
                    // available, with AUR packages in the accent.
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: width / 2
                        color: Theme.islandSurfaceHover

                        Text {
                            anchors.centerIn: parent
                            text: row.update ? "󰚰"
                                : (root.view === "find" && row.isInstalled ? "󰄬" : "󰏗")
                            font.family: Theme.fontMono
                            font.pixelSize: 13
                            color: row.update || row.aur
                                || (root.view === "find" && row.isInstalled)
                                ? Theme.accent : Theme.textMuted
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.maximumWidth: 380
                                text: row.modelData.name
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeRegular
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            Text {
                                visible: !row.update && (row.modelData.version ?? "") !== ""
                                text: row.modelData.version ?? ""
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                color: Theme.textMuted
                            }

                            // The source, when known: the repository a search
                            // found it in, or the AUR, which is worth checking
                            // before installing.
                            Text {
                                readonly property string label: row.aur ? "AUR"
                                    : (root.view === "find" ? row.modelData.source : "")
                                visible: label !== ""
                                text: label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.4
                                color: row.aur ? Theme.accent : Theme.textMuted
                            }

                            Text {
                                visible: row.modelData.outOfDate === true
                                text: "out of date"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: Theme.indicatorWarn
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.modelData.description ?? ""
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }

                    // Right-hand end of the row.

                    // An update says what it was and what it will be.
                    RowLayout {
                        visible: row.update
                        spacing: 6

                        Text {
                            text: row.modelData.from ?? ""
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }

                        Text {
                            text: "→"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }

                        Text {
                            text: row.modelData.to ?? ""
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.text
                        }
                    }

                    // Installed size, or an AUR package's popularity.
                    Text {
                        visible: !row.update && !action.visible && text !== ""
                        // Meta packages have no size, and "0.00 B" would look
                        // like an error.
                        text: root.view === "installed"
                            ? ((row.modelData.size ?? "").startsWith("0.00") ? "" : (row.modelData.size ?? ""))
                            : (row.aur ? `${row.modelData.votes ?? 0} votes` : "")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }

                    Text {
                        visible: root.view === "find" && row.isInstalled && !action.visible
                        text: "Installed"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.accent
                    }

                    // The row's single action. Install shows on the selected
                    // row, since Enter triggers it; Remove only on hover,
                    // since only a click does.
                    PillButton {
                        id: action
                        visible: !row.update && (row.isInstalled
                            ? row.hovered
                            : row.selected && PackagesService.installable(row.modelData))
                        text: row.isInstalled ? "Remove" : "Install"
                        icon: row.isInstalled ? "󰆴" : "󰇚"
                        active: !row.isInstalled
                        enabled: !PackagesService.busy
                        implicitHeight: 26
                        onClicked: root.act(row.isInstalled
                            ? () => PackagesService.remove(row.modelData)
                            : () => PackagesService.install(row.modelData))
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.islandBorder
    }

    // ── STATUS LINE ─────────────────────────────────────────────────────────
    //
    // Where the list came from, and actions on the whole list.

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: PackagesService.footerHeight
        spacing: 10

        SegmentedControl {
            visible: root.view === "installed"
            current: PackagesService.installedFilter
            enabled: PackagesService.term === ""
            options: [
                { id: "mine", label: `By you · ${PackagesService.mineCount}` },
                { id: "all",  label: `All · ${PackagesService.installed.length}` },
                { id: "aur",  label: `AUR · ${PackagesService.aurCount}` }
            ]
            onSelected: id => {
                PackagesService.installedFilter = id
                field.forceActiveFocus()
            }
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: {
                if (root.view === "updates") {
                    const aur = UpdatesService.updates.filter(row => row.source === "aur").length
                    // The fallback reads the last-synced database, so zero
                    // from it does not mean up to date.
                    const parts = [`${UpdatesService.count - aur} from the repositories`
                        + (UpdatesService.tool === "pacman" ? " as of the last sync" : "")]
                    parts.push(UpdatesService.aur ? `${aur} from the AUR` : "the AUR did not answer")
                    if (UpdatesService.checking)
                        parts.push("checking…")
                    else if (UpdatesService.age !== "")
                        parts.push(`checked ${UpdatesService.age}`)
                    return parts.join(" · ")
                }
                if (root.view === "installed")
                    return PackagesService.term !== ""
                        ? `${root.rows.length} of ${PackagesService.installed.length}` : ""
                if (PackagesService.foundTerm === "" || PackagesService.foundNote === "short")
                    return PackagesService.helper !== ""
                        ? `Installed with ${PackagesService.helper}, in a terminal`
                        : "No AUR helper — the repositories only"
                const parts = [`${PackagesService.foundRepos} in the repositories`]
                if (PackagesService.foundNote === "offline")
                    parts.push("the AUR did not answer")
                else if (PackagesService.foundNote === "prefix")
                    parts.push(`the first ${PackagesService.foundAur} in the AUR that start with it`)
                else
                    parts.push(`${PackagesService.foundAur} in the AUR`)
                return parts.join(" · ")
            }
            horizontalAlignment: root.view === "installed" ? Text.AlignRight : Text.AlignLeft
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }

        PillButton {
            visible: root.view === "updates"
            text: UpdatesService.checking ? "Checking…" : "Check"
            icon: "󰑐"
            enabled: !UpdatesService.checking
            implicitHeight: 26
            onClicked: UpdatesService.refresh()
        }

        PillButton {
            visible: root.view === "updates"
            text: "Update everything"
            icon: "󰚰"
            active: true
            enabled: UpdatesService.count > 0 && !PackagesService.busy
            implicitHeight: 26
            onClicked: root.act(() => PackagesService.upgrade())
        }
    }
}
