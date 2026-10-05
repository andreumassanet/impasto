// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I S L A N D   S U M M A R Y                                            │
// │   hover summary · the time and what is playing                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// The glance, in three faces. With one thing running, it large: the cover
// or its mark in a square, what it is, its controls, and the time large at
// the far end with the day and the date under it. With more, a row for each,
// the music with its controls, and the time at the far end. With nothing:
// the time large with the weather on a small line under it, where the
// weather is already asked for, and at the far end five days of the week
// with today in the middle. The controls are the only things on it to press;
// a click anywhere else is the control centre.
Item {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Component.onCompleted: MediaService.subscribe()
    Component.onDestruction: MediaService.release()

    readonly property bool listed: ModuleService.glanceList
    readonly property string one: ModuleService.glanceOne
    readonly property var locale: Qt.locale(SettingsService.language)

    readonly property int margin: ModuleService.glanceMargin

    // What is in use, each in its fixed colour, as the island marks it.
    readonly property var privacyMarks: [
        { on: PrivacyService.microphone, glyph: "󰍬", tint: Theme.privacyMicrophone },
        { on: PrivacyService.cameraOn,   glyph: "󰄀", tint: Theme.privacyCamera },
        { on: PrivacyService.screen,     glyph: "󰍹", tint: Theme.privacyScreen }
    ].filter(mark => mark.on)
    readonly property string privacyName: Tr.t(PrivacyService.microphone ? "Microphone"
        : PrivacyService.cameraOn ? "Camera" : "Screen")

    // ── EVERYTHING RUNNING ──────────────────────────────────────────────────

    Item {
        anchors.fill: parent
        visible: root.listed

        Column {
            x: root.margin + 4
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: ModuleService.glanceRows

                Row {
                    id: row

                    required property string modelData

                    height: ModuleService.glanceRow
                    spacing: 12

                    // The mark, in a fixed slot so the names line up.
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24

                        Rectangle {
                            anchors.centerIn: parent
                            visible: row.modelData === "recorder"
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.indicatorBad
                        }

                        Row {
                            anchors.centerIn: parent
                            visible: row.modelData === "privacy"
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
                            visible: row.modelData === "timer"
                            width: 16
                            height: 16
                            thickness: 2
                            progress: TimerService.progress
                            trackColor: Theme.indicatorDim
                            fillColor: TimerService.tint
                        }

                        ClippingRectangle {
                            anchors.fill: parent
                            visible: row.modelData === "media"
                            radius: width * Theme.pictureCorner
                            color: rowArt.visible ? "transparent" : Theme.surfaceHoverIn(QsWindow.window)

                            Image {
                                id: rowArt

                                anchors.fill: parent
                                source: row.modelData === "media" ? MediaService.artUrl : ""
                                visible: source != "" && status === Image.Ready
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 48
                                sourceSize.height: 48
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 150)
                        elide: Text.ElideRight
                        text: row.modelData === "recorder" ? Tr.t("Recording")
                            : row.modelData === "privacy" ? root.privacyName
                            : row.modelData === "timer" ? Tr.t("Timer")
                            : (MediaService.title || MediaService.identity)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeRegular
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 110)
                        elide: Text.ElideRight
                        text: row.modelData === "recorder" ? RecorderService.display
                            : row.modelData === "privacy" ? PrivacyService.who
                            : row.modelData === "timer" ? TimerService.display
                            : MediaService.artist
                        font.family: row.modelData === "recorder" || row.modelData === "timer"
                            ? Theme.fontMono : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeRegular
                        color: Theme.textMuted
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData === "media"
                        spacing: 2

                        Control {
                            glyph: "󰒮"
                            size: 14
                            live: MediaService.canPrevious
                            onPressed: MediaService.previous()
                        }

                        Control {
                            glyph: MediaService.playing ? "󰏤" : "󰐊"
                            size: 16
                            live: MediaService.canToggle
                            onPressed: MediaService.toggle()
                        }

                        Control {
                            glyph: "󰒭"
                            size: 14
                            live: MediaService.canNext
                            onPressed: MediaService.next()
                        }
                    }
                }
            }
        }

        Clock {
            anchors.right: parent.right
            anchors.rightMargin: root.margin + 4
            anchors.verticalCenter: parent.verticalCenter
            align: Text.AlignRight
            timeSize: 62
        }
    }

    // ── ONE THING ───────────────────────────────────────────────────────────

    Item {
        anchors.fill: parent
        visible: root.one !== ""

        Item {
            id: cover

            x: root.margin
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 2 * root.margin
            height: width

            ClippingRectangle {
                anchors.fill: parent
                visible: root.one === "media"
                radius: width * Theme.pictureCorner
                // Only under the placeholder: a player that sends its own logo
                // rather than a cover sends it on transparency, and a box behind
                // it reads as part of the picture.
                color: art.visible ? "transparent" : Theme.surfaceHoverIn(QsWindow.window)

                Image {
                    id: art

                    anchors.fill: parent
                    source: MediaService.artUrl
                    visible: source != "" && status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 288
                    sourceSize.height: 288
                }

                Text {
                    anchors.centerIn: parent
                    visible: !art.visible
                    text: "󰎇"
                    font.family: Theme.fontMono
                    font.pixelSize: 34
                    color: Theme.indicator
                }
            }

            // The marks the island shows, at the cover's size.
            Rectangle {
                anchors.fill: parent
                visible: root.one !== "media"
                radius: width * Theme.pictureCorner
                color: Theme.surfaceIn(QsWindow.window)

                RingIndicator {
                    anchors.centerIn: parent
                    visible: root.one === "timer"
                    width: parent.width * 0.62
                    height: width
                    thickness: 6
                    progress: TimerService.progress
                    trackColor: Theme.indicatorDim
                    fillColor: TimerService.tint
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: root.one === "recorder"
                    width: parent.width * 0.36
                    height: width
                    radius: width / 2
                    color: Theme.indicatorBad
                }

                Row {
                    anchors.centerIn: parent
                    visible: root.one === "privacy"
                    spacing: 4

                    Repeater {
                        model: root.privacyMarks

                        Text {
                            required property var modelData

                            text: modelData.glyph
                            font.family: Theme.fontMono
                            font.pixelSize: root.privacyMarks.length > 1 ? 26 : 40
                            color: modelData.tint
                        }
                    }
                }
            }
        }

        Column {
            anchors.left: cover.right
            anchors.leftMargin: 16
            anchors.right: time.left
            anchors.rightMargin: 16
            anchors.verticalCenter: cover.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: root.one === "media" ? (MediaService.title || MediaService.identity)
                    : root.one === "timer" ? (TimerService.label || Tr.t("Timer"))
                    : root.one === "recorder" ? Tr.t("Recording")
                    : root.privacyName
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.text
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.one === "media" ? MediaService.artist
                    : root.one === "timer" ? TimerService.display
                    : root.one === "recorder" ? `${RecorderService.subject} · ${RecorderService.display}`
                    : PrivacyService.who
                elide: Text.ElideRight
                font.family: root.one === "timer" ? Theme.fontMono : Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: Theme.textMuted
            }

            Item {
                width: 1
                height: 10
            }

            Row {
                visible: root.one === "media"
                spacing: 8

                Control {
                    glyph: "󰒮"
                    size: 17
                    live: MediaService.canPrevious
                    onPressed: MediaService.previous()
                }

                Control {
                    glyph: MediaService.playing ? "󰏤" : "󰐊"
                    size: 22
                    live: MediaService.canToggle
                    onPressed: MediaService.toggle()
                }

                Control {
                    glyph: "󰒭"
                    size: 17
                    live: MediaService.canNext
                    onPressed: MediaService.next()
                }
            }

            Row {
                visible: root.one === "timer"
                spacing: 8

                Control {
                    glyph: "󰑐"
                    size: 17
                    onPressed: TimerService.restart()
                }

                Control {
                    glyph: TimerService.paused ? "󰐊" : "󰏤"
                    size: 22
                    onPressed: TimerService.toggle()
                }

                Control {
                    glyph: "󰅖"
                    size: 17
                    onPressed: TimerService.cancel()
                }
            }

            Row {
                visible: root.one === "recorder"

                Control {
                    glyph: "󰓛"
                    size: 22
                    onPressed: RecorderService.stop()
                }
            }
        }

        Clock {
            id: time

            anchors.right: parent.right
            anchors.rightMargin: root.margin + 4
            anchors.verticalCenter: cover.verticalCenter
            align: Text.AlignRight
            timeSize: 62
        }
    }

    // ── WITHOUT ONE ─────────────────────────────────────────────────────────

    Item {
        anchors.fill: parent
        visible: root.one === "" && !root.listed

        Column {
            x: root.margin + 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: -4

            Text {
                text: Qt.formatDateTime(clock.date, SettingsService.clockFormat)
                font.family: Theme.fontFamily
                font.pixelSize: 62
                font.weight: Font.Black
                color: Theme.text
            }

            Row {
                visible: ModuleService.summaryWeather
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: WeatherService.glyph
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeRegular
                    color: Theme.textMuted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: [`${WeatherService.temperature}°`, WeatherService.place ?? ""]
                        .filter(part => part !== "").join("  ·  ")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall + 1
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }
            }
        }

        // Five days, today in the middle: its short name over its date, lit;
        // the others a letter over a date, dim.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.margin + 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: 5

                Column {
                    id: day

                    required property int index

                    readonly property date date: {
                        const shown = new Date(clock.date)
                        shown.setDate(shown.getDate() + day.index - 2)
                        return shown
                    }
                    readonly property bool today: day.index === 2
                    readonly property string name: root.locale.toString(day.date, "ddd")
                        .replace(".", "").toUpperCase()

                    width: 30
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: day.today ? day.name : day.name.charAt(0)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.weight: Font.Bold
                        color: day.today ? Theme.accent : Theme.textMuted
                        opacity: day.today ? 1 : 0.7
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: day.date.getDate()
                        font.family: Theme.fontFamily
                        font.pixelSize: day.today ? 19 : 15
                        font.weight: day.today ? Font.Black : Font.DemiBold
                        color: day.today ? Theme.text : Theme.textMuted
                        opacity: day.today ? 1 : 0.55
                    }
                }
            }
        }
    }

    // ── PIECES ──────────────────────────────────────────────────────────────

    // The time in the heaviest weight, the day and the date under it in
    // capitals.
    component Clock: Column {
        id: face

        property int align: Text.AlignRight
        property int timeSize: 62

        spacing: -6

        Text {
            anchors.right: face.align === Text.AlignRight ? parent.right : undefined
            text: Qt.formatDateTime(clock.date, SettingsService.clockFormat)
            font.family: Theme.fontFamily
            font.pixelSize: face.timeSize
            font.weight: Font.Black
            color: Theme.text
        }

        Text {
            anchors.right: face.align === Text.AlignRight ? parent.right : undefined
            text: root.locale.toString(clock.date, "dddd").toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.Black
            color: Theme.text
        }

        Text {
            anchors.right: face.align === Text.AlignRight ? parent.right : undefined
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
