// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O S K                                                                  │
// │   on-screen keyboard · a full keyboard along the bottom edge             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../theme"
import "../services"

// The rows are physical keys by evdev keycode, so they are the same for every
// layout but one: ISO keyboards have a key beside left Shift and the one
// beside Enter moves down a row. What each key says comes from the layout.
// Pinned, it keeps its space from the windows; it never takes the focus.
PanelWindow {
    id: root

    readonly property bool iso: OskService.keymap?.iso ?? true

    // { code, w (in keys), kind: key | shift | latch | gap, glyph, text,
    // repeat }; a w of 0 takes what the row has left.
    readonly property var rows: [
        [{ code: 1, text: "Esc", fn: true }].concat(
            [59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 87, 88].map((code, i) => ({ code: code, text: `F${i + 1}`, fn: true })),
            [{ code: 111, text: Tr.t("Del"), fn: true }]),
        [41, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13].map(code => ({ code: code })).concat(
            [{ code: 14, w: 2, glyph: "󰁮", repeat: true }]),
        [{ code: 15, w: 1.5, glyph: "󰌒" }].concat(
            [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27].map(code => ({ code: code })),
            root.iso ? [{ code: 28, w: 0, glyph: "󰌑" }] : [{ code: 43, w: 1.5 }]),
        [{ kind: "gap", w: 1.75 }].concat(
            [30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40].map(code => ({ code: code })),
            root.iso ? [{ code: 43 }, { kind: "gap", w: 0 }] : [{ code: 28, w: 0, glyph: "󰌑" }]),
        [{ code: 42, w: root.iso ? 1.25 : 2.25, kind: "shift", glyph: "󰘶" }].concat(
            root.iso ? [{ code: 86 }] : [],
            [44, 45, 46, 47, 48, 49, 50, 51, 52, 53].map(code => ({ code: code })),
            [{ code: 54, w: 0, kind: "shift", glyph: "󰘶" }]),
        [
            { code: 29, w: 1.5, kind: "latch", text: "Ctrl" },
            { code: 56, w: 1.25, kind: "latch", text: "Alt" },
            { code: 57, w: 0, repeat: true },
            { code: 100, w: 1.25, kind: "latch", text: root.iso ? "AltGr" : "Alt" },
            { code: 105, glyph: "←", repeat: true },
            { code: 103, glyph: "↑", repeat: true },
            { code: 108, glyph: "↓", repeat: true },
            { code: 106, glyph: "→", repeat: true }
        ]
    ]

    readonly property int rowWidth: 15 * Theme.oskKey + 14 * Theme.oskGap

    visible: SettingsService.osk && OskService.open && !LockService.locked
    anchors { bottom: true; left: true; right: true }
    implicitHeight: board.height + 2 * Theme.desktopGutter
    exclusiveZone: OskService.pinned ? board.height + Theme.desktopGutter : 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "impasto-osk"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: board }

    Rectangle {
        id: board

        anchors.centerIn: parent
        width: content.implicitWidth + 2 * Theme.oskPadding
        height: content.implicitHeight + 2 * Theme.oskPadding
        radius: Theme.radiusLarge
        color: Theme.islandGround
        border.color: Theme.islandRim

        RowLayout {
            id: content

            anchors.centerIn: parent
            spacing: Theme.oskPadding

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: Theme.oskGap

                Repeater {
                    model: [
                        { glyph: "󰐃", tip: "pin" },
                        { glyph: "󰌐", tip: "close" }
                    ]

                    Rectangle {
                        id: side

                        required property var modelData
                        readonly property bool lit: side.modelData.tip === "pin" && OskService.pinned

                        implicitWidth: Theme.oskButton
                        implicitHeight: Theme.oskButton
                        radius: Theme.radiusMedium
                        color: side.lit ? Theme.accent : sideMouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface

                        Text {
                            anchors.centerIn: parent
                            text: side.modelData.glyph
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLarge
                            color: side.lit ? Theme.accentText : Theme.text
                        }

                        MouseArea {
                            id: sideMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (side.modelData.tip === "pin")
                                    OskService.pinned = !OskService.pinned
                                else
                                    OskService.open = false
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                spacing: Theme.oskGap

                Repeater {
                    model: root.rows

                    RowLayout {
                        required property var modelData

                        Layout.preferredWidth: root.rowWidth
                        spacing: Theme.oskGap

                        Repeater {
                            model: parent.modelData

                            OskKey {
                                required property var modelData

                                keyData: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
