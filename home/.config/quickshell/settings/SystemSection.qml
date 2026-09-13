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
import Quickshell
import Quickshell.Io

import "../theme"
import "../services"
import "../components"

// Two parts: the profiles, with Reset under them (it resets only the active
// profile), and this machine: language, hardware and the colophon.
SettingsSection {
    id: root

    property string tab: "profiles"

    // What `setup` last copied: the version, then the branch it came from.
    // Missing when the shell runs straight from a checkout.
    readonly property FileView versionFile: FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/impasto/version`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var version: (root.versionFile.loaded ? root.versionFile.text() : "").trim().split("\n")

    // `git describe`: a tag alone on a release, tag-commits-ghash between
    // releases, -dirty with edits. The figure is the release; the rest is
    // the note, after the branch.
    readonly property var release: {
        const found = /^(v[^-]+)(?:-(\d+)-g([0-9a-f]+))?(-dirty)?$/.exec(root.version[0] || "")
        if (!found)
            return { name: root.version[0] || "—", note: root.version[1] || "" }
        const bits = [root.version[1] || ""]
        if (found[2])
            bits.push(`+${found[2]} · ${found[3]}`)
        if (found[4])
            bits.push(Tr.t("edited"))
        return { name: found[1], note: bits.filter(bit => bit !== "").join(" · ") }
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
