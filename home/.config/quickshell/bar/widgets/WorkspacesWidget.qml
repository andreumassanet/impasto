// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W O R K S P A C E S   W I D G E T                                      │
// │   the workspace strip · dots, bars, rings or the number written out      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// Three states, by shape and weight alone:
//
//     focused    the accent: a wide pill, the tallest bar, the largest ring,
//                or a pill behind the number
//     occupied   solid but dim, or the number in full
//     empty      dimmer still: a grey dot or bar, a hollow ring, a grey number
//
// The first few are always shown; the rest appear with use. The dot's pill
// and the number's pill slide between positions rather than switching. Drawn
// in the accent: unlike the battery it carries no warning, so it follows the
// palette.
Rectangle {
    id: root

    // Inside the one capsule it drops its own capsule and padding.
    property bool chromeless: false
    property bool overWallpaper: false
    readonly property color dim: root.overWallpaper ? Theme.barInkDim : Theme.indicatorDim
    // `SettingsService.workspaceStyle` unless a picker draws another.
    property string style: SettingsService.workspaceStyle
    // A still strip for the settings: five, the second focused, the first and
    // third occupied, and nothing to click.
    property bool preview: false

    readonly property bool written: ["numbers", "roman", "kanji", "greek"]
        .indexOf(root.style) >= 0

    // The strip is about the screen it is drawn on: which workspace it is
    // showing and, per screen, which ten are its own. Off a screen of its own
    // it falls back to the focused one.
    readonly property string screenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property int activeId: root.preview ? 2
        : HyprlandService.activeOn(root.screenName) || HyprlandService.activeId

    readonly property int dotSize: 6
    readonly property int activeWidth: 22
    readonly property int barWidth: 3
    readonly property int ringSize: 7
    readonly property int slotSpacing: root.written ? 2 : 8
    // Around a number, inside its pill.
    readonly property int glyphPad: 6
    readonly property int pillHeight: Math.min(20, Theme.capsuleHeight - 10)
    // The focused workspace's applications, one icon per class, after its
    // mark: inside the pill in the written styles, beside the shape in the
    // others (`workspaceApps`).
    property bool apps: SettingsService.workspaceApps
    readonly property int appsShown: 4
    readonly property int appsSpacing: 5
    readonly property int appIconSize: root.pillHeight - 6

    // The icons for a workspace: its windows' classes, each once, resolved
    // the way the dock resolves them. The preview borrows the dock's first
    // pinned applications rather than asking for windows.
    function appIconsOn(n: int): var {
        const icons = []
        if (root.preview) {
            for (const id of DockService.pinned.slice(0, 2)) {
                const entry = DockService.entryOf(id)
                if (entry)
                    icons.push(Theme.appIcon(entry.icon))
            }
            return icons
        }
        const seen = []
        for (const client of HyprlandService.clientsOn(n)) {
            const windowClass = client.class || client.initialClass || ""
            if (windowClass === "" || seen.indexOf(windowClass) >= 0)
                continue
            seen.push(windowClass)
            const entry = DockService.entryOf(DockService.idFor(windowClass))
            icons.push(Theme.appIcon(entry ? entry.icon : windowClass.toLowerCase()))
            if (icons.length === root.appsShown)
                break
        }
        return icons
    }

    // The number a workspace is written as, in the written styles.
    function glyphOf(n: int): string {
        switch (root.style) {
        case "roman": {
            const table = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
            let out = ""
            for (const [value, mark] of table)
                while (n >= value) { out += mark; n -= value }
            return out
        }
        case "kanji": {
            const digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
            if (n < 10)
                return digits[n]
            return (n >= 20 ? digits[Math.floor(n / 10)] : "") + "十" + digits[n % 10]
        }
        case "greek":
            return "αβγδεζηθικλμνξοπρστυφχψω".charAt(n - 1) || String(n)
        default:
            return String(n)
        }
    }

    function isShown(n: int): bool {
        return root.preview ? n <= 5 : HyprlandService.isVisibleOn(n, root.screenName)
    }

    function isOccupied(n: int): bool {
        return root.preview ? n === 1 || n === 3 : HyprlandService.isOccupied(n)
    }

    implicitHeight: Theme.capsuleHeight
    // Each slot carries its own gap, so a collapsed one takes no space; the
    // spare gap is subtracted here.
    implicitWidth: layout.implicitWidth - root.slotSpacing
        + (root.chromeless ? 0 : (root.written ? 12 : 20))
    radius: Theme.radiusPill

    color: root.chromeless ? "transparent" : Theme.islandGround
    border.color: Theme.islandRim
    border.width: root.chromeless ? 0 : 1

    GlassSheen {
        shape: root
        visible: Theme.glass && !root.chromeless
    }

    // The written styles' focus: one pill that slides to the focused number
    // and takes its width.
    Rectangle {
        readonly property Item slot: {
            repeater.count
            return repeater.itemAt(root.activeId - 1)
        }

        visible: root.written && slot !== null && slot.shown
        x: slot ? layout.x + slot.x + root.slotSpacing / 2 : 0
        width: slot ? Math.max(0, slot.width - root.slotSpacing) : 0
        height: root.pillHeight
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: Theme.accent

        Behavior on x {
            enabled: !root.preview
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }
        Behavior on width {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        // Row spacing would still surround a collapsed slot.
        spacing: 0

        // A slot per workspace, shown or not, so arrivals and departures both
        // animate. A Repeater over only the visible ones would destroy items
        // and make the rest jump.
        Repeater {
            id: repeater

            model: root.preview ? 5 : HyprlandService.span

            Item {
                id: slot

                required property int index
                readonly property int workspaceId: slot.index + 1
                readonly property bool shown: root.isShown(slot.workspaceId)
                readonly property bool focused: root.activeId === slot.workspaceId
                readonly property bool occupied: root.isOccupied(slot.workspaceId)
                readonly property bool hovered: mouse.containsMouse
                readonly property var icons: root.apps && slot.focused
                    ? root.appIconsOn(slot.workspaceId) : []
                readonly property real iconsWidth: slot.icons.length
                    * (root.appIconSize + root.appsSpacing)

                // The mark alone, then with the icons after it, gap aside.
                readonly property real shape: {
                    switch (root.style) {
                    case "bars": return root.barWidth
                    case "rings": return root.ringSize + 2
                    case "dots": return slot.focused ? root.activeWidth : root.dotSize
                    default: return Math.max(root.pillHeight, glyph.implicitWidth + 2 * root.glyphPad)
                    }
                }
                readonly property real mark: slot.shape + slot.iconsWidth

                Layout.preferredWidth: slot.shown ? slot.mark + root.slotSpacing : 0
                Layout.preferredHeight: Theme.capsuleHeight
                Layout.alignment: Qt.AlignVCenter
                // A collapsed slot is no width, but a bar, a ring or a number
                // keeps its own and would draw over its neighbour.
                opacity: slot.shown ? 1 : 0
                visible: slot.opacity > 0

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                }
                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationFast }
                }

                // Dots and bars: the accent when focused or hovered, dimmed
                // when occupied, grey when empty.
                Rectangle {
                    visible: root.style === "dots" || root.style === "bars"
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -slot.iconsWidth / 2
                    width: root.style === "bars" ? root.barWidth
                        : Math.max(0, slot.shape)
                    height: root.style === "dots" ? root.dotSize
                        : slot.focused ? 14 : slot.occupied ? 9 : 5
                    radius: Math.min(width, height) / 2

                    color: slot.focused || slot.hovered || slot.occupied
                        ? Theme.accent : root.dim
                    // Dimming separates occupied from focused without a third
                    // shape.
                    opacity: slot.focused || slot.hovered ? 1 : (slot.occupied ? 0.55 : 1)

                    Behavior on height { NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing } }
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                }

                // Rings: filled and larger when focused, filled and dim when
                // occupied, hollow when empty.
                Rectangle {
                    visible: root.style === "rings"
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -slot.iconsWidth / 2
                    width: slot.focused ? root.ringSize + 2 : root.ringSize
                    height: width
                    radius: width / 2

                    color: slot.focused || slot.hovered ? Theme.accent
                        : slot.occupied ? Qt.alpha(Theme.accent, 0.55) : "transparent"
                    border.color: root.dim
                    border.width: slot.focused || slot.hovered || slot.occupied ? 0 : 1.5

                    Behavior on width { NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing } }
                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }

                // Over the wallpaper, a hovered number takes the chips' own
                // hover pill: the accent alone vanishes into a light picture.
                Rectangle {
                    visible: root.written && root.overWallpaper
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - root.slotSpacing)
                    height: Theme.capsuleHeight - 8
                    radius: height / 2
                    color: Theme.surfaceHoverIn(QsWindow.window)
                    opacity: slot.hovered && !slot.focused ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                }

                // The written styles: on the sliding pill when focused, in full
                // when occupied, grey when empty; `apps` adds the focused
                // workspace's icons after its number.
                Row {
                    id: face

                    anchors.centerIn: parent
                    spacing: root.appsSpacing

                    // The shape is drawn above; this keeps its room.
                    Item {
                        visible: !root.written
                        width: slot.shape
                        height: 1
                    }

                    Text {
                        id: glyph

                        visible: root.written
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.written ? root.glyphOf(root.preview ? slot.workspaceId
                            : HyprlandService.numberOn(slot.workspaceId, root.screenName)) : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: slot.focused ? Theme.accentText
                            : slot.hovered && !root.overWallpaper ? Theme.accent
                            : slot.occupied ? Theme.text : root.dim

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    Repeater {
                        model: slot.icons

                        IconImage {
                            required property string modelData

                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: root.appIconSize
                            source: modelData
                        }
                    }
                }

                // Fills the slot, gap included; a 6 px target is too small.
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: !root.preview
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: HyprlandService.focus(slot.workspaceId)
                }
            }
        }

        // A special workspace open over this screen, in every style: its
        // name and the applications in it; a click hides it. Never in a
        // preview, which is a picture of the strip and not of this screen.
        Rectangle {
            id: special

            readonly property string name: root.preview ? ""
                : HyprlandService.specialOn(root.screenName)
            readonly property string short: special.name.replace(/^special:/, "")
            readonly property var icons: {
                const icons = []
                const seen = []
                for (const client of HyprlandService.specialClientsOf(special.name)) {
                    const windowClass = client.class || client.initialClass || ""
                    if (windowClass === "" || seen.indexOf(windowClass) >= 0)
                        continue
                    seen.push(windowClass)
                    const entry = DockService.entryOf(DockService.idFor(windowClass))
                    icons.push(Theme.appIcon(entry ? entry.icon : windowClass.toLowerCase()))
                    if (icons.length === root.appsShown)
                        break
                }
                return icons
            }

            visible: special.name !== ""
            Layout.leftMargin: visible ? root.slotSpacing + 2 : 0
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: visible ? specialRow.implicitWidth + 2 * root.glyphPad + 2 : 0
            implicitHeight: root.pillHeight
            radius: height / 2
            color: Qt.alpha(Theme.accent, 0.22)
            border.color: Theme.accent
            border.width: 1

            Row {
                id: specialRow

                anchors.centerIn: parent
                spacing: root.appsSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: special.short === "scratchpad" ? Tr.t("Scratchpad") : special.short
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Repeater {
                    model: special.icons

                    IconImage {
                        required property string modelData

                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: root.appIconSize
                        source: modelData
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: HyprlandService.toggleSpecial(special.short)
            }
        }
    }
}
