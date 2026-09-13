// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P R O F I L E S   P A R T                                              │
// │   profiles · switch, rename, import and export                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtCore
import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell.Widgets

import "../theme"
import "../services"
import "../components"

// One row per profile (`ProfileService`) in one card, the active one marked
// In use. Each shows the profile's wallpaper and a one-line summary of its
// bar, dock and widgets. Rename, duplicate, export and delete are in the row's
// `⋯` menu (`PopMenu`); delete is confirmed on the row, since it cannot be
// undone.
Item {
    id: root

    Layout.fillWidth: true
    implicitHeight: group.implicitHeight

    // An open menu hangs past the card, over the group below it.
    z: root.menuFor !== "" ? 2 : 0

    // Row keys with a menu open, a name being edited, or a delete pending.
    // At most one of each.
    property string menuFor: ""
    property string renaming: ""
    property string confirming: ""

    readonly property var barPhrases: ({
        grouped: Tr.t("Grouped bar"),
        spread: Tr.t("Spread bar"),
        island: Tr.t("One island")
    })

    readonly property var dockPhrases: ({
        bottom: Tr.t("dock at the bottom"),
        left: Tr.t("dock on the left"),
        right: Tr.t("dock on the right")
    })

    // "Grouped bar · dock at the bottom · 3 widgets", plus the palette's name
    // when it is fixed rather than adaptive.
    function summary(values: var, palette: string): string {
        const parts = [root.barPhrases[values.barStyle] ?? root.barPhrases.grouped]
        parts.push(values.dockEnabled
            ? (root.dockPhrases[values.dockEdge] ?? root.dockPhrases.bottom)
            : Tr.t("no dock"))
        const widgets = (values.desktopWidgets ?? []).filter(row => !row.edge).length
        parts.push(widgets === 0 ? Tr.t("nothing on the desk")
            : `${widgets} ${Tr.t(widgets === 1 ? "widget" : "widgets")}`)
        const fixed = palette !== "" && palette !== "adaptive" ? Palettes.byId(palette) : null
        if (fixed)
            parts.push(fixed.name)
        return parts.join(" · ")
    }

    function local(url: var): string {
        const text = String(url)
        return text.startsWith("file://") ? decodeURIComponent(text.slice(7)) : text
    }

    // Opens a row's name for editing and cancels any pending delete.
    function rename(key: string): void {
        if (key === "")
            return
        root.confirming = ""
        root.renaming = key
    }

    // Clicking empty space closes the open menu. Sits behind the rows so
    // their buttons still work.
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: root.menuFor !== ""
        onClicked: root.menuFor = ""
    }

    SettingGroup {
        id: group

        width: root.width
        title: Tr.t("Profiles")
        note: Tr.t("Changes are saved to the profile in use as you make them.")
        hint: Tr.t("A profile holds the bar, widgets, dock, launcher, control centre, look, keys and wallpaper with its palette. Screens, your name and picture, language, weather location, GitHub user, Do not disturb and night light stay with the machine, and notes, tasks and clipboard are shared by every profile.")

        Repeater {
            model: ProfileService.profiles

            Item {
                id: card

                required property var modelData

                readonly property string key: card.modelData.id
                readonly property bool inUse: card.key === ProfileService.active
                readonly property bool naming: root.renaming === card.key
                readonly property bool asking: root.confirming === card.key
                readonly property string picture: ProfileService.wallpaperOf(card.key)

                Layout.fillWidth: true
                implicitHeight: 62
                z: root.menuFor === card.key ? 5 : 0

                SettingDivider {}

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 12

                    // The profile's own painting, cropped to the row.
                    ClippingRectangle {
                        Layout.preferredWidth: 64
                        Layout.maximumWidth: 64
                        Layout.preferredHeight: 40
                        radius: height * Theme.pictureCorner
                        color: Theme.island

                        Image {
                            id: thumbnail

                            width: 64
                            height: 40
                            source: card.picture !== "" ? `file://${card.picture}` : ""
                            sourceSize: Qt.size(128, 80)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        // No picture, or one that is not on this disk.
                        Text {
                            anchors.centerIn: parent
                            visible: thumbnail.status !== Image.Ready
                            text: "󰸉"
                            font.family: Theme.fontMono
                            font.pixelSize: 16
                            color: Theme.textMuted
                        }
                    }

                    // Anchored inside an Item: laid out directly in the row,
                    // the text would shift with the width of the buttons at
                    // the other end.
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                visible: !card.naming
                                text: card.modelData.name
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.text
                            }

                            Rectangle {
                                visible: card.naming
                                Layout.preferredWidth: 220
                                Layout.preferredHeight: 24
                                radius: Theme.radiusSmall
                                color: Theme.island
                                border.color: Theme.accent
                                border.width: 1

                                TextInput {
                                    id: field

                                    // Escape discards; without this flag the
                                    // focus loss would still commit the edit.
                                    property bool leaving: false

                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    maximumLength: ProfileService.nameLength
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.text
                                    selectByMouse: true
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.accentText
                                    clip: true

                                    onEditingFinished: {
                                        if (!field.leaving && card.naming)
                                            ProfileService.rename(card.key, field.text)
                                        if (card.naming)
                                            root.renaming = ""
                                    }

                                    Keys.onEscapePressed: event => {
                                        field.leaving = true
                                        root.renaming = ""
                                        event.accepted = true
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: card.asking ? Tr.t("Deleted for good — there is no undo")
                                    : card.naming ? Tr.t("Enter to keep the name · Esc to leave it")
                                    : root.summary(ProfileService.settingsOf(card.key),
                                                   ProfileService.paletteOf(card.key))
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: card.asking ? Theme.red : Theme.textMuted
                            }
                        }
                    }

                    Rectangle {
                        visible: card.inUse && !card.asking
                        implicitWidth: inUse.implicitWidth + 20
                        implicitHeight: 26
                        radius: height / 2
                        color: "transparent"
                        border.color: Theme.accent
                        border.width: 1

                        Text {
                            id: inUse

                            anchors.centerIn: parent
                            text: Tr.t("In use")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            color: Theme.accent
                        }
                    }

                    PillButton {
                        visible: !card.inUse && !card.asking
                        text: Tr.t("Switch")
                        icon: "󰁔"
                        onClicked: {
                            root.menuFor = ""
                            ProfileService.switchTo(card.key)
                        }
                    }

                    PillButton {
                        visible: card.asking
                        text: Tr.t("Delete")
                        icon: "󰆴"
                        onClicked: {
                            root.confirming = ""
                            ProfileService.remove(card.key)
                        }
                    }

                    PillButton {
                        visible: card.asking
                        text: Tr.t("Keep")
                        onClicked: root.confirming = ""
                    }

                    IconButton {
                        visible: !card.asking
                        opacity: card.naming ? 0 : 1
                        enabled: !card.naming
                        icon: "󰇘"
                        iconSize: 13
                        active: root.menuFor === card.key
                        onClicked: root.menuFor = root.menuFor === card.key ? "" : card.key
                    }
                }

                Loader {
                    active: root.menuFor === card.key
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.top: parent.bottom
                    anchors.topMargin: 4

                    sourceComponent: PopMenu {
                        // The active profile cannot be deleted.
                        rows: {
                            const rows = [
                                { id: "rename", label: Tr.t("Rename"), icon: "󰑕", warn: false },
                                { id: "duplicate", label: Tr.t("Duplicate"), icon: "󰆏", warn: false },
                                { id: "export", label: Tr.t("Export to a file…"), icon: "󰈝", warn: false }
                            ]
                            if (!card.inUse)
                                rows.push({ id: "delete", label: Tr.t("Delete"), icon: "󰆴", warn: true })
                            return rows
                        }

                        onChosen: id => {
                            root.menuFor = ""
                            switch (id) {
                            case "rename":
                                root.rename(card.key)
                                break
                            case "duplicate":
                                root.rename(ProfileService.duplicate(card.key))
                                break
                            case "export":
                                root.exportProfile(card.key)
                                break
                            case "delete":
                                root.renaming = ""
                                root.confirming = card.key
                                break
                            }
                        }
                    }
                }

                // Focus the name field with its text selected, so typing
                // replaces it.
                Connections {
                    target: root

                    function onRenamingChanged(): void {
                        if (!card.naming)
                            return
                        field.leaving = false
                        field.text = card.modelData.name
                        field.selectAll()
                        field.forceActiveFocus()
                    }
                }
            }
        }

        SettingBlock {
            padding: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PillButton {
                    text: Tr.t("New profile")
                    icon: "󰐕"
                    onClicked: {
                        root.menuFor = ""
                        root.rename(ProfileService.create())
                    }
                }

                PillButton {
                    text: Tr.t("Import…")
                    icon: "󰋺"
                    onClicked: {
                        root.menuFor = ""
                        importDialog.open()
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // ── IMPORT AND EXPORT ───────────────────────────────────────────────────
    //
    // Opens in the documents folder from `user-dirs.dirs`, which Qt resolves,
    // so no localised path is written here.
    readonly property url documents:
        StandardPaths.writableLocation(StandardPaths.DocumentsLocation)

    // No file name is preselected: Qt's built-in dialog on 6.11 leaves it out
    // of the name field anyway, which would leave Save enabled over an empty
    // field. `defaultSuffix` appends `.json`.
    function exportProfile(key: string): void {
        if (!ProfileService.entry(key))
            return
        exportDialog.key = key
        exportDialog.currentFolder = root.documents
        exportDialog.open()
    }

    FileDialog {
        id: exportDialog

        property string key: ""

        title: Tr.t("Export the profile")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [Tr.t("Profiles (*.json)")]
        onAccepted: ProfileService.exportTo(exportDialog.key, root.local(exportDialog.selectedFile))
    }

    FileDialog {
        id: importDialog

        title: Tr.t("Import a profile")
        currentFolder: root.documents
        nameFilters: [Tr.t("Profiles (*.json)")]
        onAccepted: ProfileService.importFrom(root.local(importDialog.selectedFile))
    }
}
