// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I   N   S   P   E   C   T   O   R                                      │
// │   widget inspector · per-widget appearance                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell.Widgets

import "../theme"
import "../services"
import "../components"

// Per-widget settings on a card beside the widget: shape, style, ink, opacity
// and removal. The first tile of each row follows the desktop default.
//
// Fills the surface so the card can go to the right of, the left of or below
// the widget, and so clicks on the card do not reach the background.
Item {
    id: root

    required property Item board

    readonly property string key: DesktopService.selected
    readonly property var row: DesktopService.entryOf(root.key)
    readonly property string moduleId: root.row ? root.row.id : ""
    readonly property var entry: ModuleService.entry(root.moduleId)
    readonly property var box: DesktopService.geometry(
        root.row ?? ({}), root.board.width, root.board.height)

    // A deck of notes on an edge rather than a widget on a cell: no shape, and
    // a list of notes.
    readonly property bool deck: DesktopService.isDeck(root.row)
    readonly property bool onNote: root.moduleId === "notes"
    readonly property bool onPhoto: root.moduleId === "photo"

    // The spectrum is its bars wherever it is: no face and no capsule, a look
    // and an opacity of its own instead. On an edge it is a strip, with a
    // height and no shape.
    readonly property bool onSpectrum: root.moduleId === "spectrum"
    readonly property bool strip: DesktopService.isSpectrum(root.row)
    readonly property var looks: DesktopService.spectrumOf(root.onSpectrum ? root.row : null)

    // Notes, photos and the spectrum have no capsule to style and no capsule
    // opacity to set.
    readonly property bool styled: !root.onNote && !root.onPhoto && !root.onSpectrum

    // Only a print has a chin to write in.
    readonly property bool captioned: root.onPhoto
        && DesktopService.themeOf(root.row) === "analogue"
        && DesktopService.familyOf(root.row) !== "8x2"

    // The caption field lets go when the surface loses the keyboard.
    Connections {
        target: DesktopService

        function onTypingChanged(): void {
            if (!DesktopService.typing)
                caption.focus = false
        }
    }

    Component.onDestruction: DesktopService.typing = false

    readonly property int cardWidth: 312
    readonly property int pad: 14
    readonly property int gap: 14

    // The widget's own overrides, empty when following the desktop.
    readonly property string ownTheme: root.row && root.row.theme ? root.row.theme : ""
    readonly property string ownStyle: root.row && root.row.style ? root.row.style : ""
    readonly property bool ownOpacity: root.row && typeof root.row.opacity === "number"

    // Colours for painting each style tile.
    function inkIn(style: string): var {
        return DesktopService.inkFor({ id: root.moduleId, style: style })
    }

    Rectangle {
        id: card

        // To the right of the widget, else the left, else below; kept on the
        // board.
        readonly property bool rightFits:
            root.box.x + root.box.width + root.gap + card.width
                <= root.board.width - Theme.desktopGutter
        readonly property bool leftFits:
            root.box.x - root.gap - card.width >= Theme.desktopGutter

        // Anything on the bottom edge has no side: the card goes above.
        readonly property bool above: (root.deck || root.strip) && root.row.edge === "bottom"

        x: card.above ? Math.max(Theme.desktopGutter, root.box.x + Theme.desktopGutter)
            : card.rightFits ? root.box.x + root.box.width + root.gap
            : (card.leftFits ? root.box.x - root.gap - card.width
                : Math.max(Theme.desktopGutter, Math.min(
                    root.board.width - Theme.desktopGutter - card.width, root.box.x)))
        y: card.above ? root.box.y - root.gap - card.height
            : Math.max(Theme.desktopGutter, Math.min(
                root.board.height - Theme.desktopGutter - card.height,
                card.rightFits || card.leftFits
                    ? root.box.y : root.box.y + root.box.height + root.gap))

        width: root.cardWidth
        height: column.implicitHeight + 2 * root.pad
        radius: Theme.radiusLarge
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1

        Behavior on x { NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing } }
        Behavior on y { NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing } }

        // Exclusive from the press; otherwise the background's tap handler also
        // fires and closes the card.
        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
        }

        Column {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.pad
            spacing: 12

            // ── TITLE AND REMOVE ────────────────────────────────────────────

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.entry
                        ? (root.deck ? `${Tr.t(root.entry.name)} · ${Tr.t("Notes on the edge")}` : Tr.t(root.entry.name))
                        : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                PillButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t("Remove")
                    implicitHeight: 26
                    onClicked: DesktopService.remove(root.key)
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.hairline }

            // ── SHAPE ───────────────────────────────────────────────────────
            //
            // The families this module has a face for, as footprints in cells.
            // The same choice as dragging the corner handle.

            Text {
                visible: !root.deck && !root.strip
                text: Tr.t("Shape")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Row {
                visible: !root.deck && !root.strip
                spacing: 8

                Repeater {
                    model: root.deck || root.strip ? []
                        : DesktopService.familiesFor(root.moduleId, DesktopService.themeOf(root.row))

                    Rectangle {
                        id: shapeTile

                        required property string modelData

                        readonly property var shape: DesktopService.family(shapeTile.modelData)
                        readonly property bool current:
                            DesktopService.familyOf(root.row) === shapeTile.modelData

                        width: shapeTile.shape.cols * 9 + 12
                        height: 48
                        radius: Theme.radiusSmall
                        color: shapeTile.current ? Theme.islandSurfaceHover : "transparent"
                        border.color: shapeTile.current ? Theme.accent : Theme.hairline
                        border.width: 1

                        Rectangle {
                            anchors.centerIn: parent
                            width: shapeTile.shape.cols * 9
                            height: shapeTile.shape.rows * 9
                            radius: 3
                            color: shapeTile.current ? Theme.accent : Theme.textMuted
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopService.setFamily(root.key, shapeTile.modelData)
                        }
                    }
                }
            }

            // ── WHERE ───────────────────────────────────────────────────────
            //
            // For a note: a grid cell or one of the three edges. Picking an
            // edge moves the note to that edge's deck; for a deck, it moves the
            // whole deck. The spectrum goes the same way, to an edge without
            // one.

            Text {
                visible: root.onNote || root.onSpectrum
                text: Tr.t("Where")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Row {
                visible: root.onNote || root.onSpectrum
                spacing: 8

                Repeater {
                    model: (root.onNote || root.onSpectrum ? [
                        { id: "grid", label: Tr.t("Grid"), icon: "󰕰" }
                    ] : []).concat(root.onNote || root.onSpectrum ? [
                        { id: "left", label: Tr.t("Left"), icon: "󰞕" },
                        { id: "right", label: Tr.t("Right"), icon: "󰞘" },
                        { id: "bottom", label: Tr.t("Bottom"), icon: "󰞖" }
                    ] : [])

                    Rectangle {
                        id: whereTile

                        required property var modelData

                        readonly property bool current: root.deck || root.strip
                            ? root.row.edge === whereTile.modelData.id
                            : whereTile.modelData.id === "grid"

                        // An edge that already has a spectrum takes no second.
                        readonly property bool taken: root.onSpectrum && !whereTile.current
                            && whereTile.modelData.id !== "grid"
                            && !DesktopService.spectrumTakes(DesktopService.nameOf(root.row),
                                whereTile.modelData.id)

                        opacity: whereTile.taken ? 0.4 : 1

                        width: 64
                        height: 48
                        radius: Theme.radiusSmall
                        color: whereTile.current ? Theme.islandSurfaceHover : "transparent"
                        border.color: whereTile.current ? Theme.accent : Theme.hairline
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: whereTile.modelData.icon
                                font.family: Theme.fontMono
                                font.pixelSize: 14
                                color: whereTile.current ? Theme.accent : Theme.textMuted
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: whereTile.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: whereTile.current ? Theme.text : Theme.textMuted
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                const where = whereTile.modelData.id
                                if (whereTile.current || whereTile.taken)
                                    return
                                const name = DesktopService.nameOf(root.row)
                                if (root.onSpectrum) {
                                    if (where === "grid")
                                        DesktopService.spectrumToGrid(root.key, name)
                                    else if (root.strip)
                                        DesktopService.setSpectrumEdge(root.key, name, where)
                                    else
                                        DesktopService.spectrumToEdge(root.key, name, where)
                                    return
                                }
                                if (root.deck) {
                                    if (where === "grid")
                                        return
                                    DesktopService.setDeckEdge(root.key, name, where)
                                    return
                                }
                                DesktopService.noteToEdge(root.key, name, where)
                            }
                        }
                    }
                }
            }

            // ── THE SPECTRUM'S LOOK ─────────────────────────────────────────
            //
            // Each tile is a sample of this strip with that one thing changed,
            // drawn from a fixed spectrum so it shows in silence too. Every
            // change lands on the strip at once.

            Heading {
                visible: root.onSpectrum
                text: Tr.t("Look")
            }

            Row {
                visible: root.onSpectrum
                spacing: 6

                Repeater {
                    model: root.onSpectrum ? DesktopService.spectrumLooks : []

                    SpectrumTile {
                        required property var modelData

                        current: root.looks.look === modelData.id
                        look: modelData.id
                        onChosen: DesktopService.setSpectrum(root.key, { look: modelData.id })
                    }
                }
            }

            Heading {
                visible: root.onSpectrum
                text: Tr.t("Fill")
            }

            Row {
                visible: root.onSpectrum
                spacing: 6

                Repeater {
                    model: root.onSpectrum ? DesktopService.spectrumFills : []

                    SpectrumTile {
                        required property var modelData

                        current: root.looks.fill === modelData.id
                        fillStyle: modelData.id
                        onChosen: DesktopService.setSpectrum(root.key, { fill: modelData.id })
                    }
                }
            }

            Text {
                visible: root.onSpectrum
                width: parent.width
                text: {
                    const look = DesktopService.spectrumLooks.find(entry => entry.id === root.looks.look)
                    const fill = DesktopService.spectrumFills.find(entry => entry.id === root.looks.fill)
                    return [look, fill].filter(entry => entry).map(entry => Tr.t(entry.label)).join(" · ")
                }
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            Heading {
                visible: root.onSpectrum
                text: root.looks.fill === "blend" ? Tr.t("From the edge") : Tr.t("Colour")
            }

            ColourRow {
                visible: root.onSpectrum
                field: "color"
            }

            Heading {
                visible: root.onSpectrum && root.looks.fill === "blend"
                text: Tr.t("To the tip")
            }

            ColourRow {
                visible: root.onSpectrum && root.looks.fill === "blend"
                field: "color2"
            }

            Heading {
                visible: root.onSpectrum
                text: Tr.t("Size")
            }

            Measure {
                visible: root.strip
                label: Tr.t("Height")
                field: "reach"
            }

            Measure {
                visible: root.onSpectrum
                label: Tr.t("Bars")
                field: "bar"
            }

            Measure {
                visible: root.onSpectrum
                label: Tr.t("Gap")
                field: "gap"
            }

            Heading {
                visible: root.onSpectrum
                text: Tr.t("Lows")
            }

            Row {
                visible: root.onSpectrum
                spacing: 8

                Repeater {
                    model: root.onSpectrum ? [
                        { id: "corners", label: Tr.t("At the corners") },
                        { id: "along", label: Tr.t("Along the edge") }
                    ] : []

                    Rectangle {
                        id: lowsTile

                        required property var modelData

                        readonly property bool current: root.looks.lows === lowsTile.modelData.id

                        width: 138
                        height: 34
                        radius: Theme.radiusSmall
                        color: lowsTile.current ? Theme.islandSurfaceHover : "transparent"
                        border.color: lowsTile.current ? Theme.accent : Theme.hairline
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: lowsTile.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: lowsTile.current ? Theme.text : Theme.textMuted
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopService.setSpectrum(root.key, { lows: lowsTile.modelData.id })
                        }
                    }
                }
            }

            Item {
                visible: root.onSpectrum
                width: parent.width
                height: 28

                Heading {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t("Peaks")
                }

                ToggleSwitch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.looks.peaks
                    onToggled: checked => DesktopService.setSpectrum(root.key, { peaks: checked })
                }
            }

            SliderRow {
                visible: root.onSpectrum
                width: parent.width
                height: 34
                icon: "󰊸"
                value: root.looks.opacity
                from: DesktopService.spectrumRanges.opacity.from
                to: DesktopService.spectrumRanges.opacity.to
                onMoved: value => DesktopService.setSpectrum(root.key, { opacity: value })
            }

            // ── ALIGNMENT ───────────────────────────────────────────────────
            //
            // For a deck: the start, centre or end of its edge. Finer placement
            // is the grip before the first tab.

            Text {
                visible: root.deck
                text: Tr.t("Along the edge")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Row {
                visible: root.deck
                spacing: 8

                Repeater {
                    model: root.deck ? [
                        { value: 0, label: Tr.t("Start") },
                        { value: 0.5, label: Tr.t("Middle") },
                        { value: 1, label: Tr.t("End") }
                    ] : []

                    Rectangle {
                        id: alongTile

                        required property var modelData

                        readonly property bool current: root.deck
                            && Math.abs(DesktopService.alongOf(root.row) - alongTile.modelData.value) < 0.01

                        width: 64
                        height: 30
                        radius: Theme.radiusSmall
                        color: alongTile.current ? Theme.islandSurfaceHover : "transparent"
                        border.color: alongTile.current ? Theme.accent : Theme.hairline
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: alongTile.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: alongTile.current ? Theme.text : Theme.textMuted
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopService.setDeckAlong(root.key, alongTile.modelData.value)
                        }
                    }
                }
            }

            // ── NOTES ───────────────────────────────────────────────────────
            //
            // For a deck: every note, ticked on or off this edge, in the order
            // ticked. Ticking a note here moves it from wherever it was.

            Text {
                visible: root.deck
                text: Tr.t("Which notes")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Column {
                visible: root.deck
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.deck ? NotesService.live : []

                    Rectangle {
                        id: tickRow

                        required property var modelData

                        readonly property bool on: root.deck
                            && DesktopService.deckNotes(root.row).indexOf(tickRow.modelData.key) >= 0
                        readonly property string elsewhere: {
                            const place = DesktopService.placementOf(tickRow.modelData.key)
                            return tickRow.on || place === "" ? "" : place
                        }

                        width: parent.width
                        height: 26
                        radius: Theme.radiusSmall
                        color: tickHover.hovered ? Theme.islandSurfaceHover : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 8

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: 4
                                color: tickRow.on ? Theme.accent : "transparent"
                                border.color: tickRow.on ? Theme.accent : Theme.textMuted
                                border.width: 1.5

                                Text {
                                    anchors.centerIn: parent
                                    visible: tickRow.on
                                    text: "󰄬"
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    color: Theme.accentText
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8
                                height: 8
                                radius: 4
                                color: NotesService.tintColor(tickRow.modelData.tint)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 30 - (elsewhereMark.visible ? elsewhereMark.width + 8 : 0)
                                text: NotesService.titleOf(tickRow.modelData)
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: tickRow.on ? Theme.text : Theme.textMuted
                            }

                            Text {
                                id: elsewhereMark

                                anchors.verticalCenter: parent.verticalCenter
                                visible: tickRow.elsewhere !== ""
                                text: tickRow.elsewhere === "grid" ? "󰕰" : "󰞘"
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                color: Theme.textMuted
                            }
                        }

                        HoverHandler { id: tickHover; cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopService.toggleDeckNote(root.key, tickRow.modelData.key)
                        }
                    }
                }
            }

            // ── NOTE ────────────────────────────────────────────────────────
            //
            // For a notes widget on a cell: the front of the deck (the default
            // when the row names none), then every note.

            Text {
                visible: root.onNote && !root.deck
                text: Tr.t("Which note")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Flow {
                visible: root.onNote && !root.deck
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.onNote && !root.deck
                        ? [{ key: "", text: Tr.t("The newest"), tint: "" }].concat(NotesService.live)
                        : []

                    Rectangle {
                        id: noteTile

                        required property var modelData

                        readonly property string noteKey: noteTile.modelData.key
                        readonly property bool current:
                            (root.row && root.row.note ? root.row.note : "") === noteTile.noteKey
                        readonly property string line: noteTile.noteKey === ""
                            ? noteTile.modelData.text
                            : NotesService.titleOf(noteTile.modelData)

                        width: Math.min(tileLine.implicitWidth + 24 + (noteTile.noteKey === "" ? 0 : 12), 140)
                        height: 26
                        radius: Theme.radiusPill
                        color: noteTile.current ? Theme.islandSurfaceHover : "transparent"
                        border.color: noteTile.current ? Theme.accent : Theme.hairline
                        border.width: 1

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: noteTile.noteKey !== ""
                                width: 7
                                height: 7
                                radius: 3.5
                                color: NotesService.tintColor(noteTile.modelData.tint)
                            }

                            Text {
                                id: tileLine

                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, noteTile.width - 24 - (noteTile.noteKey === "" ? 0 : 12))
                                text: noteTile.line
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: noteTile.current ? Theme.text : Theme.textMuted
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopService.update(root.key, { note: noteTile.noteKey || null })
                        }
                    }
                }
            }

            // ── PICTURE ─────────────────────────────────────────────────────
            //
            // For a photo: the picture, the picker (`Picker.qml`, in this
            // card's place) and a way to empty it. The only place a picture
            // is chosen.

            Text {
                visible: root.onPhoto
                text: Tr.t("Picture")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Row {
                visible: root.onPhoto
                spacing: 10

                ClippingRectangle {
                    width: 48
                    height: 48
                    radius: width * Theme.pictureCorner
                    color: Theme.islandSurface

                    Image {
                        id: thumbnail

                        anchors.fill: parent
                        source: root.onPhoto ? DesktopService.pictureOf(root.row) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 96
                        sourceSize.height: 96
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: thumbnail.status !== Image.Ready
                        text: "󰋩"
                        font.family: Theme.fontMono
                        font.pixelSize: 18
                        color: Theme.textMuted
                    }
                }

                PillButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t("Choose…")
                    implicitHeight: 26
                    onClicked: DesktopService.picking = root.key
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.onPhoto && DesktopService.pictureOf(root.row) !== ""
                    icon: "󰅖"
                    iconSize: 13
                    onClicked: DesktopService.update(root.key, { picture: null })
                }
            }

            // ── CAPTION ─────────────────────────────────────────────────────
            //
            // Written in the print's chin. Typing holds the keyboard until
            // Enter, Escape or a click anywhere else.

            Text {
                visible: root.captioned
                text: Tr.t("Caption")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Rectangle {
                visible: root.captioned
                width: parent.width
                height: 34
                radius: Theme.radiusSmall
                color: Theme.islandSurface
                border.color: caption.activeFocus ? Theme.accent : Theme.islandBorder
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                TextInput {
                    id: caption

                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.row && typeof root.row.caption === "string" ? root.row.caption : ""
                    maximumLength: 40
                    font.family: Theme.fontSignature
                    font.pixelSize: 19
                    color: Theme.text
                    selectByMouse: true
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    clip: true

                    onActiveFocusChanged: DesktopService.typing = caption.activeFocus
                    onTextEdited: DesktopService.update(root.key, { caption: caption.text === "" ? null : caption.text })
                    Keys.onReturnPressed: caption.focus = false
                    Keys.onEnterPressed: caption.focus = false
                    Keys.onEscapePressed: caption.focus = false

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: caption.text === "" && !caption.activeFocus
                        text: Tr.t("Written under the picture")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            // ── THEME ───────────────────────────────────────────────────────
            //
            // The default first (follows the settings), then each theme, drawn
            // as a live clock face.

            Text {
                visible: root.moduleId !== "notes" && !root.onSpectrum
                text: Tr.t("Face")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Row {
                visible: root.moduleId !== "notes" && !root.onSpectrum
                spacing: 8

                Repeater {
                    model: [{ id: "", label: "Default" }].concat(DesktopService.themes)

                    Rectangle {
                        id: themeTile

                        required property var modelData

                        readonly property string themeId: themeTile.modelData.id
                        readonly property string shown:
                            themeTile.themeId !== "" ? themeTile.themeId : SettingsService.desktopTheme
                        readonly property bool current: root.ownTheme === themeTile.themeId

                        width: 50
                        height: 48
                        radius: Theme.radiusSmall
                        color: "transparent"
                        border.color: themeTile.current ? Theme.accent : Theme.hairline
                        border.width: 1

                        ThemeSwatch {
                            anchors.centerIn: parent
                            theme: themeTile.shown
                            factor: 0.19
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 4
                            visible: themeTile.themeId === ""
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.textMuted
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopService.setTheme(root.key, themeTile.themeId)
                        }
                    }
                }
            }

            // ── STYLE ───────────────────────────────────────────────────────
            //
            // The default first, then the four styles, each tile painted as the
            // widget would be.

            // Not for notes or photos (`styled`).
            Text {
                visible: root.styled
                text: Tr.t("Style")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Row {
                visible: root.styled
                spacing: 8

                Repeater {
                    model: [{ id: "", label: "Default" }].concat(DesktopService.styles)

                    Rectangle {
                        id: styleTile

                        required property var modelData

                        readonly property string styleId: styleTile.modelData.id
                        // The style this tile shows; for the default tile, the
                        // desktop's style.
                        readonly property string shown:
                            styleTile.styleId !== "" ? styleTile.styleId : SettingsService.desktopStyle
                        readonly property var ink: root.inkIn(styleTile.shown)
                        readonly property bool current: root.ownStyle === styleTile.styleId

                        width: 50
                        height: 48
                        radius: Theme.radiusSmall
                        color: "transparent"
                        border.color: styleTile.current ? Theme.accent : Theme.hairline
                        border.width: 1

                        StyleSwatch {
                            anchors.centerIn: parent
                            style: styleTile.shown
                            ink: styleTile.ink
                        }

                        // A dot marks the default tile as "follow" rather than
                        // a fifth style.
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 4
                            visible: styleTile.styleId === ""
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.textMuted
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: DesktopService.setStyle(root.key, styleTile.styleId)
                        }
                    }
                }
            }

            Text {
                visible: root.styled
                width: parent.width
                text: {
                    const theme = DesktopService.themes.find(
                        entry => entry.id === DesktopService.themeOf(root.row))
                    const style = DesktopService.styles.find(
                        entry => entry.id === DesktopService.styleOf(root.row))
                    const parts = [theme ? Tr.t(theme.label) : "", style ? Tr.t(style.label) : ""]
                    const own = root.ownTheme !== "" || root.ownStyle !== ""
                    return parts.filter(part => part !== "").join(" · ")
                        + (own ? "" : ` · ${Tr.t("default")}`)
                }
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            // ── OPACITY ─────────────────────────────────────────────────────

            Item {
                visible: root.styled
                width: parent.width
                height: 40

                SliderRow {
                    anchors.left: parent.left
                    anchors.right: reset.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    height: 40
                    icon: "󰊸"
                    value: DesktopService.opacityOf(root.row)
                    from: 20
                    to: 100
                    onMoved: value => DesktopService.setOpacity(root.key, Math.round(value))
                }

                IconButton {
                    id: reset

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "󰦛"
                    iconSize: 13
                    enabled: root.ownOpacity
                    opacity: root.ownOpacity ? 1 : 0.3
                    onClicked: DesktopService.setOpacity(root.key, null)
                }
            }

        }
    }

    // ── PIECES ──────────────────────────────────────────────────────────────

    component Heading: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        font.weight: Font.DemiBold
        color: Theme.textMuted
    }

    // This strip with one thing changed, as a tile.
    component SpectrumTile: Rectangle {
        id: tile

        property bool current: false
        property string look: root.looks.look
        property string fillStyle: root.looks.fill

        signal chosen()

        width: 50
        height: 44
        radius: Theme.radiusSmall
        color: tile.current ? Theme.islandSurfaceHover : "transparent"
        border.color: tile.current ? Theme.accent : Theme.hairline
        border.width: 1

        SpectrumBars {
            anchors.fill: parent
            anchors.margins: 6
            sample: true
            style: tile.look
            fillStyle: tile.fillStyle
            color: root.looks.color
            color2: root.looks.color2
            barWidth: 4
            gap: 2
            floorLength: 1
            lowsAt: "along"
            peaks: root.looks.peaks
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: tile.chosen()
        }
    }

    // As the cursor's colour is chosen: Palette, the accent, which follows the
    // wallpaper, then the fixed colours.
    component ColourRow: Flow {
        id: colours

        property string field: "color"
        readonly property string chosen: colours.field === "color"
            ? root.looks.colorName : root.looks.color2Name

        function choose(value: string): void {
            DesktopService.setSpectrum(root.key, { [colours.field]: value })
        }

        width: parent.width
        spacing: 6

        // The palette's, ringed thicker as the cursor's is: it is the live
        // accent, not a colour.
        Rectangle {
            id: palette

            readonly property bool current: colours.chosen === "palette"

            width: paletteRow.implicitWidth + 20
            height: 26
            radius: height / 2
            color: "transparent"
            border.color: palette.current ? Theme.accent : Theme.hairline
            border.width: 1

            Row {
                id: paletteRow

                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: Theme.accent
                    border.color: Theme.accentText
                    border.width: 2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t("Palette")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: palette.current ? Theme.accent : Theme.text
                }
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: colours.choose("palette")
            }
        }

        Repeater {
            model: Theme.fixedColours

            Rectangle {
                id: swatch

                required property var modelData

                readonly property bool current: colours.chosen === swatch.modelData.id

                width: 26
                height: 26
                radius: 13
                color: swatch.modelData.id
                border.color: swatch.current ? Theme.accent : Theme.hairline
                border.width: swatch.current ? 2 : 1

                HoverHandler { cursorShape: Qt.PointingHandCursor }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: colours.choose(swatch.modelData.id)
                }
            }
        }
    }

    // One of the sizes, in pixels, beside its name.
    component Measure: Item {
        id: measure

        property string label: ""
        property string field: ""
        readonly property var range: DesktopService.spectrumRanges[measure.field]

        width: parent.width
        height: 30

        Text {
            id: name

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            text: measure.label
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            color: Theme.textMuted
        }

        SliderRow {
            anchors.left: name.right
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            value: root.looks[measure.field]
            from: measure.range.from
            to: measure.range.to
            unit: " px"
            onMoved: value => DesktopService.setSpectrum(root.key, { [measure.field]: value })
        }
    }
}
