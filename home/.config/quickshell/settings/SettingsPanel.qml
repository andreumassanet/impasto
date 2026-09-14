// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G S   P A N E L                                            │
// │   sections on the left, one page at a time on the right                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// Sidebar and page. `SettingsWindow` owns the window; this owns the sections.
//
// Settings are filed by what they change, not by how they are applied, so the
// window rounding is under Appearance rather than on a compositor page. The
// sidebar is grouped into categories and a long section is split into parts
// (`TabStrip`): two levels of navigation, no more.
//
// Where an option is a shape, the control is a live miniature built from the
// real components (`PreviewTile`), so it follows the palette and cannot go
// stale the way a screenshot would.
Item {
    id: root

    signal closed()
    signal panelRequested(string panel)

    readonly property int gap: 12

    // ── THE GROUPS ──────────────────────────────────────────────────────────

    readonly property var categories: [
        { id: "shell",   label: Tr.t("THE SHELL") },
        { id: "desk",    label: Tr.t("THE DESK") },
        { id: "session", label: Tr.t("THE SESSION") }
    ]

    // ── THE SECTIONS ────────────────────────────────────────────────────────
    //
    // One row per page. `keywords` are extra search terms beyond the label.
    readonly property var sections: [
        { id: "bar", category: "shell", icon: "󰧨", label: Tr.t("Bar & Island"),
          blurb: Tr.t("The top bar, the island and notifications."),
          tabs: [{ id: "island", label: Tr.t("The island") },
                 { id: "modules", label: Tr.t("The bar") },
                 { id: "workspaces", label: Tr.t("Workspaces") },
                 { id: "notifications", label: Tr.t("Notifications") }],
          keywords: "bar island notch height margin width full span workspaces unified layout island bar band notification toast do not disturb silence timeout clock time date seconds format beside running modules layout left right split drag catalogue chip icon ring figure hover shape media claude battery timer volume brightness network wifi bluetooth weather stats cpu updates pet recorder",
          page: barPage },

        { id: "widgets", category: "shell", icon: "󰕮", label: Tr.t("Desktop"),
          blurb: Tr.t("What sits on the wallpaper, under the windows."),
          tabs: [{ id: "modules", label: Tr.t("Module settings") },
                 { id: "widgets", label: Tr.t("The widgets") }],
          keywords: "widgets desktop wallpaper widget place drag size shape capsule bare outline accent style palette ink tray edit arrange clock calendar notes note sticky theme analogue modern opacity weather location place city github contributions username handwriting edges deck",
          page: widgetsPage },

        { id: "controls", category: "shell", icon: "󰕰", label: Tr.t("Control Centre"),
          blurb: Tr.t("What the island opens onto when you click it."),
          tabs: [],
          keywords: "controls control centre center panel doors buttons row pet games notes board tasks kanban stats blocks grid toggles tiles arrange edit tray wifi bluetooth airplane microphone focus",
          page: controlsPage },

        { id: "dock", category: "shell", icon: "󱂩", label: Tr.t("Dock"),
          blurb: Tr.t("The dock and the applications kept on it."),
          tabs: [],
          keywords: "dock apps applications launcher pinned kept favourite favorite running edge bottom left right align icon size autohide reserve taskbar menu windows close",
          page: dockPage },

        { id: "launcher", category: "shell", icon: "󰍉", label: Tr.t("Launcher"),
          blurb: Tr.t("Search, sigils and the clipboard history."),
          tabs: [{ id: "results", label: Tr.t("Results") },
                 { id: "sigils", label: Tr.t("Sigils") },
                 { id: "clipboard", label: Tr.t("Clipboard") }],
          keywords: "launcher search apps results calculate run window timer note task board prefix sigil order recent frequency favourite favorite pinned kept clipboard history copy paste images wipe lock",
          page: launcherPage },

        { id: "appearance", category: "desk", icon: "󰔏", label: Tr.t("Appearance"),
          blurb: Tr.t("Palette, windows, fonts and animations."),
          tabs: [{ id: "theme", label: Tr.t("Theme") },
                 { id: "windows", label: Tr.t("Windows") },
                 { id: "type", label: Tr.t("Type") },
                 { id: "motion", label: Tr.t("Motion") }],
          keywords: "appearance theme colour color wallpaper transition fade wipe wave circle random greeting fastfetch fa terminal scene lava lamp critters koi invaders shadow rounding blur gaps border opacity glass rules font family sans mono nerd icons typeface animation speed curve easing preset motion",
          page: appearancePage },

        { id: "monitors", category: "desk", icon: "󰍹", label: Tr.t("Displays"),
          blurb: Tr.t("Screen layout, modes and the laptop lid."),
          tabs: [{ id: "arrangement", label: Tr.t("Arrangement") },
                 { id: "screen", label: Tr.t("The screen") },
                 { id: "lid", label: Tr.t("The lid") },
                 { id: "night", label: Tr.t("Night light") }],
          keywords: "displays monitor screen resolution refresh scale rotate transform vrr mirror extend primary night light blue filter warm temperature gamma hyprsunset lid clamshell laptop close workspaces",
          page: monitorsPage },

        { id: "input", category: "desk", icon: "󰍽", label: Tr.t("Input"),
          blurb: Tr.t("The keyboard, the pointer and the cursor."),
          tabs: [{ id: "keyboard", label: Tr.t("Keyboard") },
                 { id: "pointer", label: Tr.t("Pointer") }],
          keywords: "input keyboard layout repeat mouse sensitivity pointer cursor size theme shake find",
          page: inputPage },

        { id: "keys", category: "desk", icon: "󰌌", label: Tr.t("Keys"),
          blurb: Tr.t("Every keybinding, the shell's and Hyprland's."),
          tabs: [{ id: "shell", label: Tr.t("The shell's own") },
                 { id: "compositor", label: Tr.t("The compositor's") }],
          keywords: "keys shortcut binding hotkey super rebind",
          page: keysPage },

        { id: "session", category: "session", icon: "󰌾", label: Tr.t("Session"),
          blurb: Tr.t("Your account, the lock screen and idle behaviour."),
          tabs: [{ id: "lock", label: Tr.t("Lock screen") },
                 { id: "idle", label: Tr.t("When you leave") }],
          keywords: "session lock blur password suspend security idle timeout sleep screen off dpms away never lock after avatar picture name account",
          page: sessionPage },

        { id: "system", category: "session", icon: "󰍛", label: Tr.t("System"),
          blurb: Tr.t("Profiles, language, this machine and reset."),
          tabs: [{ id: "profiles", label: Tr.t("Profiles") },
                 { id: "machine", label: Tr.t("This machine") }],
          keywords: "system about version cpu memory uptime reset defaults language spanish english profile profiles switch rename duplicate delete import export backup file json",
          page: systemPage }
    ]

    // ── THE GUIDE ───────────────────────────────────────────────────────────
    //
    // Where the help button takes each page, or one part of it, on the
    // documentation site. Keyed "section" or "section/part".
    readonly property string guideRoot: "https://andreumassanet.github.io/impasto-docs/"
    readonly property var guides: ({
        "bar": "shell/bar/",
        "bar/island": "shell/island/#settings",
        "bar/modules": "shell/bar/#arranging",
        "bar/workspaces": "shell/bar/#size-and-workspaces",
        "bar/notifications": "shell/island/#notifications",
        "widgets": "shell/desktop/",
        "widgets/widgets": "shell/desktop/#arranging",
        "controls": "shell/control-centre/#arranging",
        "dock": "shell/dock/#settings",
        "launcher": "shell/launcher/#settings",
        "launcher/sigils": "shell/launcher/#modes",
        "launcher/clipboard": "shell/launcher/#the-clipboard",
        "appearance": "shell/settings/#the-pages",
        "appearance/theme": "theming/palettes/",
        "monitors": "shell/displays/",
        "monitors/arrangement": "shell/displays/#arrangement",
        "monitors/screen": "shell/displays/#the-screen",
        "monitors/lid": "shell/displays/#the-lid",
        "monitors/night": "shell/displays/#night-light",
        "input": "shell/settings/#the-pages",
        "keys": "shell/keys-and-packages/#changing-a-key",
        "session": "shell/lock-and-login/",
        "session/lock": "shell/lock-and-login/#the-lock-screen",
        "session/idle": "shell/lock-and-login/#when-you-leave-it-alone",
        "system": "shell/settings/#profiles",
        "system/machine": "shell/settings/#language"
    })

    readonly property string guide: root.guideRoot
        + (root.guides[`${root.section}/${root.tab}`] ?? root.guides[root.section] ?? "")

    // ── NAVIGATION ──────────────────────────────────────────────────────────
    //
    // A history rather than a single id, so a page that links to another can
    // be left with the back button.
    property var trail: [{ section: "bar", tab: "island" }]
    property int cursor: 0

    readonly property string section: root.trail[root.cursor].section
    readonly property string tab: root.trail[root.cursor].tab

    readonly property var current:
        root.sections.find(entry => entry.id === root.section) ?? root.sections[0]

    function firstTab(id: string): string {
        const entry = root.sections.find(other => other.id === id)
        return entry && entry.tabs.length > 0 ? entry.tabs[0].id : ""
    }

    // The part each section was last left on.
    property var visited: ({})

    function go(id: string, wanted: string): void {
        const part = wanted !== undefined && wanted !== ""
            ? wanted : (root.visited[id] ?? root.firstTab(id))
        if (id === root.section && part === root.tab)
            return
        const path = root.trail.slice(0, root.cursor + 1)
        path.push({ section: id, tab: part })
        root.trail = path
        root.cursor = path.length - 1
        page.contentY = 0
    }

    function show(part: string): void {
        if (part === root.tab)
            return
        const kept = Object.assign({}, root.visited)
        kept[root.section] = part
        root.visited = kept
        const path = root.trail.slice()
        path[root.cursor] = { section: root.section, tab: part }
        root.trail = path
        page.contentY = 0
    }

    function back(): void {
        if (root.cursor > 0) {
            root.cursor--
            page.contentY = 0
        }
    }

    function forward(): void {
        if (root.cursor < root.trail.length - 1) {
            root.cursor++
            page.contentY = 0
        }
    }

    property string filter: ""

    function matches(entry: var): bool {
        const term = root.filter.trim().toLowerCase()
        if (term === "")
            return true
        // Labels are translated; keywords are English, so both languages match.
        const parts = entry.tabs.map(part => part.label).join(" ").toLowerCase()
        return entry.label.toLowerCase().includes(term)
            || entry.keywords.includes(term)
            || entry.blurb.toLowerCase().includes(term)
            || parts.includes(term)
    }

    readonly property var shown: root.sections.filter(entry => root.matches(entry))

    // Flattened: a heading per non-empty group followed by its sections, so a
    // single ListView and scroll position covers the whole sidebar.
    readonly property var sidebar: {
        const rows = []
        for (const group of root.categories) {
            const members = root.shown.filter(entry => entry.category === group.id)
            if (members.length === 0)
                continue
            rows.push({ heading: true, label: group.label, id: `head:${group.id}` })
            for (const entry of members)
                rows.push({ heading: false, label: entry.label,
                            icon: entry.icon, id: entry.id })
        }
        return rows
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: root.gap

        // ── SIDEBAR ─────────────────────────────────────────────────────────

        Rectangle {
            Layout.preferredWidth: 206
            Layout.maximumWidth: 206
            Layout.fillWidth: false
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: Theme.islandSurface
            border.color: Theme.islandBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // ── SIGNATURE ───────────────────────────────────────────────
                //
                // The name in the script face, beside the palette board painted
                // in the active palette.
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 38

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        PaletteBoard {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 34
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "impasto"
                            font.family: Theme.fontSignature
                            font.pixelSize: 28
                            color: Theme.text
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: Theme.radiusSmall
                    color: Theme.island
                    border.color: search.activeFocus ? Theme.accent : Theme.islandBorder
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        spacing: 8

                        Text {
                            text: "󰍉"
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            color: Theme.textMuted
                        }

                        TextInput {
                            id: search

                            Layout.fillWidth: true
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                            selectByMouse: true
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentText
                            clip: true
                            focus: true

                            onTextEdited: root.filter = text

                            // Escape clears the field first, and closes the
                            // window only once it is empty.
                            Keys.onEscapePressed: event => {
                                if (search.text === "") {
                                    event.accepted = false
                                    return
                                }
                                search.text = ""
                                root.filter = ""
                            }

                            // Enter opens the first match.
                            Keys.onReturnPressed: {
                                if (root.shown.length > 0)
                                    root.go(root.shown[0].id, "")
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text === ""
                                text: Tr.t("Search settings")
                                font: search.font
                                color: Theme.textMuted
                            }
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 1
                    model: root.sidebar
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: entry

                        required property var modelData

                        readonly property bool active:
                            !entry.modelData.heading
                            && entry.modelData.id === root.section

                        width: ListView.view.width
                        height: entry.modelData.heading ? 24 : 30

                        // Group heading; not clickable.
                        Text {
                            visible: entry.modelData.heading
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            text: entry.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                            color: Theme.textMuted
                            opacity: 0.7
                        }

                        Rectangle {
                            visible: !entry.modelData.heading
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: entry.active ? Theme.islandSurfaceHover
                                : (entryMouse.containsMouse ? Theme.island : "transparent")
                            border.color: entry.active ? Theme.accent : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 11
                                anchors.rightMargin: 11
                                spacing: 11

                                Text {
                                    text: entry.modelData.icon ?? ""
                                    font.family: Theme.fontMono
                                    font.pixelSize: 13
                                    color: entry.active ? Theme.accent : Theme.textMuted
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: entry.modelData.label
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: entry.active ? Font.DemiBold : Font.Normal
                                    color: entry.active ? Theme.accent : Theme.text
                                }
                            }

                            MouseArea {
                                id: entryMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.go(entry.modelData.id, "")
                            }
                        }
                    }
                }
            }
        }

        // ── PAGE ────────────────────────────────────────────────────────────

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.gap

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                IconButton {
                    icon: "󰅁"
                    iconSize: 13
                    opacity: root.cursor > 0 ? 1 : 0.3
                    onClicked: root.back()
                }

                IconButton {
                    icon: "󰅂"
                    iconSize: 13
                    opacity: root.cursor < root.trail.length - 1 ? 1 : 0.3
                    onClicked: root.forward()
                }

                Item { Layout.fillWidth: true }

                // This page, or this part of it, on the documentation site.
                IconButton {
                    icon: "󰋗"
                    iconSize: 13
                    onClicked: Qt.openUrlExternally(root.guide)
                }

                IconButton {
                    icon: "󰅖"
                    iconSize: 13
                    onClicked: root.closed()
                }
            }

            // One scroll area for the whole page, hero and strip included;
            // sections never scroll on their own.
            Flickable {
                id: page

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: body

                    width: page.width
                    spacing: root.gap

                    SettingsHero {
                        Layout.fillWidth: true
                        icon: root.current.icon
                        title: root.current.label
                    }

                    TabStrip {
                        Layout.fillWidth: true
                        tabs: root.current.tabs
                        current: root.tab
                        onPicked: id => root.show(id)
                    }

                    Loader {
                        id: pageLoader

                        Layout.fillWidth: true
                        sourceComponent: root.current.page

                        onLoaded: pageLoader.item.tab = Qt.binding(() => root.tab)

                        onSourceComponentChanged: pageFade.restart()

                        NumberAnimation {
                            id: pageFade
                            target: pageLoader
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.durationFast
                            easing.type: Theme.easing
                        }
                    }
                }
            }
        }
    }

    Component { id: barPage;        BarSection {} }
    // Widgets are arranged on the desktop itself, behind this window.
    Component { id: widgetsPage;    WidgetsSection {
        onArranging: root.closed() } }
    // Open the control centre before closing, while this panel still exists
    // to emit the request.
    Component { id: controlsPage;   ControlsSection {
        onArranging: {
            root.panelRequested("controls")
            root.closed()
        } } }
    Component { id: dockPage;       DockSection {} }
    Component { id: launcherPage;   LauncherSection {} }
    Component { id: appearancePage; AppearanceSection {
        onPanelRequested: name => root.panelRequested(name) } }
    Component { id: inputPage;      InputSection {} }
    Component { id: monitorsPage;   MonitorsSection {} }
    Component { id: keysPage;       KeysSection {} }
    Component { id: sessionPage;    SessionSection {} }
    Component { id: systemPage;     SystemSection {} }
}
