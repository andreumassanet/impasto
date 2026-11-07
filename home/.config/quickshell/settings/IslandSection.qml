// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I S L A N D   S E C T I O N                                            │
// │   island · where it sits, the time, what runs beside it, notifications   │
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

// Two parts: the island at rest (where it meets the top edge, the time, what
// runs beside it, the glance), and the notifications that take it over. The
// shell is the notification daemon, so they are the island's.
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
            title: Tr.t("The island")
            note: Tr.t("Where the island meets the top edge, and what opens it.")
            hint: Tr.t("A notch cuts the island into the top edge, and the bar's top margin no longer applies to it.")

            SettingTiles {
                label: Tr.t("Position")
                locked: SettingsService.barStyle === "bezel"
                reason: Tr.t("The bezel is always cut into the top edge")
                reading: SettingsService.notched
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
                    caption: Tr.t("Notch")
                    selected: SettingsService.islandAttached
                    onPicked: SettingsService.set("islandAttached", true)

                    BarPreview {
                        anchors.centerIn: parent
                        attached: true
                        barStyle: SettingsService.barStyle
                    }
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
                label: Tr.t("Music on the resting island")
                reading: SettingsService.islandSpectrum ? Tr.t("Moving with the sound") : Tr.t("A still note")

                ToggleSwitch {
                    checked: SettingsService.islandSpectrum
                    onToggled: checked => SettingsService.set("islandSpectrum", checked)
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
                            text: Tr.date(clock.date, SettingsService.clockShowsSeconds
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
