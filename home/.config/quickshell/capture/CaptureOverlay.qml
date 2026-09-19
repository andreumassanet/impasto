// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A P T U R E   O V E R L A Y                                          │
// │   capture overlay · selection drawn on a screenshot                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Wayland

import "../theme"
import "../services"

// The capture surface: a screenshot taken by grim when the key was pressed,
// drawn full screen with everything outside the selection dimmed. Working on a
// still image means menus can be captured and nothing has to be frozen; the
// crop is cut from the same pixels.
//
// Exclusive zones are ignored so a drag that runs under the bar stays on this
// surface: the compositor ends a drag once the pointer leaves the surface it
// started on.
PanelWindow {
    id: root

    // The window under the pointer in window mode, the dragged box in region
    // mode.
    property rect selection: Qt.rect(0, 0, 0, 0)
    property bool dragging: false
    property real originX: 0
    property real originY: 0

    readonly property bool whole: CaptureService.shape === "screen"
    readonly property bool showing: root.whole
        || (root.selection.width > 1 && root.selection.height > 1)

    visible: CaptureService.active
    // The screen the photograph was taken of, so the picture is this screen
    // at its own size and the pointer lands where it looks.
    screen: CaptureService.screen
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "impasto-capture"
    // Exclusive, or hovering another window takes the keyboard back and Escape
    // stops working.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Window geometry is read once per opening: the image is static.
    Connections {
        target: CaptureService

        function onOpened(): void {
            root.selection = Qt.rect(0, 0, 0, 0)
            root.dragging = false
            HyprlandService.loadClients()
            keys.forceActiveFocus()
        }
    }

    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                CaptureService.cancel()
                break
            case Qt.Key_1:
                CaptureService.setShape("region")
                break
            case Qt.Key_2:
                CaptureService.setShape("window")
                break
            case Qt.Key_3:
                CaptureService.setShape("screen")
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.take()
                break
            default:
                return
            }
            event.accepted = true
        }

        // ── SCREENSHOT ──────────────────────────────────────────────────────

        Image {
            id: shot

            anchors.fill: parent
            source: CaptureService.photo === ""
                ? "" : `file://${CaptureService.photo}`
            // Stretch, not fit: the image is this screen at the output's
            // physical resolution.
            fillMode: Image.Stretch
            cache: false
            asynchronous: false
        }

        // ── OUTSIDE THE SELECTION ───────────────────────────────────────────
        //
        // Four rectangles rather than a mask or a shader: the hole is always
        // rectangular.

        Item {
            anchors.fill: parent
            visible: !root.whole

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.max(0, root.showing ? root.selection.y : parent.height)
                color: Theme.captureWash
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.showing
                    ? Math.max(0, parent.height - root.selection.y - root.selection.height)
                    : 0
                color: Theme.captureWash
            }

            Rectangle {
                visible: root.showing
                anchors.left: parent.left
                y: root.selection.y
                width: Math.max(0, root.selection.x)
                height: root.selection.height
                color: Theme.captureWash
            }

            Rectangle {
                visible: root.showing
                anchors.right: parent.right
                y: root.selection.y
                width: Math.max(0, parent.width - root.selection.x - root.selection.width)
                height: root.selection.height
                color: Theme.captureWash
            }
        }

        // In screen mode the selection is the whole screen; a wash at the edges
        // shows that a click will take it.
        Rectangle {
            anchors.fill: parent
            visible: root.whole
            color: "transparent"
            border.color: Theme.accent
            border.width: 3
        }

        // ── OUTLINE ─────────────────────────────────────────────────────────

        Rectangle {
            visible: root.showing && !root.whole
            x: root.selection.x
            y: root.selection.y
            width: root.selection.width
            height: root.selection.height
            color: "transparent"
            border.color: Theme.accent
            border.width: 2
        }

        // The size label sits above the box, or inside it when the box touches
        // the top of the screen.
        Rectangle {
            id: reading

            visible: root.showing && !root.whole
            x: Math.min(Math.max(0, root.selection.x),
                        parent.width - width)
            y: root.selection.y > height + 8
                ? root.selection.y - height - 8
                : root.selection.y + 8
            width: readingText.implicitWidth + 20
            height: 28
            radius: height / 2
            color: Theme.island
            border.color: Theme.islandBorder
            border.width: 1

            Text {
                id: readingText

                anchors.centerIn: parent
                text: `${Math.round(root.selection.width)} × ${Math.round(root.selection.height)}`
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }

        // ── POINTER ─────────────────────────────────────────────────────────

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: CaptureService.shape === "region"
                ? Qt.CrossCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onPositionChanged: mouse => {
                if (root.dragging) {
                    root.selection = Qt.rect(
                        Math.min(root.originX, mouse.x),
                        Math.min(root.originY, mouse.y),
                        Math.abs(mouse.x - root.originX),
                        Math.abs(mouse.y - root.originY))
                    return
                }
                if (CaptureService.shape === "window")
                    root.selection = root.windowUnder(mouse.x, mouse.y)
            }

            onPressed: mouse => {
                // The right button cancels.
                if (mouse.button === Qt.RightButton) {
                    CaptureService.cancel()
                    return
                }
                if (CaptureService.shape !== "region")
                    return
                root.dragging = true
                root.originX = mouse.x
                root.originY = mouse.y
                root.selection = Qt.rect(mouse.x, mouse.y, 0, 0)
            }

            onReleased: mouse => {
                if (mouse.button !== Qt.LeftButton)
                    return
                if (!root.dragging) {
                    // Window and screen modes take a single click.
                    if (CaptureService.shape !== "region")
                        root.take()
                    return
                }
                root.dragging = false
                // Ignore a click without a drag in region mode.
                if (root.selection.width < 4 || root.selection.height < 4) {
                    root.selection = Qt.rect(0, 0, 0, 0)
                    return
                }
                root.take()
            }
        }

        // ── BAR ─────────────────────────────────────────────────────────────

        CaptureBar {
            id: bar

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.captureBarMargin
            // Above the pointer area, so pressing a segment does not start a
            // selection.
            z: 5
            opacity: root.dragging ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }
        }
    }

    // ── WINDOW LOOKUP ───────────────────────────────────────────────────────

    // Topmost window containing the point. The surface covers one screen, so
    // its coordinates start at that screen's corner and hyprctl's start at the
    // compositor's; the corner is added to ask and taken off to answer.
    // hyprctl lists windows bottom to top, so the last match is the visible one.
    function windowUnder(x: real, y: real): rect {
        const clients = HyprlandService.clientsOn(HyprlandService.activeId)
        const left = root.screen?.x ?? 0
        const top = root.screen?.y ?? 0
        let found = Qt.rect(0, 0, 0, 0)
        for (const client of clients) {
            const at = client.at ?? [0, 0]
            const size = client.size ?? [0, 0]
            if (x + left >= at[0] && x + left <= at[0] + size[0]
                && y + top >= at[1] && y + top <= at[1] + size[1])
                found = Qt.rect(at[0] - left, at[1] - top, size[0], size[1])
        }
        return found
    }

    // Takes the capture. Screen mode passes no rectangle, so nothing is
    // cropped.
    function take(): void {
        if (root.whole) {
            CaptureService.fire(0, 0, 0, 0)
            return
        }
        if (CaptureService.shape === "window" && root.selection.width < 4) {
            const under = root.windowUnder(pointer.mouseX, pointer.mouseY)
            if (under.width < 4)
                return
            root.selection = under
        }
        if (root.selection.width < 4 || root.selection.height < 4)
            return
        CaptureService.fire(root.selection.x, root.selection.y,
                            root.selection.width, root.selection.height)
    }
}
