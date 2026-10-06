// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I S L A N D   S U M M A R Y                                            │
// │   hover summary · one face, and a strip for the rest                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// The glance is always one face: a square at the near end, what it is beside
// it with its controls, and the time large at the far end with the day and
// the date under it. The face is the running thing with the most to press
// (`ModuleService.glanceFace`); everything else running is a chip on a strip
// under it. With nothing running the weather is the face, and without the
// weather the time is alone. The square is a slot, not a box: a cover fills
// it, and every other mark is drawn to fill it on the black.
//
// The square, the controls and the chips are the only things on it to
// press; a click anywhere else is the control centre.
Item {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Component.onCompleted: LyricsService.subscribe()
    Component.onDestruction: LyricsService.release()

    readonly property string face: ModuleService.glanceFace
    readonly property var locale: Qt.locale(SettingsService.language)
    readonly property int margin: ModuleService.glanceMargin
    readonly property int square: ModuleService.glanceFaceHeight - 2 * root.margin

    // What is in use, each in its fixed colour, as the island marks it.
    readonly property var privacyMarks: [
        { on: PrivacyService.microphone, glyph: "󰍬", tint: Theme.privacyMicrophone },
        { on: PrivacyService.cameraOn,   glyph: "󰄀", tint: Theme.privacyCamera },
        { on: PrivacyService.screen,     glyph: "󰍹", tint: Theme.privacyScreen }
    ].filter(mark => mark.on)
    // The first machine running, and what it is doing.
    readonly property var machine: VmService.running[0] ?? null
    readonly property string machineState: !root.machine ? ""
        : root.machine.paused ? Tr.t("Paused")
        : [Tr.t("Running"), VmService.uptime(root.machine.started),
           VmService.running.length > 1 ? `${VmService.running.length} ${Tr.t("running")}` : ""]
            .filter(part => part !== "").join(" · ")

    readonly property string privacyName: Tr.t(PrivacyService.microphone ? "Microphone"
        : PrivacyService.cameraOn ? "Camera" : "Screen")

    // The line being sung, once the lyrics have a first one; a gap between
    // verses is a note rather than the artist coming back.
    readonly property bool singing: LyricsService.available && LyricsService.synced
        && LyricsService.current >= 0
    readonly property string lyric: root.singing
        ? (LyricsService.currentText !== "" ? LyricsService.currentText : "♪") : ""

    // What a mark does at rest, for the square and the chips alike: the
    // take stops, the machine opens its panel, the rest open their detail
    // — the music's opens out round its lyrics when it has them.
    function press(id: string): void {
        if (id === "recorder")
            RecorderService.stop()
        else if (id === "machine")
            ModuleService.togglePanel("machines")
        else
            ModuleService.activate(id)
    }

    function title(id: string): string {
        switch (id) {
        case "media":
            return MediaService.title || MediaService.identity
        case "timer":
            return TimerService.label || Tr.t("Timer")
        case "recorder":
            return Tr.t("Recording")
        case "machine":
            return root.machine?.title ?? ""
        case "privacy":
            return root.privacyName
        case "weather":
            return [`${WeatherService.temperature}°`, WeatherService.description]
                .filter(part => part !== "").join(" · ")
        }
        return ""
    }

    function value(id: string): string {
        switch (id) {
        case "media":
            return MediaService.artist
        case "timer":
            return TimerService.display
        case "recorder":
            return `${Tr.t(RecorderService.subject)} · ${RecorderService.display}`
        case "machine":
            return root.machineState
        case "privacy":
            return PrivacyService.who
        case "weather":
            return [WeatherService.place, `${WeatherService.high}° / ${WeatherService.low}°`]
                .filter(part => part !== "").join(" · ")
        }
        return ""
    }

    // ── FACE ────────────────────────────────────────────────────────────────

    Item {
        id: slot

        x: root.margin
        y: root.margin
        width: root.square
        height: root.square
        visible: root.face !== "clock"

        MouseArea {
            anchors.fill: parent
            enabled: root.face !== "privacy"
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.press(root.face)
        }

        // Drawn once loaded: a parent hidden on its own `visible` would never
        // show the picture that decides it.
        readonly property bool cover: MediaService.artUrl !== "" && art.status === Image.Ready

        ClippingRectangle {
            anchors.fill: parent
            visible: root.face === "media" && slot.cover
            radius: width * Theme.pictureCorner
            color: "transparent"

            Image {
                id: art

                anchors.fill: parent
                source: MediaService.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 288
                sourceSize.height: 288
            }
        }

        Glyph {
            visible: root.face === "media" && !slot.cover
            text: "󰎇"
            font.pixelSize: Math.round(slot.width * 0.78)
        }

        RingIndicator {
            anchors.fill: parent
            anchors.margins: 6
            visible: root.face === "timer"
            thickness: 10
            progress: TimerService.progress
            trackColor: Theme.indicatorDim
            fillColor: TimerService.tint
        }

        // The dot, and a faint ring round it for the room it would fill.
        Rectangle {
            anchors.centerIn: parent
            visible: root.face === "recorder"
            width: Math.round(slot.width * 0.86)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: Theme.indicatorBad
            opacity: 0.35
        }

        Rectangle {
            anchors.centerIn: parent
            visible: root.face === "recorder"
            width: Math.round(slot.width * 0.5)
            height: width
            radius: width / 2
            color: Theme.indicatorBad
        }

        Glyph {
            visible: root.face === "machine"
            text: VmService.mark(root.machine?.os ?? "")
            font.pixelSize: Math.round(slot.width * 0.82)
        }

        Glyph {
            visible: root.face === "weather"
            text: WeatherService.glyph
            font.pixelSize: Math.round(slot.width * 0.86)
        }

        Row {
            anchors.centerIn: parent
            visible: root.face === "privacy"
            spacing: 4

            Repeater {
                model: root.privacyMarks

                Text {
                    required property var modelData

                    text: modelData.glyph
                    font.family: Theme.fontMono
                    font.pixelSize: Math.round(slot.width
                        * (root.privacyMarks.length > 2 ? 0.34 : root.privacyMarks.length > 1 ? 0.48 : 0.72))
                    color: modelData.tint
                }
            }
        }
    }

    Column {
        anchors.left: slot.right
        anchors.leftMargin: 16
        anchors.right: time.left
        anchors.rightMargin: 28
        anchors.verticalCenter: slot.verticalCenter
        visible: root.face !== "clock"
        spacing: 4

        Text {
            width: parent.width
            text: root.title(root.face)
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Bold
            color: Theme.text
        }

        // Under the music's title, the line being sung once there is one.
        Text {
            id: line

            width: parent.width
            visible: text !== ""
            text: root.lyric !== "" ? root.lyric : root.value(root.face)
            elide: Text.ElideRight
            wrapMode: root.lyric !== "" ? Text.Wrap : Text.NoWrap
            maximumLineCount: 2
            font.family: root.face === "timer" ? Theme.fontMono : Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular
            color: root.lyric !== "" ? Theme.text : Theme.textMuted

            onTextChanged: {
                if (root.lyric !== "")
                    turn.restart()
            }

            NumberAnimation {
                id: turn
                target: line
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.durationMedium
                easing.type: Theme.easing
            }
        }

        Item {
            width: 1
            height: 10
            visible: controls.visible
        }

        Row {
            id: controls

            visible: ["media", "timer", "machine", "recorder"].includes(root.face)
            spacing: 8

            Control {
                visible: root.face === "media"
                glyph: "󰒮"
                size: 17
                live: MediaService.canPrevious
                onPressed: MediaService.previous()
            }

            Control {
                visible: root.face === "media"
                glyph: MediaService.playing ? "󰏤" : "󰐊"
                size: 22
                live: MediaService.canToggle
                onPressed: MediaService.toggle()
            }

            Control {
                visible: root.face === "media"
                glyph: "󰒭"
                size: 17
                live: MediaService.canNext
                onPressed: MediaService.next()
            }

            Control {
                visible: root.face === "timer"
                glyph: "󰑐"
                size: 17
                onPressed: TimerService.restart()
            }

            Control {
                visible: root.face === "timer"
                glyph: TimerService.paused ? "󰐊" : "󰏤"
                size: 22
                onPressed: TimerService.toggle()
            }

            Control {
                visible: root.face === "timer"
                glyph: "󰅖"
                size: 17
                onPressed: TimerService.cancel()
            }

            Control {
                visible: root.face === "machine"
                glyph: "󰍹"
                size: 17
                onPressed: VmService.open(root.machine?.name ?? "")
            }

            Control {
                visible: root.face === "machine"
                glyph: root.machine?.paused ? "󰐊" : "󰏤"
                size: 22
                onPressed: root.machine?.paused ? VmService.resume(root.machine.name)
                                                : VmService.pause(root.machine?.name ?? "")
            }

            Control {
                visible: root.face === "machine"
                glyph: "󰐥"
                size: 17
                onPressed: VmService.stop(root.machine?.name ?? "")
            }

            Control {
                visible: root.face === "recorder"
                glyph: "󰓛"
                size: 22
                onPressed: RecorderService.stop()
            }
        }
    }

    // The same block in every face; alone, it is centred.
    Clock {
        id: time

        x: root.face === "clock" ? Math.round((root.width - width) / 2)
            : root.width - width - root.margin - 4
        anchors.verticalCenter: slot.verticalCenter
    }

    // ── STRIP ───────────────────────────────────────────────────────────────

    // Everything else running, one chip each: the island's mark, the name
    // and a reading. A chip does what that thing's mark does at rest.
    Row {
        x: root.margin + 4
        y: ModuleService.glanceFaceHeight - root.margin + 14
        height: 24
        spacing: 22

        Repeater {
            model: ModuleService.glanceStrip

            Item {
                id: chip

                required property string modelData

                width: content.width
                height: 24

                MouseArea {
                    anchors.fill: parent
                    enabled: chip.modelData !== "privacy"
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.press(chip.modelData)
                }

                Row {
                    id: content

                    height: 24
                    spacing: 8

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: chip.modelData === "privacy" ? privacyChip.width : 24
                        height: 24

                        Rectangle {
                            anchors.centerIn: parent
                            visible: chip.modelData === "recorder"
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.indicatorBad
                        }

                        Row {
                            id: privacyChip

                            anchors.centerIn: parent
                            visible: chip.modelData === "privacy"
                            spacing: 2

                            Repeater {
                                model: root.privacyMarks

                                Text {
                                    required property var modelData

                                    text: modelData.glyph
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: modelData.tint
                                }
                            }
                        }

                        RingIndicator {
                            anchors.centerIn: parent
                            visible: chip.modelData === "timer"
                            width: 16
                            height: 16
                            thickness: 2
                            progress: TimerService.progress
                            trackColor: Theme.indicatorDim
                            fillColor: TimerService.tint
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: chip.modelData === "machine"
                            text: VmService.mark(root.machine?.os ?? "")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.text
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 150)
                        elide: Text.ElideRight
                        text: root.title(chip.modelData)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeRegular
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    // Three or more, the readings that are words give way.
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ModuleService.glanceStrip.length < 3
                            || chip.modelData === "recorder" || chip.modelData === "timer"
                        width: Math.min(implicitWidth, 110)
                        elide: Text.ElideRight
                        text: chip.modelData === "recorder" ? RecorderService.display
                            : root.value(chip.modelData)
                        font.family: chip.modelData === "recorder" || chip.modelData === "timer"
                            ? Theme.fontMono : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeRegular
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // ── PIECES ──────────────────────────────────────────────────────────────

    // A mark drawn in the square at the size it is given.
    component Glyph: Text {
        anchors.centerIn: parent
        font.family: Theme.fontMono
        color: Theme.text
    }

    // The time in the heaviest weight, the day and the date under it in
    // capitals.
    component Clock: Column {
        id: face

        // Its own width, since its lines hang from its right edge.
        width: Math.max(hour.implicitWidth, weekday.implicitWidth, date.implicitWidth)
        spacing: -6

        Text {
            id: hour
            anchors.right: parent.right
            text: Qt.formatDateTime(clock.date, SettingsService.clockFormat)
            font.family: Theme.fontFamily
            font.pixelSize: 62
            font.weight: Font.Black
            color: Theme.text
        }

        Text {
            id: weekday
            anchors.right: parent.right
            text: root.locale.toString(clock.date, "dddd").toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.Black
            color: Theme.text
        }

        Text {
            id: date
            anchors.right: parent.right
            text: root.locale.toString(clock.date, "d MMMM").toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.Black
            color: Theme.textMuted
        }
    }

    // A player control: its glyph, lit under the pointer.
    component Control: Item {
        id: control

        property string glyph: ""
        property int size: 20
        property bool live: true
        signal pressed()

        width: control.size + 16
        height: width
        opacity: control.live ? 1 : 0.35

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.surfaceHoverIn(QsWindow.window)
            opacity: mouse.containsMouse && control.live ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }

        Text {
            anchors.centerIn: parent
            text: control.glyph
            font.family: Theme.fontMono
            font.pixelSize: control.size
            color: Theme.text
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            enabled: control.live
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.pressed()
        }
    }
}
