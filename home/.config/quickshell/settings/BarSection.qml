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
                label: Tr.t("A glance on hover")
                reading: SettingsService.islandSummary
                    ? Tr.t("Resting the pointer on the island opens it")
                    : Tr.t("Only a click opens anything")

                ToggleSwitch {
                    checked: SettingsService.islandSummary
                    onToggled: checked => SettingsService.set("islandSummary", checked)
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
            hint: Tr.t("A recording comes first, then a countdown, then media; click the recording dot to stop it. Anything kept off the island still works from its chip on the bar.")

            Repeater {
                model: SettingsService.besideDefaults

                SettingRow {
                    id: besideRow

                    required property string modelData

                    label: Tr.t(ModuleService.entry(besideRow.modelData).name)
                    reading: SettingsService.beside(besideRow.modelData)
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

        // Kept slots solid, the rest hollow (shown only while occupied).
        SettingBlock {
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: strip.implicitWidth + 24
                implicitHeight: 28
                radius: Theme.radiusPill
                color: Theme.island
                border.color: Theme.islandBorder
                border.width: 1

                Row {
                    id: strip

                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: SettingsService.workspaceMax

                        Rectangle {
                            required property int index

                            readonly property bool focused: index === 0
                            readonly property bool kept:
                                index < SettingsService.workspaceCount

                            anchors.verticalCenter: parent.verticalCenter
                            width: focused ? 22 : 6
                            height: 6
                            radius: height / 2
                            color: focused ? Theme.accent
                                : (kept ? Theme.indicatorDim : "transparent")
                            border.color: Theme.indicatorDim
                            border.width: kept ? 0 : 1
                            opacity: kept ? 1 : 0.45

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.durationMedium
                                    easing.type: Theme.easing
                                }
                            }
                        }
                    }
                }
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
