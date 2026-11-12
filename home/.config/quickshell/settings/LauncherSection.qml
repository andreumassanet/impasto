// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L A U N C H E R   S E C T I O N                                        │
// │   launcher · results, prefixes and clipboard                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../theme"
import "../services"
import "../components"

// Launcher modes are chosen by the first character typed; the sigils are
// listed and changed here.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    // Letters, digits and spaces start an application search, so none of them
    // can be a sigil, and neither can one another mode already uses.
    function accepts(mode: string, sigil: string): bool {
        if (sigil.length !== 1 || /[A-Za-z0-9 ]/.test(sigil))
            return false
        return !LauncherService.modes.some(other =>
            other.id !== mode && other.prefix === sigil)
    }

    // ── RESULTS ─────────────────────────────────────────────────────────────

    SettingGroup {
        visible: root.tab === "results"
        title: Tr.t("Where it opens")
        note: Tr.t("In the island, or growing from the bottom edge of the screen.")
        hint: Tr.t("The drawer is the same launcher, sigils included, growing from the bottom edge; the grid lists every application by category. The launcher key, the bar's button and the dock's open whichever is chosen. Resting on the bottom edge and the pinned search pill belong to the drawer and the grid.")

        SettingRow {
            label: Tr.t("Design")
            reading: SettingsService.launcherDesign === "grid"
                ? Tr.t("A grid of applications from the bottom edge")
                : SettingsService.launcherDesign === "drawer"
                    ? Tr.t("The launcher from the bottom edge")
                    : Tr.t("In the island")

            SegmentedControl {
                options: [
                    { id: "island", label: Tr.t("Island") },
                    { id: "drawer", label: Tr.t("Drawer") },
                    { id: "grid", label: Tr.t("Grid") }
                ]
                current: SettingsService.launcherDesign
                onSelected: id => SettingsService.set("launcherDesign", id)
            }
        }

        SettingRow {
            label: Tr.t("Open when resting on the edge")
            reading: SettingsService.launcherOnHover
                ? Tr.t("Rest on the bottom edge to open; leave without typing to close")
                : Tr.t("Only by key")
            locked: SettingsService.launcherDesign === "island"
            reason: Tr.t("Needs the drawer or the grid")

            ToggleSwitch {
                checked: SettingsService.launcherOnHover
                onToggled: checked => SettingsService.set("launcherOnHover", checked)
            }
        }

        SettingRow {
            label: Tr.t("Pinned search bar")
            reading: SettingsService.launcherPinned
                ? Tr.t("A search pill stays on the bottom edge; the windows keep clear of it")
                : Tr.t("Out of sight until opened")
            locked: SettingsService.launcherDesign === "island"
            reason: Tr.t("Needs the drawer or the grid")

            ToggleSwitch {
                checked: SettingsService.launcherPinned
                onToggled: checked => SettingsService.set("launcherPinned", checked)
            }
        }
    }

    SettingGroup {
        visible: root.tab === "results"
        title: Tr.t("The list")
        note: Tr.t("What the launcher lists with nothing typed, and how tall it gets.")
        hint: Tr.t("By use ranks applications by launches, with older launches counting for less; those kept on the dock come first until something else is used more. As tall as the answer sizes the island to the results, up to the limit above; off, the box is fixed and the list scrolls.")

        SettingRow {
            label: Tr.t("Order")

            SegmentedControl {
                options: [
                    { id: "recent", label: Tr.t("By use") },
                    { id: "alphabetical", label: Tr.t("Alphabetical") }
                ]
                current: SettingsService.launcherOrder
                onSelected: id => SettingsService.set("launcherOrder", id)
            }
        }

        SettingRow {
            label: Tr.t("Tap Super")
            reading: SettingsService.superTapLauncher
                ? Tr.t("Super pressed and let go alone opens the launcher")
                : Tr.t("Super alone does nothing")

            ToggleSwitch {
                checked: SettingsService.superTapLauncher
                onToggled: checked => SettingsService.set("superTapLauncher", checked)
            }
        }

        SettingSlider {
            label: Tr.t("Results shown")
            value: SettingsService.launcherResults
            from: 4
            to: 14
            reading: `${SettingsService.launcherResults} ${Tr.t("rows")}`
            onMoved: value => SettingsService.set("launcherResults", Math.round(value))
        }

        SettingRow {
            label: Tr.t("As tall as the answer")
            reading: SettingsService.launcherFits
                ? Tr.t("Only as tall as it needs") : Tr.t("A fixed box")

            ToggleSwitch {
                checked: SettingsService.launcherFits
                onToggled: checked => SettingsService.set("launcherFits", checked)
            }
        }

        SettingRow {
            label: Tr.t("Sums without a prefix")
            reading: SettingsService.launcherBareMath
                ? Tr.t("12 * 34 shows its answer as the first row")
                : Tr.t("Only after the calculator's prefix")

            ToggleSwitch {
                checked: SettingsService.launcherBareMath
                onToggled: checked => SettingsService.set("launcherBareMath", checked)
            }
        }

        // Skeleton preview of the list at the chosen length.
        SettingBlock {
            Behavior on implicitHeight {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 250
                implicitHeight: rows.implicitHeight + 20
                radius: Theme.radiusMedium
                color: Theme.island
                border.color: Theme.islandBorder
                border.width: 1

                ColumnLayout {
                    id: rows

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 3
                        spacing: 8

                        Text {
                            text: "󰍉"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: Theme.textMuted
                        }

                        Rectangle {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 4
                            radius: 2
                            color: Theme.textMuted
                            opacity: 0.5
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.hairline
                    }

                    Repeater {
                        model: SettingsService.launcherResults

                        Rectangle {
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 18
                            radius: Theme.radiusSmall - 2
                            color: index === 0 ? Theme.islandSurfaceHover : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 9
                                    Layout.preferredHeight: 9
                                    radius: 3
                                    color: Theme.islandSurfaceHover
                                    border.color: Theme.islandBorder
                                    border.width: 1
                                }

                                // Varied widths, so the skeleton reads as
                                // names rather than stripes.
                                Rectangle {
                                    Layout.preferredWidth: 48 + (index * 37) % 76
                                    Layout.preferredHeight: 4
                                    radius: 2
                                    color: Theme.textMuted
                                    opacity: index === 0 ? 0.8 : 0.4
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── FALLBACKS ───────────────────────────────────────────────────────────

    SettingGroup {
        visible: root.tab === "results"
        title: Tr.t("Fallbacks")
        note: Tr.t("Rows under the applications that act on the text as typed.")
        hint: Tr.t("Open an address, search the web, run the text as a command, or run it in a terminal that stays open. Only in the plain-text mode; a command runs as soon as its row is chosen.")

        SettingRow {
            label: Tr.t("Offer fallback rows")
            reading: SettingsService.launcherFallbacks
                ? Tr.t("Open, search, run") : Tr.t("Applications only")

            ToggleSwitch {
                checked: SettingsService.launcherFallbacks
                onToggled: checked => SettingsService.set("launcherFallbacks", checked)
            }
        }

        SettingField {
            label: Tr.t("Web search address")
            reading: Tr.t("The text is added at the end, encoded")
            placeholder: LauncherService.defaultSearchUrl
            value: SettingsService.launcherSearchUrl
            onEdited: value => SettingsService.set("launcherSearchUrl", value.trim())
        }
    }

    // ── SIGILS ──────────────────────────────────────────────────────────────
    //
    // Each sigil is edited in place, at the end of its mode's row.

    SettingGroup {
        visible: root.tab === "sigils"
        title: Tr.t("Sigils")
        note: Tr.t("Plain text searches applications, and a sigil in front switches mode. Click one to change it.")

        Repeater {
            model: LauncherService.modes

            SettingRow {
                id: mode

                required property var modelData
                readonly property bool fixed: mode.modelData.id === "apps"

                label: Tr.t(mode.modelData.label)
                reading: Tr.t(mode.modelData.hint)

                Rectangle {
                    implicitWidth: 34
                    implicitHeight: 28
                    radius: Theme.radiusSmall
                    color: Theme.island
                    border.color: sigil.activeFocus ? Theme.accent : Theme.islandBorder
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                    Text {
                        anchors.centerIn: parent
                        visible: mode.fixed
                        text: "abc"
                        font.family: Theme.fontMono
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        color: Theme.accent
                    }

                    TextInput {
                        id: sigil

                        anchors.fill: parent
                        visible: !mode.fixed
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        maximumLength: 1
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.accent
                        selectByMouse: true

                        text: mode.modelData.prefix
                        onTextEdited: {
                            if (root.accepts(mode.modelData.id, sigil.text))
                                SettingsService.setLauncherPrefix(
                                    mode.modelData.id, sigil.text)
                        }
                        // Revert to the stored value, so a rejected
                        // character does not look accepted.
                        onEditingFinished:
                            sigil.text = Qt.binding(() => mode.modelData.prefix)
                    }
                }
            }
        }
    }

    // ── CLIPBOARD ───────────────────────────────────────────────────────────
    //
    // The clipboard history is a launcher mode, so its settings live here.

    SettingGroup {
        visible: root.tab === "clipboard"
        title: Tr.t("Clipboard history")
        note: Tr.t("Everything copied, searchable from the launcher.")
        hint: Tr.t("Copies from password managers are never stored, and turning the history off stops the watcher entirely. Emptying on lock is off by default, since the lock already protects the session.")

        SettingRow {
            label: Tr.t("Keep a history")
            reading: SettingsService.clipboardHistory
                ? Tr.t("Watching") : Tr.t("Nothing kept")

            ToggleSwitch {
                checked: SettingsService.clipboardHistory
                onToggled: checked => SettingsService.set("clipboardHistory", checked)
            }
        }

        // Locked rather than hidden while the history is off.
        SettingSlider {
            label: Tr.t("Entries kept")
            value: SettingsService.clipboardKeep
            from: 20
            to: 500
            locked: !SettingsService.clipboardHistory
            reason: Tr.t("No history is being kept")
            onMoved: value => SettingsService.set("clipboardKeep", Math.round(value))
        }

        SettingRow {
            label: Tr.t("Keep images")
            reading: SettingsService.clipboardImages
                ? Tr.t("Pictures as well as text") : Tr.t("Text only")
            locked: !SettingsService.clipboardHistory
            reason: Tr.t("No history is being kept")

            ToggleSwitch {
                checked: SettingsService.clipboardImages
                onToggled: checked => SettingsService.set("clipboardImages", checked)
            }
        }

        SettingRow {
            label: Tr.t("Empty it on lock")
            reading: SettingsService.clipboardWipeOnLock
                ? Tr.t("Thrown away on lock") : Tr.t("Kept across a lock")
            locked: !SettingsService.clipboardHistory
            reason: Tr.t("No history is being kept")

            ToggleSwitch {
                checked: SettingsService.clipboardWipeOnLock
                onToggled: checked => SettingsService.set("clipboardWipeOnLock", checked)
            }
        }
    }
}
