// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S Y S T E M   S E C T I O N                                            │
// │   system · profiles, machine info and reset                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// Two parts: the profiles, with Reset under them (it resets only the active
// profile), and this machine: language, hardware and the colophon.
SettingsSection {
    id: root

    property string tab: "profiles"

    // `git describe`: a tag alone on a release, tag-commits-ghash between
    // releases, -dirty with edits. The release is the figure; the rest is
    // its note.
    function describe(text: string): var {
        const found = /^(v[^-]+)(?:-(\d+)-g([0-9a-f]+))?(-dirty)?$/.exec(text)
        if (!found)
            return { name: text, note: [] }
        const bits = []
        if (found[2])
            bits.push(`+${found[2]} · ${found[3]}`)
        if (found[4])
            bits.push(Tr.t("edited"))
        return { name: found[1], note: bits }
    }

    // What `setup` recorded, with the branch in front of the note.
    readonly property var release: {
        const found = root.describe(VersionService.version)
        return { name: found.name || "—",
                 note: [VersionService.branch].concat(found.note)
                     .filter(bit => bit !== "").join(" · ") }
    }

    // Where the update would leave that figure, written the same way.
    readonly property string destination: {
        const found = root.describe(VersionService.target)
        return [found.name].concat(found.note).filter(bit => bit !== "").join(" · ")
    }

    // Whether there is a checkout to ask about at all: none recorded, or one
    // recorded and no longer there.
    readonly property bool checkout: VersionService.repo !== ""
        && !(VersionService.answered && !VersionService.available)

    // One line on the checkout: what it is doing, what it found, or nothing
    // at all when there is nothing to ask.
    readonly property string waiting: {
        if (!root.checkout)
            return ""
        if (VersionService.answered && VersionService.upstream === "")
            return Tr.t("No remote to compare with")
        if (VersionService.checking)
            return Tr.t("Checking…")
        if (VersionService.checkedAt <= 0)
            return Tr.t("Not checked yet")
        if (VersionService.offline)
            return Tr.t("The remote did not answer")
        if (VersionService.behind === 0)
            return `${Tr.t("Up to date")} · ${Tr.t("checked at")} `
                + Qt.formatTime(new Date(VersionService.checkedAt),
                                SettingsService.clockFormat)
        // What it would become is the Update row's, below it.
        return `${VersionService.behind} `
            + Tr.t(VersionService.behind === 1 ? "commit waiting" : "commits waiting")
    }

    function spell(seconds: int): string {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        if (days > 0)
            return `${days}d ${hours}h`
        if (hours > 0)
            return `${hours}h ${minutes}m`
        return `${minutes}m`
    }

    // ── PROFILES ────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "profiles"
        spacing: root.spacing

        ProfilesPart {}

        SettingGroup {
            title: Tr.t("Reset")
            note: Tr.t("Only the profile in use. The others are left as they were.")
            hint: Tr.t("Reset returns every setting in this profile to its default, clears the compositor overrides and reloads Hyprland. Machine settings such as screens, name, picture and language are kept, and there is no undo.")

            SettingRow {
                label: Tr.t("Where the settings live")

                Text {
                    text: "~/.local/state/quickshell"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }

            SettingRow {
                label: Tr.t("Reset this profile")
                reading: Tr.t("Back to the defaults")

                PillButton {
                    text: Tr.t("Reset")
                    icon: "󰜉"
                    implicitWidth: 92
                    implicitHeight: 30
                    onClicked: {
                        SettingsService.reset()
                        CompositorService.restoreDefaults()
                    }
                }
            }
        }
    }

    // ── THIS MACHINE ────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "machine"
        spacing: root.spacing

        // The remote is asked when the page opens, and only when the last
        // answer is old enough to be worth another.
        onVisibleChanged: if (visible) VersionService.checkStale()

        // Strings missing from `Tr.qml` fall back to English.
        SettingGroup {
            title: Tr.t("This window")
            note: Tr.t("The language of this window.")
            hint: Tr.t("Only the settings window is translated, and anything without a translation appears in English. Files the shell writes, such as generated themes, are always in English.")

            SettingRow {
                label: Tr.t("Language")

                SegmentedControl {
                    options: Tr.languages
                    current: SettingsService.language
                    onSelected: id => SettingsService.set("language", id)
                }
            }
        }

        SettingGroup {
            title: Tr.t("This machine")

            SettingBlock {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Figure {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        label: Tr.t("PROCESSOR")
                        value: StatsService.cpuModel || "—"
                        note: `${StatsService.cores.length} ${Tr.t("threads")}`
                    }

                    Figure {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        label: Tr.t("MEMORY")
                        value: StatsService.memoryTotal > 0
                            ? `${(StatsService.memoryTotal / 1024 / 1024 / 1024).toFixed(1)} GiB`
                            : "—"
                        note: `${Math.round(StatsService.memoryFraction * 100)}${Tr.t("% in use")}`
                    }

                    Figure {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        label: Tr.t("UPTIME")
                        value: StatsService.uptime > 0 ? root.spell(StatsService.uptime) : "—"
                        note: Tr.t("since boot")
                    }

                    // What `setup` last installed, and the branch it came from.
                    Figure {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        label: Tr.t("VERSION")
                        value: root.release.name
                        note: root.release.note
                    }
                }
            }
        }

        SettingGroup {
            title: Tr.t("Updates")
            note: Tr.t("impasto itself, not the packages it runs.")
            hint: Tr.t("Update pulls the checkout impasto was installed from and runs the installer again in a terminal, where its questions and your password stay visible.")

            SettingRow {
                label: Tr.t("Check for updates")
                reading: root.waiting
                alarm: VersionService.offline
                locked: !root.checkout
                reason: Tr.t("No checkout to update from")

                PillButton {
                    text: VersionService.checking ? Tr.t("Checking…") : Tr.t("Check")
                    icon: "󰑐"
                    enabled: !VersionService.checking
                    implicitWidth: 112
                    implicitHeight: 30
                    onClicked: VersionService.check()
                }
            }

            // Only when there is something to install: with nothing waiting
            // the row is an offer to do nothing. Locked when the pull would
            // refuse, rather than a button that is known to fail.
            SettingRow {
                visible: VersionService.behind > 0
                label: Tr.t("Update")
                reading: `${Tr.t("To")} ${root.destination}`
                locked: VersionService.ahead > 0
                reason: Tr.t("Commits of your own are not on the remote")

                PillButton {
                    text: Tr.t("Update")
                    icon: "󰚰"
                    active: true
                    implicitWidth: 112
                    implicitHeight: 30
                    onClicked: VersionService.update()
                }
            }

            // The commits the update would bring, newest first.
            SettingBlock {
                visible: VersionService.commits.length > 0

                Text {
                    text: Tr.t("WHAT IS WAITING")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                    color: Theme.textMuted
                }

                Repeater {
                    model: VersionService.commits

                    RowLayout {
                        id: entry

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: entry.modelData.hash
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.accent
                        }

                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.subject
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                        }
                    }
                }

                Text {
                    visible: VersionService.behind > VersionService.commits.length
                    text: `+${VersionService.behind - VersionService.commits.length} `
                        + Tr.t("more")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }
        }

        // Colophon: the palette board over the name in the signature face.
        Item {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 8
            implicitHeight: colophon.implicitHeight

            Column {
                id: colophon

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                PaletteBoard {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 76
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 6
                    text: "impasto"
                    font.family: Theme.fontSignature
                    font.pixelSize: 30
                    color: Theme.text
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tr.t("A Hyprland shell, and the desk around it")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 4
                    text: "github.com/andreumassanet/impasto"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: repoMouse.containsMouse ? Theme.accent : Theme.textMuted
                    opacity: repoMouse.containsMouse ? 1 : 0.6

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    MouseArea {
                        id: repoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(
                            "https://github.com/andreumassanet/impasto")
                    }
                }
            }
        }
    }
}
