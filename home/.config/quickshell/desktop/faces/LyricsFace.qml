// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L Y R I C S   F A C E                                                  │
// │   the lyrics of what is playing, and nothing else                        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

import "../../theme"
import "../../services"

// Only the words, the same in every theme: the player is its own widget. In
// every family the lines running past, with the sung one held in the middle
// and the ones around it fading; the type follows the room. With no line to
// show, the reason, where the lines would be.
Item {
    id: root

    property string family: "4x2"
    property var ink: DesktopService.inkFor(null)

    readonly property int padding: root.width > 300 ? 22 : 18
    readonly property int size: root.family === "2x2" ? 16
        : root.family === "8x2" ? 22
        : root.family === "4x4" ? 21 : 19

    Component.onCompleted: LyricsService.subscribe()
    Component.onDestruction: LyricsService.release()

    // ── THE LINES ───────────────────────────────────────────────────────────

    Text {
        anchors.centerIn: lines
        width: lines.width
        visible: !LyricsService.available || LyricsService.instrumental
        // Silent with nothing playing, except while arranging, so it can be found.
        text: LyricsService.status !== "" ? Tr.t(LyricsService.status)
            : DesktopService.editing && !MediaService.available ? Tr.t("Nothing playing") : ""
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pixelSize: root.size
        font.weight: Font.Bold
        color: root.ink.muted
    }

    ListView {
        id: lines

        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        visible: LyricsService.available && !LyricsService.instrumental
        model: LyricsService.lines
        spacing: Math.round(root.size / 2)
        interactive: false
        currentIndex: LyricsService.synced ? LyricsService.current : -1
        highlightRangeMode: LyricsService.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        preferredHighlightBegin: height / 2 - root.size
        preferredHighlightEnd: height / 2 + root.size
        highlightMoveDuration: Theme.durationMorph
        header: Item { width: 1; height: LyricsService.synced ? lines.height / 2 : root.padding }
        footer: Item { width: 1; height: lines.height / 2 }

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fade
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        delegate: Text {
            id: verse

            required property var modelData
            required property int index

            readonly property int away: LyricsService.current < 0
                ? (LyricsService.synced ? verse.index + 1 : 1)
                : Math.abs(verse.index - LyricsService.current)

            width: lines.width
            text: verse.modelData.text !== "" ? verse.modelData.text : "♪"
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: root.size
            font.weight: Font.Bold
            color: root.ink.text
            opacity: verse.away === 0 ? 1 : Math.max(0.2, 0.45 - 0.1 * (verse.away - 1))

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
            }
        }
    }

    Rectangle {
        id: fade

        anchors.fill: lines
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.2; color: "white" }
            GradientStop { position: 0.8; color: "white" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
