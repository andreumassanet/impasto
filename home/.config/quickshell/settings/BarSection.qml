// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A R   S E C T I O N                                                  │
// │   bar · island, layout, workspaces and notifications                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"
import "../services"
import "../components"

// Four parts: the island (bar style, and what the island shows at rest), the
// modules either side of it (`ModulesPart`), workspaces, and notifications.
// Notifications live here because the shell is the notification daemon and a
// notification takes over the island.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    // A live clock, so the format tiles show the real time in the real
    // typeface.
    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    // ── THE ISLAND ──────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "island"

        SettingGroup {
            title: Tr.t("Shape")
            note: Tr.t("How the bar is drawn, and where the island meets the top edge.")
            hint: Tr.t("The style keeps what is on the bar and only changes how it is drawn: grouped round the island, spread to the two edges, or all inside one capsule. What each side carries is arranged in The bar.")

            SettingTiles {
                label: Tr.t("Style")
                reading: Tr.t((SettingsService.barStyles.find(
                    entry => entry.id === SettingsService.barStyle) ?? { note: "" }).note)

                Repeater {
                    model: SettingsService.barStyles

                    PreviewTile {
                        id: styleTile

                        required property var modelData

                        caption: Tr.t(styleTile.modelData.label)
                        selected: SettingsService.barStyle === styleTile.modelData.id
                        onPicked: SettingsService.set("barStyle", styleTile.modelData.id)

                        BarPreview {
                            anchors.centerIn: parent
                            attached: SettingsService.islandAttached
                            barStyle: styleTile.modelData.id
                        }
                    }
                }
            }

            SettingTiles {
                label: Tr.t("Island")
                reading: SettingsService.islandAttached
                    ? Tr.t("Cut into the top edge")
                    : Tr.t("Floating below the top edge")

                PreviewTile {
                    caption: Tr.t("Floating")
                    selected: !SettingsService.islandAttached
                    onPicked: SettingsService.set("islandAttached", false)

                    BarPreview {
                        anchors.centerIn: parent
                        attached: false
                        barStyle: SettingsService.barStyle
                    }
                }

                PreviewTile {
                    caption: "Notch"
                    selected: SettingsService.islandAttached
                    onPicked: SettingsService.set("islandAttached", true)

                    BarPreview {
                        anchors.centerIn: parent
                        attached: true
                        barStyle: SettingsService.barStyle
                    }
                }
            }

            SettingTiles {
                label: Tr.t("Ground")
                reading: Tr.t(Theme.glass ? "The terminal's glass, over a blur" : "Solid black")

                Repeater {
                    model: [
                        { id: "classic", label: "Classic" },
                        { id: "glass", label: "Glass" }
                    ]

                    PreviewTile {
                        id: groundTile

                        required property var modelData

                        stageHeight: 56
                        caption: Tr.t(groundTile.modelData.label)
                        selected: (Theme.solid ? "classic" : SettingsService.surfaceStyle) === groundTile.modelData.id
                        onPicked: SettingsService.set("surfaceStyle", groundTile.modelData.id)

                        GroundSwatch {
                            anchors.centerIn: parent
                            style: groundTile.modelData.id
                        }
                    }
                }
            }

            // Locked in one capsule, where the sides sit on its band.
            SettingRow {
                label: Tr.t("Sides")
                reading: SettingsService.barSides === "bare"
                    ? Tr.t("The icons on the wallpaper")
                    : Tr.t("Each group in a capsule")
                locked: SettingsService.barStyle === "island"
                reason: Tr.t("In one island the sides sit on its band")

                SegmentedControl {
                    options: [
                        { id: "capsule", label: Tr.t("In capsules") },
                        { id: "bare", label: Tr.t("On the wallpaper") }
                    ]
                    current: SettingsService.barSides
                    onSelected: id => SettingsService.set("barSides", id)
                }
            }

            // Only the single-capsule style has a band that can span the
            // screen; locked in the other two.
            SettingRow {
                label: Tr.t("Span the whole screen")
                reading: SettingsService.barFullWidth
                    ? Tr.t("As wide as the bar can be")
                    : Tr.t("As wide as the island needs")
                locked: SettingsService.barStyle !== "island"
                reason: Tr.t("Only one island can span the screen")

                ToggleSwitch {
                    checked: SettingsService.barFullWidth
                    onToggled: checked => SettingsService.set("barFullWidth", checked)
                }
            }

            SettingRow {
                label: Tr.t("On every screen")
                reading: SettingsService.barEverywhere
                    ? Tr.t("One on each, and the one you are on is the live one")
                    : Tr.t("Only on the screen you are on")
                locked: Quickshell.screens.length < 2
                reason: Tr.t("Only one screen is on")

                ToggleSwitch {
                    checked: SettingsService.barEverywhere
                    onToggled: checked => SettingsService.set("barEverywhere", checked)
                }
            }

            SettingRow {
                label: Tr.t("Zen")
                reading: SettingsService.barHidden
                    ? Tr.t("The bar is away; the island still comes down to show something")
                    : Tr.t("Hides the bar and gives its band to the windows")

                ToggleSwitch {
                    checked: SettingsService.barHidden
                    onToggled: checked => SettingsService.set("barHidden", checked)
                }
            }

            SettingRow {
                label: Tr.t("A glance on hover")
                reading: SettingsService.islandSummary
                    ? Tr.t("Resting the pointer on the island opens it")
                    : Tr.t("Only a click opens anything")

                ToggleSwitch {
                    checked: SettingsService.islandSummary
                    onToggled: checked => SettingsService.set("islandSummary", checked)
                }
            }

            SettingRow {
                label: Tr.t("Lyrics")
                reading: SettingsService.lyrics
                    ? Tr.t("The playing track's lyrics are looked up on lrclib.net")
                    : Tr.t("No lyrics, and nothing is looked up")

                ToggleSwitch {
                    checked: SettingsService.lyrics
                    onToggled: checked => SettingsService.set("lyrics", checked)
                }
            }
        }

        // ── CLOCK ───────────────────────────────────────────────────────────

        SettingGroup {
            title: Tr.t("Clock")
            note: Tr.t("Shown on the resting island, and larger in the glance.")
            hint: Tr.t("Seconds make the clock repaint sixty times as often.")

            SettingTiles {
                label: Tr.t("Clock format")

                Repeater {
                    model: SettingsService.clockFormats

                    PreviewTile {
                        id: formatTile

                        required property var modelData

                        caption: Tr.t(formatTile.modelData.label)
                        selected: SettingsService.clockFormat === formatTile.modelData.id
                        onPicked: SettingsService.set("clockFormat", formatTile.modelData.id)

                        Text {
                            anchors.centerIn: parent
                            text: Qt.formatDateTime(clock.date, SettingsService.clockShowsSeconds
                                ? formatTile.modelData.id.replace("mm", "mm:ss")
                                : formatTile.modelData.id)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }
                }
            }

            SettingRow {
                label: Tr.t("Show the date")
                reading: SettingsService.clockShowsDate
                    ? Tr.t("Beside the time") : Tr.t("The time alone")

                ToggleSwitch {
                    checked: SettingsService.clockShowsDate
                    onToggled: checked => SettingsService.set("clockShowsDate", checked)
                }
            }

            SettingRow {
                label: Tr.t("Show seconds")

                ToggleSwitch {
                    checked: SettingsService.clockShowsSeconds
                    onToggled: checked => SettingsService.set("clockShowsSeconds", checked)
                }
            }
        }

        // ── BESIDE THE TIME ─────────────────────────────────────────────────
        //
        // Modules shown either side of the time while they run.

        SettingGroup {
            title: Tr.t("Beside the time")
            note: Tr.t("What is running sits either side of the time, two at most.")
            hint: Tr.t("A recording is always there and comes first; click its dot to stop it. Then the microphone, camera or screen in use, a countdown and media, which still work from their chips on the bar when kept off the island. The workspace comes last, for a bar without the strip; click it for the overview.")

            Repeater {
                model: SettingsService.besideChoices

                SettingRow {
                    id: besideRow

                    required property string modelData

                    readonly property bool privacy: besideRow.modelData === "privacy"
                    readonly property bool workspace: besideRow.modelData === "workspace"
                    readonly property bool machine: besideRow.modelData === "machine"
                    readonly property bool on: SettingsService.beside(besideRow.modelData)

                    label: besideRow.privacy ? Tr.t("Privacy")
                        : besideRow.workspace ? Tr.t("Workspace")
                        : besideRow.machine ? Tr.t("Virtual machines")
                        : Tr.t(ModuleService.entry(besideRow.modelData).name)
                    reading: besideRow.privacy
                        ? (besideRow.on ? Tr.t("What uses the microphone, camera or screen") : Tr.t("Not shown"))
                        : besideRow.workspace
                            ? (besideRow.on ? Tr.t("The one you are on") : Tr.t("Not shown"))
                        : besideRow.machine
                            ? (besideRow.on ? Tr.t("On the island while one runs") : Tr.t("Not shown"))
                        : besideRow.on
                            ? Tr.t("On the island while it runs") : Tr.t("Only where its chip is put")

                    ToggleSwitch {
                        checked: SettingsService.beside(besideRow.modelData)
                        onToggled: checked => SettingsService.setBeside(besideRow.modelData, checked)
                    }
                }
            }
        }

        SettingGroup {
            title: Tr.t("Scale")
            note: Tr.t("The bar itself is the preview: it repaints over this window as the sliders move.")
            hint: Tr.t("Everything on the bar scales with its height. The top margin is the gap to the screen edge (the island ignores it in notch mode), and the side margin is the inset from the left and right edges.")

            SettingSlider {
                label: Tr.t("Bar height")
                value: SettingsService.barHeight
                from: 24
                to: 48
                unit: " px"
                onMoved: value => SettingsService.set("barHeight", Math.round(value))
            }

            SettingSlider {
                label: Tr.t("Top margin")
                value: SettingsService.barMargin
                from: 0
                to: 32
                unit: " px"
                onMoved: value => SettingsService.set("barMargin", Math.round(value))
            }

            // Applies in every style, including the spanning band: its full
            // width is the screen less this margin.
            SettingSlider {
                label: Tr.t("Side margin")
                value: SettingsService.barSideMargin
                from: 0
                to: 48
                unit: " px"
                onMoved: value => SettingsService.set("barSideMargin", Math.round(value))
            }
        }
    }

    // ── MODULES ─────────────────────────────────────────────────────────────

    ModulesPart {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "modules"
    }

    // ── WORKSPACES ──────────────────────────────────────────────────────────

    SettingGroup {
        visible: root.tab === "workspaces"
        title: Tr.t("Workspaces")
        note: Tr.t("The shown workspaces are always drawn; the rest, up to the available count, appear only while they have windows.")

        SettingBlock {
            WorkspaceStyles {
                Layout.fillWidth: true
            }
        }

        SettingSlider {
            label: Tr.t("Workspaces shown")
            value: SettingsService.workspaceCount
            from: 1
            to: SettingsService.workspaceMax
            onMoved: value => SettingsService.set("workspaceCount", Math.round(value))
        }

        SettingSlider {
            label: Tr.t("Workspaces available")
            value: SettingsService.workspaceMax
            from: 4
            to: 20
            onMoved: value => {
                const max = Math.round(value)
                SettingsService.set("workspaceMax", max)
                // The ceiling cannot end up below the floor.
                if (SettingsService.workspaceCount > max)
                    SettingsService.set("workspaceCount", max)
            }
        }
    }

    // ── NOTIFICATIONS ───────────────────────────────────────────────────────

    SettingGroup {
        visible: root.tab === "notifications"
        title: Tr.t("Notifications")
        note: Tr.t("New notifications appear briefly in the island.")
        hint: Tr.t("The shell is the notification daemon: notifications without their own timeout use the time below, and critical ones stay until dismissed. Do not disturb only keeps them off the screen; they still collect in the control centre until the shell restarts.")

        // Locked while Do not disturb is on, since nothing is shown.
        SettingSlider {
            label: Tr.t("How long one stays")
            value: SettingsService.notificationTimeout / 1000
            from: 2
            to: 15
            unit: " s"
            locked: NotificationService.doNotDisturb
            reason: Tr.t("Nothing is shown while Do not disturb is on")
            onMoved: value => SettingsService.set(
                "notificationTimeout", Math.round(value) * 1000)
        }

        SettingRow {
            label: Tr.t("Do not disturb")
            reading: NotificationService.doNotDisturb
                ? Tr.t("Nothing takes the screen")
                : Tr.t("Everything is shown")

            ToggleSwitch {
                checked: NotificationService.doNotDisturb
                onToggled: NotificationService.toggleDoNotDisturb()
            }
        }

        SettingRow {
            label: Tr.t("Kept")
            reading: NotificationService.history.length > 0
                ? `${NotificationService.history.length} ${Tr.t("in this session")}`
                : Tr.t("Nothing kept")

            PillButton {
                text: Tr.t("Clear")
                icon: "󰜉"
                implicitWidth: 92
                implicitHeight: 30
                enabled: NotificationService.history.length > 0
                onClicked: NotificationService.clearHistory()
            }
        }
    }
}
