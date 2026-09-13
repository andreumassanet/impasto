// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O N I T O R S   S E C T I O N                                        │
// │   displays · arrangement, lid and night light                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// `MonitorService` keeps one arrangement per set of connected screens in the
// shell's settings and applies it with `hyprctl eval`; `monitors.lua` is the
// fallback and is never written.
//
// One group for the selected screen rather than one per screen. Changes apply
// on release with no confirmation; Forget hands the set back to Hyprland's
// `auto` placement. Rows for a disabled screen are locked, not hidden.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    Component.onCompleted: MonitorService.load()

    readonly property var monitors: MonitorService.monitors

    // Selection is the description, not an index: an index into a list that a
    // hotplug reorders points at a different screen afterwards.
    property string chosen: ""

    // Defaults to the primary screen rather than the first one enumerated.
    readonly property var current: {
        const found = root.monitors.find(m => m.description === root.chosen)
        if (found)
            return found
        const primary = root.monitors.find(
            m => m.name === MonitorService.effectivePrimaryName)
        return primary ?? root.monitors[0] ?? null
    }

    readonly property bool currentOff: root.current?.disabled ?? false

    // Merges fields into the selected screen's stored rule.
    function change(fields: var): void {
        if (root.current)
            MonitorService.remember(root.current.description, fields)
    }

    readonly property var screenOptions: root.monitors.map(m => ({
        id: m.description, label: m.name
    }))

    // Refresh rates available at the current resolution.
    readonly property var currentRefreshes: {
        const screen = root.current
        if (!screen)
            return []
        const group = (screen.resolutions ?? []).find(
            r => r.width === screen.width && r.height === screen.height)
        return group ? group.refreshes : []
    }

    readonly property bool lastLit:
        root.monitors.filter(m => !m.disabled).length <= 1
        && !root.currentOff

    readonly property bool mirrored: MonitorService.mirroring

    // Hyprland `transform` 0–3; the flipped transforms (4–7) are left out.
    readonly property var rotations: [
        { id: 0, label: Tr.t("None") },
        { id: 1, label: "90°" },
        { id: 2, label: "180°" },
        { id: 3, label: "270°" }
    ]


    // ── ARRANGEMENT ─────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "arrangement"

        SettingGroup {
            title: Tr.t("The screens")
            note: Tr.t("Drag one to move it, click one to change it.")
            hint: Tr.t("Arrangements are saved per set of connected monitors, identified by the monitor rather than the port, so moving a cable or closing the lid keeps them.")

            SettingBlock {
                MonitorCanvas {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 230

                    monitors: root.monitors
                    selected: root.current?.description ?? ""
                    enabled: !root.mirrored
                    opacity: root.mirrored ? 0.5 : 1

                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                    onPicked: description => root.chosen = description

                    onArranged: positions => {
                        for (const description in positions)
                            MonitorService.remember(description, {
                                position: `${positions[description].x}x${positions[description].y}`
                            })
                    }
                }
            }

            // Disabled screens have no geometry to draw on the canvas, so each
            // gets a row here instead; clicking one picks it.
            Repeater {
                model: root.monitors.filter(m => m.disabled)

                Item {
                    id: dark

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 42

                    SettingDivider {}

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: "󰶐"
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            color: root.chosen === dark.modelData.description
                                ? Theme.accent : Theme.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Tr.t("%1 — off, and still plugged in").arg(dark.modelData.name)
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.chosen = dark.modelData.description
                    }
                }
            }

            SettingRow {
                visible: root.monitors.length > 1
                label: Tr.t("Arrangement")
                reading: root.mirrored
                    ? Tr.t("Every screen shows the primary's") : Tr.t("Extended across all of them")

                SegmentedControl {
                    options: [
                        { id: "extend", label: Tr.t("Extend") },
                        { id: "mirror", label: Tr.t("Mirror") }
                    ]
                    current: root.mirrored ? "mirror" : "extend"
                    onSelected: id => MonitorService.rememberMirror(id === "mirror")
                }
            }

            SettingRow {
                visible: root.monitors.length > 1
                label: Tr.t("The island is on")
                reading: MonitorService.effectivePrimaryName

                SegmentedControl {
                    options: root.screenOptions
                    current: MonitorService.primaryScreen
                        ? (root.monitors.find(m => m.name === MonitorService.primaryScreen.name)
                            ?.description ?? "")
                        : ""
                    onSelected: id => MonitorService.rememberPrimary(id)
                }
            }
        }

        SettingGroup {
            visible: MonitorService.arranged
            title: Tr.t("This arrangement")
            note: Tr.t("Kept against these screens and no others.")

            SettingRow {
                label: Tr.t("Forget it")
                reading: Tr.t("Hands these screens back to Hyprland's own placement")

                PillButton {
                    text: Tr.t("Forget")
                    onClicked: MonitorService.forget()
                }
            }
        }
    }


    // ── SELECTED SCREEN ─────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "screen"

        SettingGroup {
            visible: root.monitors.length > 1
            title: Tr.t("Which screen")

            SettingRow {
                label: Tr.t("Editing")
                reading: root.current
                    ? `${root.current.make} ${root.current.model}`.trim() : ""

                SegmentedControl {
                    options: root.screenOptions
                    current: root.current?.description ?? ""
                    onSelected: id => root.chosen = id
                }
            }
        }

        // Named for the screen, and the monitor's own make and model.
        SettingGroup {
            visible: !!root.current
            title: root.current
                ? [root.current.name, `${root.current.make} ${root.current.model}`.trim()]
                    .filter(part => part !== "").join(" · ")
                : ""

            SettingRow {
                label: Tr.t("On")
                // Disabled: out of the layout, workspaces moved off it. DPMS
                // off: still in the layout with its workspaces, just dark.
                reading: {
                    if (root.currentOff)
                        return Tr.t("Off — out of the layout, and still plugged in")
                    if (root.current && !root.current.dpms)
                        return Tr.t("Dark — the panel is asleep, and the workspaces are still on it")
                    return ""
                }
                // The last enabled screen cannot be disabled; there would be
                // no way back.
                locked: root.lastLit
                reason: Tr.t("The only screen there is")

                ToggleSwitch {
                    checked: !root.currentOff
                    onToggled: checked => root.change({ disabled: !checked })
                }
            }

            SettingSlider {
                label: Tr.t("Scale")
                value: root.current?.scale ?? 1
                from: 1
                to: 3
                stepSize: 0.05
                decimals: 2
                unit: "×"
                locked: root.currentOff
                reason: Tr.t("The screen is off")
                onMoved: value => root.change({ scale: Math.round(value * 20) / 20 })
            }

            SettingRow {
                label: Tr.t("Rotation")
                locked: root.currentOff
                reason: Tr.t("The screen is off")

                SegmentedControl {
                    options: root.rotations.map(entry => ({
                        id: String(entry.id), label: entry.label
                    }))
                    current: String(root.current?.transform ?? 0)
                    onSelected: id => root.change({ transform: Number(id) })
                }
            }

            SettingRow {
                label: Tr.t("Variable refresh")
                locked: root.currentOff
                reason: Tr.t("The screen is off")

                ToggleSwitch {
                    checked: (root.current?.vrr ?? 0) !== 0
                    onToggled: checked => root.change({ vrr: checked ? 1 : 0 })
                }
            }
        }

        SettingGroup {
            visible: !!root.current
            title: Tr.t("Resolution")
            note: Tr.t("What the monitor itself reported, largest first.")
            hint: Tr.t("Only the modes the monitor reports are listed. Choosing a resolution selects its highest refresh rate.")

            SettingBlock {
                padding: 6
                enabled: !root.currentOff
                opacity: root.currentOff ? 0.55 : 1

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                ListView {
                    id: resolutions

                    Layout.fillWidth: true
                    Layout.preferredHeight: 148
                    clip: true
                    model: root.current?.resolutions ?? []
                    currentIndex: -1
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: line

                        required property var modelData

                        readonly property bool active:
                            !!root.current
                            && line.modelData.width === root.current.width
                            && line.modelData.height === root.current.height

                        width: resolutions.width
                        height: 32
                        radius: Theme.radiusSmall
                        color: active ? Theme.accent
                            : (hover.containsMouse ? Theme.islandSurfaceHover : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            Text {
                                Layout.fillWidth: true
                                text: `${line.modelData.width} × ${line.modelData.height}`
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                                color: line.active ? Theme.accentText : Theme.text
                            }

                            Text {
                                text: `${line.modelData.refreshes[0]} Hz`
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                color: line.active ? Theme.accentText : Theme.textMuted
                            }
                        }

                        MouseArea {
                            id: hover

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.change({
                                mode: `${line.modelData.width}x${line.modelData.height}@`
                                      + line.modelData.refreshes[0].toFixed(2)
                            })
                        }
                    }
                }
            }

            SettingRow {
                visible: (root.currentRefreshes?.length ?? 0) > 1
                label: Tr.t("Refresh rate")
                reading: `${(root.current?.refresh ?? 0).toFixed(2)} Hz`
                locked: root.currentOff
                reason: Tr.t("The screen is off")

                Row {
                    spacing: 6

                    Repeater {
                        model: root.currentRefreshes

                        PillButton {
                            required property var modelData

                            text: `${modelData} Hz`
                            active: Math.abs((root.current?.refresh ?? 0) - modelData) < 0.05
                            onClicked: root.change({
                                mode: `${root.current.width}x${root.current.height}@`
                                      + modelData.toFixed(2)
                            })
                        }
                    }
                }
            }
        }
    }


    // ── LID ─────────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.spacing
        visible: root.tab === "lid"

        SettingGroup {
            title: Tr.t("When the lid closes")
            note: Tr.t("Only applies with another screen connected.")
            hint: Tr.t("With nothing else connected, closing the lid is left to logind, which suspends. With another screen connected, the shell can switch the panel off and move its workspaces to the remaining screen, then bring them back when the lid opens.")

            SettingTiles {
                label: Tr.t("The laptop's screen")
                reading: SettingsService.lidPolicy === "off"
                    ? Tr.t("Switched off, and its workspaces move over")
                    : (SettingsService.lidPolicy === "keep"
                        ? Tr.t("Left on behind the lid")
                        : Tr.t("Left to the system"))
                locked: MonitorService.internalName === ""
                reason: Tr.t("No laptop panel on this machine")

                PreviewTile {
                    caption: Tr.t("Switch it off")
                    selected: SettingsService.lidPolicy === "off"
                    onPicked: SettingsService.set("lidPolicy", "off")

                    LidPreview {
                        anchors.centerIn: parent
                        lit: false
                        external: true
                    }
                }

                PreviewTile {
                    caption: Tr.t("Leave it on")
                    selected: SettingsService.lidPolicy === "keep"
                    onPicked: SettingsService.set("lidPolicy", "keep")

                    LidPreview {
                        anchors.centerIn: parent
                        lit: true
                        external: true
                    }
                }

                PreviewTile {
                    caption: Tr.t("The system decides")
                    selected: SettingsService.lidPolicy === "system"
                    onPicked: SettingsService.set("lidPolicy", "system")

                    LidPreview {
                        anchors.centerIn: parent
                        lit: true
                        external: false
                    }
                }
            }
        }

        SettingGroup {
            title: Tr.t("Right now")
            note: Tr.t("The current state, as the shell detects it.")

            SettingRow {
                label: Tr.t("The laptop's panel")
                reading: {
                    if (MonitorService.internalName === "")
                        return Tr.t("Not on this machine")
                    const found = MonitorService.internal
                    if (!found)
                        return Tr.t("Not on this machine")
                    if (found.disabled)
                        return Tr.t("%1 — off, and still plugged in").arg(found.name)
                    return Tr.t("%1 — on").arg(found.name)
                }

                Text {
                    text: MonitorService.internal
                        && !MonitorService.internal.disabled ? "󰍹" : "󰶐"
                    font.family: Theme.fontMono
                    font.pixelSize: 15
                    color: Theme.textMuted
                }
            }

            SettingRow {
                label: Tr.t("Other screens")
                reading: {
                    const others = root.monitors.filter(
                        m => m.name !== MonitorService.internalName)
                    if (others.length === 0)
                        return Tr.t("None — the system handles the lid")
                    return others.map(m => m.name).join(", ")
                }

                Text {
                    text: String(root.monitors.filter(
                        m => m.name !== MonitorService.internalName).length)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }
        }
    }


    // ── NIGHT LIGHT ─────────────────────────────────────────────────────────
    //
    // A gamma ramp through hyprsunset. The switch mirrors the control centre
    // tile (both read `SunsetService`); the temperature is only set here.

    SettingGroup {
        visible: root.tab === "night"
        title: Tr.t("Night light")
        note: Tr.t("Warmer colours for the evening.")
        hint: Tr.t("It adjusts the gamma ramp, so screenshots keep their original colours. There is no schedule: it stays on until you turn it off.")

        SettingRow {
            label: Tr.t("Warm the screen")
            locked: !SunsetService.available
            reason: Tr.t("Needs hyprsunset, which is not installed")

            ToggleSwitch {
                checked: SunsetService.on
                onToggled: SunsetService.toggle()
            }
        }

        SettingSlider {
            label: Tr.t("Colour temperature")
            value: SettingsService.nightTemperature
            from: SunsetService.warmest
            to: SunsetService.coolest
            stepSize: 100
            unit: " K"
            locked: !SunsetService.available
            reason: Tr.t("Needs hyprsunset, which is not installed")
            onMoved: value => SettingsService.set(
                "nightTemperature", Math.round(value / 100) * 100)
        }
    }
}
