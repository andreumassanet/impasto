// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A P P E A R A N C E   P A N E L                                        │
// │   animated wallpaper, wallpaper and palette picker                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// The animated wallpapers, the wallpapers and the palettes, each as a strip
// (`Carousel`): the tile in the middle large, its neighbours stepping away.
// Left and Right slide, Enter applies. Three pages top to bottom: Up and Down
// move between them, the second shortcut opens on the palettes, and the
// chevrons in the footer do it with the pointer.
//
// The wallpaper directories are rescanned whenever the panel opens, so there
// is no refresh button.
FocusScope {
    id: root

    signal closed()
    signal panelRequested(string panel)

    // `wallpaper` or `palette`: the name the panel was opened under, so the
    // shortcut slides a panel that is already open. `shown` is the page on
    // screen, which can also be `animated`, a page with no name of its own.
    property string page: "wallpaper"
    property string shown: root.page
    onPageChanged: root.shown = root.page

    readonly property var pages: ["animated", "wallpaper", "palette"]
    readonly property int shownIndex: root.pages.indexOf(root.shown)
    readonly property bool onPalette: root.shown === "palette"
    readonly property bool onAnimated: root.shown === "animated"

    readonly property int gap: 12
    readonly property int tileWidth: 160
    readonly property int tileHeight: 100
    readonly property real centreScale: 1.25
    readonly property int daub: 12
    readonly property int loadReach: 8

    readonly property Carousel strip:
        root.onPalette ? palettes : root.onAnimated ? animations : wallpapers

    // The search narrows the strips (fuzzy, best match first).
    property string query: ""
    readonly property var shownWallpapers: root.matching(WallpaperService.wallpapers)
    readonly property var shownAnimated: root.matching(WallpaperService.animated)

    readonly property var centredWallpaper: root.shownWallpapers[wallpapers.current] ?? null
    readonly property var centredAnimation: root.shownAnimated[animations.current] ?? null
    readonly property var centredPalette: ThemeService.availableThemes[palettes.current] ?? null

    Component.onCompleted: {
        WallpaperService.scan()
        root.forceActiveFocus()
    }

    // Initial values for the strips' `current`, so they open on what is
    // applied instead of sliding there from the first tile. `settle` follows
    // the list when the scan returns a moment after opening.
    readonly property int appliedWallpaper: Math.max(0, root.shownWallpapers.findIndex(
        entry => entry.path === WallpaperService.chosen))
    readonly property int appliedAnimation: Math.max(0, root.shownAnimated.findIndex(
        entry => entry.path === WallpaperService.chosen))
    readonly property int activePalette: Math.max(0, ThemeService.availableThemes.findIndex(
        entry => entry.id === ThemeService.activeId))

    function settle(): void {
        wallpapers.goTo(root.appliedWallpaper)
        animations.goTo(root.appliedAnimation)
        palettes.goTo(root.activePalette)
    }

    Connections {
        target: WallpaperService
        function onWallpapersChanged(): void { root.settle() }
        function onAnimatedChanged(): void { root.settle() }
        function onChosenChanged(): void { root.settle() }
    }

    function apply(): void {
        if (root.onPalette) {
            if (root.centredPalette)
                ThemeService.setTheme(root.centredPalette.id)
        } else if (root.onAnimated) {
            if (root.centredAnimation)
                WallpaperService.apply(root.centredAnimation.path)
        } else if (root.centredWallpaper) {
            WallpaperService.apply(root.centredWallpaper.path)
        }
    }

    // The page `delta` away, up or down. The two named pages go through the
    // island, so its name follows; the animated one is this panel's own.
    function turn(delta: int): void {
        const index = root.shownIndex + delta
        if (index < 0 || index >= root.pages.length)
            return
        root.shown = root.pages[index]
        if (root.shown !== "animated")
            root.panelRequested(root.shown === "palette" ? "palette" : "appearance")
    }

    // Five daubs, in the board's order: the accent and the four status hues.
    // The adaptive entry shows the current theme until the wallpaper has been
    // read.
    function daubsOf(theme: var): var {
        const colors = theme.adaptive ? ThemeService.dynamicColors : theme.colors
        return colors
            ? [colors.accent, colors.green, colors.yellow, colors.red, colors.blue]
            : [Theme.accent, Theme.green, Theme.yellow, Theme.red, Theme.blue]
    }

    Keys.onLeftPressed: root.strip.step(-1)
    Keys.onRightPressed: root.strip.step(1)
    Keys.onDownPressed: root.turn(1)
    Keys.onUpPressed: root.turn(-1)
    Keys.onReturnPressed: root.apply()
    Keys.onEnterPressed: root.apply()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home)
            root.strip.goTo(0)
        else if (event.key === Qt.Key_End)
            root.strip.goTo(root.strip.count - 1)
        else if (event.key === Qt.Key_PageUp)
            root.strip.step(-5)
        else if (event.key === Qt.Key_PageDown)
            root.strip.step(5)
        // Typing searches the strip by name.
        else if (event.text.length === 1 && event.text.trim() !== "" && !root.onPalette) {
            search.text += event.text
            search.forceActiveFocus()
        } else
            return
        event.accepted = true
    }

    // Fuzzy matching, as a launcher does. Every character of the
    // query must appear in the name in order; runs of adjacent characters,
    // matches at a word's start and a match early in the name score higher.
    // -1 when it does not match.
    function fuzzyScore(name: string, query: string): int {
        const haystack = name.toLowerCase()
        const needle = query.toLowerCase().replace(/\s+/g, "")
        let score = 0
        let from = 0
        let previous = -2
        for (const character of needle) {
            const found = haystack.indexOf(character, from)
            if (found < 0)
                return -1
            score += found === previous + 1 ? 8 : 1
            if (found === 0 || /[\s\-_.]/.test(haystack[found - 1]))
                score += 4
            previous = found
            from = found + 1
        }
        return score * 100 - haystack.indexOf(needle[0] ?? "")
    }

    function matching(entries: var): var {
        if (root.query.trim() === "")
            return entries
        return entries
            .map(entry => ({ entry: entry, score: root.fuzzyScore(String(entry.name ?? ""), root.query) }))
            .filter(scored => scored.score >= 0)
            .sort((first, second) => second.score - first.score)
            .map(scored => scored.entry)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.gap

        // ── STRIPS ──────────────────────────────────────────────────────────

        // All three live here, each parked a strip's height per page away
        // from the one shown, so turning the page slides them past each other.
        Item {
            id: pages

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Carousel {
                id: wallpapers

                width: pages.width
                height: pages.height
                y: (1 - root.shownIndex) * pages.height
                opacity: root.shownIndex === 1 ? 1 : 0
                current: root.appliedWallpaper
                model: root.shownWallpapers
                tileWidth: root.tileWidth
                tileHeight: root.tileHeight
                centreScale: root.centreScale
                gap: root.gap
                onActivated: root.apply()

                Behavior on y { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
                Behavior on opacity { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

                delegate: CarouselTile {
                    id: tile

                    readonly property bool applied:
                        tile.modelData.path === WallpaperService.chosen

                    ClippingRectangle {
                        anchors.fill: parent
                        contentUnderBorder: true
                        radius: Theme.radiusMedium
                        color: Theme.surfaceIn(QsWindow.window)
                        border.color: tile.centred ? Theme.accent : Theme.borderIn(QsWindow.window)
                        border.width: tile.centred ? 2 : 1

                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        // Only tiles near the middle load a picture: decoding
                        // every wallpaper on open leaves the visible ones
                        // black for over a second. Qt caches decoded images,
                        // so stepping back does not read them again.
                        Image {
                            anchors.fill: parent
                            source: Math.abs(tile.distance) <= root.loadReach
                                ? `file://${tile.modelData.path}` : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 320
                            sourceSize.height: 200
                        }

                        AppliedMark { visible: tile.applied }
                    }
                }
            }

            Carousel {
                id: animations

                width: pages.width
                height: pages.height
                y: (0 - root.shownIndex) * pages.height
                opacity: root.onAnimated ? 1 : 0
                current: root.appliedAnimation
                model: root.shownAnimated
                tileWidth: root.tileWidth
                tileHeight: root.tileHeight
                centreScale: root.centreScale
                gap: root.gap
                onActivated: root.apply()

                Behavior on y { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
                Behavior on opacity { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

                // Each tile is the video's poster, the frame it starts from.
                delegate: CarouselTile {
                    id: clip

                    readonly property bool applied:
                        clip.modelData.path === WallpaperService.chosen

                    ClippingRectangle {
                        anchors.fill: parent
                        contentUnderBorder: true
                        radius: Theme.radiusMedium
                        color: Theme.surfaceIn(QsWindow.window)
                        border.color: clip.centred ? Theme.accent : Theme.borderIn(QsWindow.window)
                        border.width: clip.centred ? 2 : 1

                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        Image {
                            anchors.fill: parent
                            source: Math.abs(clip.distance) <= root.loadReach
                                ? `file://${clip.modelData.poster}` : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 320
                            sourceSize.height: 200
                        }

                        AppliedMark { visible: clip.applied }
                    }
                }
            }

            // With no videos yet, where to put them.
            Text {
                x: (pages.width - width) / 2
                y: animations.y + (pages.height - height) / 2
                width: pages.width - 4 * root.gap
                visible: root.shownAnimated.length === 0
                opacity: animations.opacity
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Tr.t("No animated wallpapers yet. Videos in ~/.local/share/wallpapers/animated show up here.")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            Carousel {
                id: palettes

                width: pages.width
                height: pages.height
                y: (2 - root.shownIndex) * pages.height
                opacity: root.onPalette ? 1 : 0
                current: root.activePalette
                model: ThemeService.availableThemes
                tileWidth: root.tileWidth
                tileHeight: root.tileHeight
                centreScale: root.centreScale
                gap: root.gap
                onActivated: root.apply()

                Behavior on y { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
                Behavior on opacity { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

                delegate: CarouselTile {
                    id: card

                    readonly property bool applied: card.modelData.id === ThemeService.activeId

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusMedium
                        color: card.hovered ? Theme.surfaceHoverIn(QsWindow.window) : Theme.surfaceIn(QsWindow.window)
                        border.color: card.centred ? Theme.accent : Theme.borderIn(QsWindow.window)
                        border.width: card.centred ? 2 : 1

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6

                                Repeater {
                                    model: root.daubsOf(card.modelData)

                                    Rectangle {
                                        required property var modelData

                                        width: root.daub
                                        height: root.daub
                                        radius: width / 2
                                        color: modelData
                                        border.color: Theme.hairline
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: Theme.paletteTransition } }
                                    }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: card.modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: card.centred ? Font.DemiBold : Font.Normal
                                color: card.centred ? Theme.text : Theme.textMuted
                            }
                        }

                        AppliedMark { visible: card.applied }
                    }
                }
            }
        }

        // ── FOOTER ──────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: root.gap

            // The search, a pill on the wallpaper pages. Its
            // placeholder is the centred entry's name.
            Rectangle {
                visible: !root.onPalette
                Layout.preferredWidth: 300
                Layout.preferredHeight: 28
                radius: height / 2
                color: Theme.islandSurface
                border.color: search.activeFocus ? Theme.accent : "transparent"
                border.width: 1

                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                TextInput {
                    id: search

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 32
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                    selectionColor: Theme.accent
                    // The best match comes first; an empty query goes back to
                    // what is applied.
                    onTextChanged: {
                        root.query = search.text
                        if (search.text.trim() === "")
                            root.settle()
                        else
                            root.strip.goTo(0)
                    }
                    Keys.onLeftPressed: root.strip.step(-1)
                    Keys.onRightPressed: root.strip.step(1)
                    Keys.onReturnPressed: root.apply()
                    Keys.onEnterPressed: root.apply()
                    Keys.onEscapePressed: event => {
                        if (search.text === "") {
                            event.accepted = false
                            return
                        }
                        search.text = ""
                        root.forceActiveFocus()
                    }

                    Text {
                        anchors.fill: parent
                        visible: search.text === ""
                        text: root.onAnimated ? (root.centredAnimation?.name ?? "") : (root.centredWallpaper?.name ?? "")
                        elide: Text.ElideRight
                        font: search.font
                        color: Theme.textMuted
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.onPalette ? (root.centredPalette?.badge ?? "") : ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            // Position in the strip; the tile's mark already shows what is
            // applied.
            Text {
                text: root.strip.count === 0
                    ? (WallpaperService.scanning ? "Scanning…" : root.query !== "" ? "No match" : "")
                    : `${root.strip.current + 1}/${root.strip.count}`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            // Switch pages with the pointer: up, and down, where there is one.
            Door {
                glyph: "󰅃"
                visible: root.shownIndex > 0
                onClicked: root.turn(-1)
            }

            Door {
                glyph: "󰅀"
                visible: root.shownIndex < root.pages.length - 1
                onClicked: root.turn(1)
            }
        }
    }

    component Door: Text {
        id: door

        property string glyph: ""
        signal clicked()

        text: door.glyph
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeRegular
        color: doorMouse.containsMouse ? Theme.text : Theme.textMuted

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        MouseArea {
            id: doorMouse

            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: door.clicked()
        }
    }

    // The check on what is applied, distinct from the accent ring, which
    // marks the position in the strip.
    component AppliedMark: Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        width: 18
        height: 18
        radius: width / 2
        color: Theme.accent

        Text {
            anchors.centerIn: parent
            text: "󰄬"
            font.family: Theme.fontMono
            font.pixelSize: 10
            color: Theme.accentText
        }
    }
}
