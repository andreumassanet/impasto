// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D O C K   P O P O U T                                                  │
// │   frame · an app's windows and menu, grown out of the dock               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

import "../theme"
import "../services"
import "../components"

// The dock drawer's popout: part of the dock's own shape, it grows out of the
// dock's inner edge beside the icon, in the dock's ground, square where it
// meets the dock and rounded beyond (the fillets are `DockDrawer`'s). It
// changes size with its content; the dock itself never widens.
//   menu     right-click: new window, pin or unpin, close every window, open
//            a new window on a workspace
//   windows  click: a row per window with a live preview, its title and
//            workspace, focus, send to a workspace, float, pin, fullscreen,
//            close
Item {
    id: root

    // The dock item (`DockService.items`), or null when closed; the last one
    // stays drawn while it shrinks.
    property var app: null
    property bool menu: false
    // "left", "right" or "bottom": the side the dock is on, so the card grows
    // from it.
    property string edge: "left"
    // The workspace before the first one the chips offer: the screen's own
    // ten when each screen has its own.
    property int workspaceBase: 0
    // The ten the chips offer: that one, moved by the arrows beside them
    // (`layerShift`), back to it for each opening. With one ten per screen
    // there is nothing to move to.
    property int layerShift: 0
    readonly property int highestBase: Math.max(0, Math.floor((HyprlandService.maximum - 1) / 10) * 10)
    readonly property int layerBase: Math.max(0, Math.min(root.highestBase, root.workspaceBase + 10 * root.layerShift))

    function shiftLayer(delta: int): void {
        const next = root.workspaceBase + 10 * (root.layerShift + delta)
        if (next >= 0 && next <= root.highestBase)
            root.layerShift += delta
    }

    signal done()
    signal windowsRequested()

    readonly property bool open: root.app !== null
    property var shownApp: null
    onAppChanged: if (root.app !== null) root.shownApp = root.app
    onShownAppChanged: root.layerShift = 0

    readonly property int padding: 10
    readonly property int cardWidth: root.menu ? 272 : 360
    readonly property int chips: Math.min(10, HyprlandService.maximum)

    readonly property bool vertical: root.edge !== "bottom"
    readonly property int corner: Theme.radiusLarge + 6
    // The card at its full size; the item shows as much of it as `reveal`
    // has grown out of the dock.
    readonly property real fullWidth: root.cardWidth
    readonly property real fullHeight: content.implicitHeight + 2 * root.padding
    property real reveal: root.open ? 1 : 0

    Behavior on reveal { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

    implicitWidth: root.vertical ? root.fullWidth * root.reveal : root.fullWidth
    implicitHeight: root.vertical ? root.fullHeight : root.fullHeight * root.reveal
    width: root.implicitWidth
    height: root.implicitHeight
    visible: root.reveal > 0.01
    clip: true

    Behavior on implicitHeight {
        enabled: root.vertical
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // The card slides out from behind the dock: anchored to the far side
    // while the item grows from the dock's.
    Item {
        id: card

        width: root.fullWidth
        height: root.fullHeight
        x: root.edge === "left" ? root.width - root.fullWidth : 0
        y: root.edge === "bottom" ? root.height - root.fullHeight : 0

        Rectangle {
            anchors.fill: parent
            color: Theme.islandGround
            topLeftRadius: root.edge === "left" ? 0 : root.corner
            bottomLeftRadius: root.edge === "left" || root.edge === "bottom" ? 0 : root.corner
            topRightRadius: root.edge === "right" ? 0 : root.corner
            bottomRightRadius: root.edge === "right" || root.edge === "bottom" ? 0 : root.corner
        }
    }

    ColumnLayout {
        id: content

        parent: card
        x: root.padding
        y: root.padding
        width: root.fullWidth - 2 * root.padding
        spacing: 8
        clip: true

        // ── HEADER ──────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22

                Image {
                    id: headerIcon

                    anchors.fill: parent
                    source: DockApps.iconOf(root.shownApp)
                    visible: DockApps.iconOf(root.shownApp) !== "" && status === Image.Ready
                    sourceSize: Qt.size(44, 44)
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !headerIcon.visible
                    text: "󰀻"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.textMuted
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.shownApp?.name ?? ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                visible: !root.menu && (root.shownApp?.windows.length ?? 0) > 1
                text: Tr.t("%1 windows").arg(root.shownApp?.windows.length ?? 0)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            Chip {
                visible: !root.menu && (root.shownApp?.id ?? "") !== ""
                glyph: "󰐕"
                onTriggered: {
                    DockService.launch(root.shownApp)
                    root.done()
                }
            }
        }

        // ── MENU ────────────────────────────────────────────────────────────

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.menu
            spacing: 2

            Row_ {
                visible: (root.shownApp?.id ?? "") !== ""
                glyph: "󰐕"
                label: Tr.t("New window")
                onTriggered: {
                    DockService.launch(root.shownApp)
                    root.done()
                }
            }

            Row_ {
                visible: (root.shownApp?.id ?? "") !== ""
                glyph: root.shownApp?.pinned ? "󰐄" : "󰐃"
                label: root.shownApp?.pinned ? Tr.t("Unpin from the dock") : Tr.t("Pin to the dock")
                onTriggered: {
                    DockService.togglePin(root.shownApp.id)
                    root.done()
                }
            }

            Row_ {
                visible: (root.shownApp?.windows.length ?? 0) > 0
                glyph: "󰖯"
                label: Tr.t("Show its windows (%1)").arg(root.shownApp?.windows.length ?? 0)
                onTriggered: root.windowsRequested()
            }

            Row_ {
                visible: (root.shownApp?.windows.length ?? 0) > 0
                glyph: "󰅖"
                label: (root.shownApp?.windows.length ?? 0) > 1 ? Tr.t("Close every window") : Tr.t("Close the window")
                danger: true
                onTriggered: {
                    DockService.closeAll(root.shownApp)
                    root.done()
                }
            }

            LayerHeader {
                visible: (root.shownApp?.id ?? "") !== ""
                Layout.topMargin: 6
                label: Tr.t("New window on workspace")
            }

            Grid {
                Layout.alignment: Qt.AlignHCenter
                visible: (root.shownApp?.id ?? "") !== ""
                columns: 5
                spacing: 4

                Repeater {
                    model: root.chips

                    Chip {
                        required property int index

                        width: 46
                        height: 32
                        label: String(root.layerBase + index + 1)
                        onTriggered: {
                            DockApps.launchOn(root.shownApp, root.layerBase + index + 1)
                            root.done()
                        }
                    }
                }
            }
        }

        // ── WINDOWS ─────────────────────────────────────────────────────────

        Repeater {
            // Keyed, so a title or focus change keeps the cards, their
            // previews and an open "send to workspace" picker.
            model: ScriptModel {
                objectProp: "address"
                values: root.menu ? [] : (root.shownApp?.windows ?? [])
            }

            Rectangle {
                id: windowCard

                required property var modelData
                // The full record: floating, pinned and fullscreen are not in
                // the dock's summary of the window.
                readonly property var client: DockApps.clientOf(windowCard.modelData.address) ?? {}
                property bool sending: false

                Layout.fillWidth: true
                implicitHeight: cardColumn.implicitHeight + 12
                radius: Theme.radiusLarge
                color: Theme.islandSurface

                Behavior on implicitHeight { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }

                ColumnLayout {
                    id: cardColumn

                    x: 6
                    y: 6
                    width: windowCard.width - 12
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // Live preview; a click focuses the window.
                        ClippingRectangle {
                            Layout.preferredWidth: 112
                            Layout.preferredHeight: 70
                            radius: Theme.radiusMedium
                            color: Theme.island

                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: root.open ? DockApps.toplevelFor(windowCard.client) : null
                                live: root.open
                                constraintSize: Qt.size(224, 140)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    HyprlandService.focusWindow(windowCard.modelData.address)
                                    root.done()
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: windowCard.modelData.title || Tr.t("Window")
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeRegular
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Tr.t("Workspace %1").arg(windowCard.client.workspace?.name ?? windowCard.modelData.workspace)
                                    + (windowCard.client.floating ? " · " + Tr.t("floating") : "")
                                    + (windowCard.client.pinned ? " · " + Tr.t("pinned") : "")
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.textMuted
                            }

                            Row {
                                Layout.topMargin: 4
                                spacing: 3

                                Chip { glyph: "󱂬"; lit: windowCard.sending; onTriggered: windowCard.sending = !windowCard.sending }
                                Chip { glyph: "󰖲"; lit: windowCard.client.floating ?? false; onTriggered: HyprlandService.toggleFloating(windowCard.modelData.address) }
                                Chip { glyph: "󰐃"; lit: windowCard.client.pinned ?? false; onTriggered: DockApps.togglePin(windowCard.modelData.address) }
                                Chip { glyph: "󰊓"; lit: (windowCard.client.fullscreen ?? 0) > 0; onTriggered: DockApps.toggleFullscreen(windowCard.modelData.address) }
                                Chip { glyph: "󰅖"; danger: true; onTriggered: HyprlandService.closeWindow(windowCard.modelData.address) }
                            }
                        }
                    }

                    // Send to a workspace, under the move chip.
                    LayerHeader {
                        visible: windowCard.sending
                        label: Tr.t("Send to workspace")
                    }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        visible: windowCard.sending
                        spacing: 3

                        Repeater {
                            model: root.chips

                            Chip {
                                required property int index
                                readonly property int workspaceId: root.layerBase + index + 1

                                width: 30
                                label: String(workspaceId)
                                lit: windowCard.modelData.workspace === workspaceId
                                onTriggered: {
                                    DockApps.moveTo(windowCard.modelData.address, workspaceId)
                                    windowCard.sending = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // A wide, flat row of the menu.
    component Row_: Rectangle {
        id: row

        property string glyph: ""
        property string label: ""
        property bool danger: false

        signal triggered()

        Layout.fillWidth: true
        implicitHeight: 38
        radius: 10
        color: rowMouse.containsMouse ? (row.danger ? Theme.red : Theme.islandSurfaceHover) : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Text {
                text: row.glyph
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLarge
                color: row.danger && rowMouse.containsMouse ? Theme.accentText : (row.danger ? Theme.red : Theme.text)
            }

            Text {
                Layout.fillWidth: true
                text: row.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: row.danger && rowMouse.containsMouse ? Theme.accentText : Theme.text
            }
        }

        MouseArea {
            id: rowMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.triggered()
        }
    }

    // A label over workspace chips: which ten they are, with the arrows that
    // move them a ten down or up.
    component LayerHeader: RowLayout {
        id: header

        property string label: ""

        Layout.fillWidth: true
        spacing: 4

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            text: header.label
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }

        Chip {
            glyph: "󰅃"
            width: 26
            height: 26
            visible: root.layerBase > 0
            onTriggered: root.shiftLayer(-1)
        }

        Text {
            text: `${root.layerBase + 1}–${root.layerBase + root.chips}`
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.features: { "tnum": 1 }
            color: root.layerShift !== 0 ? Theme.accent : Theme.text
        }

        Chip {
            glyph: "󰅀"
            width: 26
            height: 26
            visible: root.layerBase < root.highestBase
            onTriggered: root.shiftLayer(1)
        }
    }

    // A small square (a glyph) or short pill (a label).
    component Chip: Rectangle {
        id: chip

        property string glyph: ""
        property string label: ""
        property bool lit: false
        property bool danger: false

        signal triggered()

        width: 28
        height: 28
        radius: 8
        color: chip.lit ? Theme.accent
            : chipMouse.containsMouse ? (chip.danger ? Theme.red : Theme.islandSurfaceHover) : Theme.island

        Text {
            anchors.centerIn: parent
            text: chip.glyph !== "" ? chip.glyph : chip.label
            font.family: chip.glyph !== "" ? Theme.fontMono : Theme.fontFamily
            font.pixelSize: chip.glyph !== "" ? Theme.fontSizeMedium : Theme.fontSizeRegular
            color: chip.lit || (chip.danger && chipMouse.containsMouse) ? Theme.accentText : Theme.text
        }

        MouseArea {
            id: chipMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.triggered()
        }
    }
}
