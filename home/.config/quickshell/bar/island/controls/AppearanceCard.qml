// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A P P E A R A N C E   C A R D                                          │
// │   current wallpaper · opens the appearance panel                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Widgets

import "../../../theme"
import "../../../services"
import "../../../components"

// Shows the current wallpaper and opens the appearance panel.
// ClippingRectangle rather than `clip`, which is rectangular and would square
// the corners; `contentUnderBorder` keeps the outline over the picture.
ClippingRectangle {
    id: root

    signal requested()

    contentUnderBorder: true
    radius: Theme.radiusMedium
    color: Theme.surfaceIn(QsWindow.window)
    border.color: mouse.containsMouse ? Theme.accent : Theme.borderIn(QsWindow.window)
    border.width: 1

    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== ""
            ? `file://${WallpaperService.currentWallpaper}` : ""
        visible: source != "" && status === Image.Ready
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 560
        sourceSize.height: 320
        scale: mouse.containsMouse ? 1.04 : 1

        Behavior on scale {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }
    }

    // The label gets its own background, since it sits on a photograph.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 52
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.45; color: Theme.scrim }
            GradientStop { position: 1.0; color: Theme.island }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        spacing: 10

        ColorSwatch {
            Layout.alignment: Qt.AlignVCenter
            swatchSize: 11
            colors: ThemeService.activeId === "adaptive"
                ? ThemeService.adaptiveSwatches
                : (Palettes.byId(ThemeService.activeId)?.swatches ?? ThemeService.adaptiveSwatches)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: Tr.t("Appearance")
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.scrimText
            }

            Text {
                Layout.fillWidth: true
                text: Tr.t(Theme.activeName)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.scrimText
                opacity: 0.7
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "󰅂"
            font.family: Theme.fontMono
            font.pixelSize: 14
            color: mouse.containsMouse ? Theme.accent : Theme.scrimText
            opacity: mouse.containsMouse ? 1 : 0.7

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.requested()
    }
}
