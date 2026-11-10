// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A P P E A R A N C E   P A N E L                                        │
// │   favourite, wallpaper and palette picker                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtMultimedia
import Quickshell
import QtQuick.Layouts
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"

// The favourites, the wallpapers and the palettes, each as a strip
// (`Carousel`): the tile in the middle large, its neighbours stepping away.
// Left and Right slide, Enter applies. The wallpapers are the collection as
// it is on disk, pictures and videos together: a folder is a tile too, Enter
// opens it, and its first tile, or Backspace, goes back up. A video is marked
// and plays in the middle. A marks a wallpaper as a favourite, and the
// favourites are the page above. Up and Down move between the three pages,
// the second shortcut opens on the palettes, and the chevrons in the footer
// do it with the pointer.
//
// The wallpaper directories are rescanned whenever the panel opens, so there
// is no refresh button.
FocusScope {
    id: root

    signal closed()
    signal panelRequested(string panel)

    // `wallpaper` or `palette`: the name the panel was opened under, so the
    // shortcut slides a panel that is already open. `shown` is the page on
    // screen, which can also be `favourites`, a page with no name of its own.
    property string page: "wallpaper"
    property string shown: root.page
    onPageChanged: root.shown = root.page

    readonly property var pages: ["favourites", "wallpaper", "palette"]
    readonly property int shownIndex: root.pages.indexOf(root.shown)
    readonly property bool onPalette: root.shown === "palette"
    readonly property bool onFavourites: root.shown === "favourites"

    readonly property int gap: 12
    readonly property int tileWidth: 160
    readonly property int tileHeight: 100
    readonly property real centreScale: 1.25
    readonly property int daub: 12
    readonly property int loadReach: 8

    readonly property Carousel strip:
        root.onPalette ? palettes : root.onFavourites ? favourites : wallpapers

    // The folder the wallpapers strip is in, "" at the top. Until the person
    // moves, it opens in the folder of what is applied.
    property string folder: ""
    property bool browsed: false
    readonly property var wallView: WallpaperService.viewOf(WallpaperService.collection, root.folder)
    readonly property var favView: WallpaperService.favourites

    readonly property var centredWallpaper: root.wallView[wallpapers.current] ?? null
    readonly property var centredFavourite: root.favView[favourites.current] ?? null
    readonly property var centredPalette: ThemeService.availableThemes[palettes.current] ?? null

    Component.onCompleted: {
        WallpaperService.scan()
        root.forceActiveFocus()
    }

    // Initial values for the strips' `current`, so they open on what is
    // applied instead of sliding there from the first tile. `settle` follows
    // the list when the scan returns a moment after opening.
    readonly property int appliedWallpaper: root.firstIn(root.wallView)
    readonly property int appliedFavourite: root.firstIn(root.favView)
    readonly property int activePalette: Math.max(0, ThemeService.availableThemes.findIndex(
        entry => entry.id === ThemeService.activeId))

    // What is applied, or past the tile back up.
    function firstIn(view: var): int {
        const applied = view.findIndex(entry => entry.path === WallpaperService.chosen)
        return applied >= 0 ? applied : (view.length > 1 && view[0].kind === "up" ? 1 : 0)
    }

    function settle(): void {
        if (!root.browsed)
            root.folder = WallpaperService.folderOfChosen(WallpaperService.collection)
        wallpapers.goTo(root.appliedWallpaper)
        favourites.goTo(root.appliedFavourite)
        palettes.goTo(root.activePalette)
    }

    Connections {
        target: WallpaperService
        function onCollectionChanged(): void { root.settle() }
        function onChosenChanged(): void { root.settle() }
    }

    function apply(): void {
        if (root.onPalette) {
            if (root.centredPalette)
                ThemeService.setTheme(root.centredPalette.id)
            return
        }
        const entry = root.onFavourites ? root.centredFavourite : root.centredWallpaper
        if (!entry)
            return
        if (entry.kind === "folder" || entry.kind === "up")
            root.browse(entry.folder)
        else
            WallpaperService.apply(entry.path)
    }

    // A, on a picture or a video: into the favourites, or out of them.
    function favour(): void {
        const entry = root.onFavourites ? root.centredFavourite
            : root.onPalette ? null : root.centredWallpaper
        if (entry && entry.path && !entry.kind)
            WallpaperService.toggleFavourite(entry.path)
    }

    // A folder tile is marked while what is applied is somewhere inside it.
    function holdsChosen(entry: var): bool {
        if (entry.kind !== "folder")
            return false
        const list = WallpaperService.collection
        if (!list.some(candidate => candidate.path === WallpaperService.chosen))
            return false
        const own = WallpaperService.folderOfChosen(list)
        return own === entry.folder || own.startsWith(`${entry.folder}/`)
    }

    // What the footer names: the centred tile, after the folder it is in.
    function labelOf(entry: var, folder: string): string {
        if (!entry)
            return ""
        const name = entry.kind === "up" ? Tr.t("Back")
            : entry.kind === "folder" ? `${entry.name} · ${Tr.t("%1 inside").arg(entry.count)}`
            : entry.name
        return folder === "" ? name : `${folder.split("/").join(" / ")}  ·  ${name}`
    }

    // Into a folder, or back up out of one: going up lands on the folder
    // just left.
    function browse(folder: string): void {
        root.browsed = true
        const left = root.folder
        root.folder = folder
        const back = root.wallView.findIndex(entry => entry.kind === "folder" && entry.folder === left)
        wallpapers.goTo(back >= 0 ? back : root.firstIn(root.wallView))
    }

    function leave(): void {
        if (root.shown === "wallpaper" && root.folder !== "")
            root.browse(WallpaperService.parentOf(root.folder))
    }

    // The page `delta` away, up or down. The two named pages go through the
    // island, so its name follows; the favourites are this panel's own.
    function turn(delta: int): void {
        const index = root.shownIndex + delta
        if (index < 0 || index >= root.pages.length)
            return
        root.shown = root.pages[index]
        if (root.shown !== "favourites")
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
        else if (event.key === Qt.Key_Backspace)
            root.leave()
        else if (event.key === Qt.Key_A)
            root.favour()
        else
            return
        event.accepted = true
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
                id: favourites

                width: pages.width
                height: pages.height
                y: (0 - root.shownIndex) * pages.height
                opacity: root.onFavourites ? 1 : 0
                current: root.appliedFavourite
                model: root.favView
                tileWidth: root.tileWidth
                tileHeight: root.tileHeight
                centreScale: root.centreScale
                gap: root.gap
                onActivated: root.apply()

                Behavior on y { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
                Behavior on opacity { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

                delegate: WallTile {}
            }

            // With no favourites yet, how to keep one.
            Text {
                x: (pages.width - width) / 2
                y: favourites.y + (pages.height - height) / 2
                width: pages.width - 4 * root.gap
                visible: root.favView.length === 0
                opacity: favourites.opacity
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Tr.t("No favourites yet. Press A on a wallpaper to keep it here.")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            Carousel {
                id: wallpapers

                width: pages.width
                height: pages.height
                y: (1 - root.shownIndex) * pages.height
                opacity: root.shownIndex === 1 ? 1 : 0
                current: root.appliedWallpaper
                model: root.wallView
                tileWidth: root.tileWidth
                tileHeight: root.tileHeight
                centreScale: root.centreScale
                gap: root.gap
                onActivated: root.apply()

                Behavior on y { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
                Behavior on opacity { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

                delegate: WallTile {}
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
                                text: Tr.t(card.modelData.name)
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

            Text {
                Layout.fillWidth: true
                text: root.onPalette ? Tr.t(root.centredPalette?.badge ?? "")
                    : root.onFavourites ? root.labelOf(root.centredFavourite, "")
                    : root.labelOf(root.centredWallpaper, root.folder)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            // Position in the strip; the tile's mark already shows what is
            // applied.
            Text {
                text: root.strip.count === 0
                    ? (WallpaperService.scanning ? Tr.t("Scanning…") : "")
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

    // One tile of the collection: a picture, a video's poster with a mark,
    // playing while it is in the middle, a folder, or the way back up. Only
    // tiles near the middle load a picture: decoding every wallpaper on open
    // leaves the visible ones black for over a second. Qt caches decoded
    // images, so stepping back does not read them again.
    component WallTile: CarouselTile {
        id: tile

        readonly property bool video: (tile.modelData.poster ?? "") !== "" && !tile.modelData.kind
        readonly property bool applied: tile.modelData.path === WallpaperService.chosen
            || root.holdsChosen(tile.modelData)
        readonly property bool favourite: WallpaperService.isFavourite(tile.modelData.path ?? "")

        ClippingRectangle {
            anchors.fill: parent
            contentUnderBorder: true
            radius: Theme.radiusMedium
            color: Theme.surfaceIn(QsWindow.window)
            border.color: tile.centred ? Theme.accent : Theme.borderIn(QsWindow.window)
            border.width: tile.centred ? 2 : 1

            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            Image {
                anchors.fill: parent
                visible: tile.modelData.kind !== "up"
                source: Math.abs(tile.distance) <= root.loadReach && tile.modelData.kind !== "up"
                    ? `file://${tile.modelData.kind === "folder" ? tile.modelData.picture
                        : tile.video ? tile.modelData.poster : tile.modelData.path}` : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 320
                sourceSize.height: 200
            }

            // The video itself, muted, only in the middle of the strip shown.
            Loader {
                anchors.fill: parent
                active: tile.video && tile.centred && tile.strip.opacity === 1
                sourceComponent: Video {
                    source: `file://${tile.modelData.path}`
                    autoPlay: true
                    loops: MediaPlayer.Infinite
                    muted: true
                    fillMode: VideoOutput.PreserveAspectCrop
                }
            }

            FolderFace { entry: tile.modelData }

            // A video's mark and a favourite's, bottom left.
            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 6
                spacing: 4

                Badge { visible: tile.video; glyph: "󰐊" }
                Badge { visible: tile.favourite; glyph: "󰓎" }
            }

            AppliedMark { visible: tile.applied }
        }
    }

    component Badge: Rectangle {
        property string glyph: ""

        width: 18
        height: 18
        radius: width / 2
        color: Theme.scrim

        Text {
            anchors.centerIn: parent
            text: parent.glyph
            font.family: Theme.fontMono
            font.pixelSize: 10
            color: Theme.text
        }
    }

    // A folder's tile over the first picture inside it, darkened, with its
    // name; the tile back up is an arrow on the plain ground.
    component FolderFace: Item {
        id: face

        property var entry: ({})

        anchors.fill: parent
        visible: face.entry.kind === "folder" || face.entry.kind === "up"

        Rectangle {
            anchors.fill: parent
            visible: face.entry.kind === "folder"
            color: Theme.scrim
            opacity: 0.55
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.entry.kind === "up" ? "󰁝" : "󰉋"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeWidget
                color: face.entry.kind === "up" ? Theme.textMuted : Theme.text
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: face.entry.kind === "folder"
                width: Math.min(implicitWidth, face.width - 16)
                elide: Text.ElideRight
                text: face.entry.name ?? ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                font.weight: Font.DemiBold
                color: Theme.text
            }
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
