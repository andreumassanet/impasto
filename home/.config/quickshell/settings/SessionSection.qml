// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E S S I O N   S E C T I O N                                          │
// │   session · account, lock screen and idle                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import "../theme"
import "../services"
import "../components"
import "../lock"

// The lock screen and the idle policy. The shell locks through
// ext-session-lock and shows the blurred desktop behind the lock. The blur
// slider previews over the wallpaper, since the lock's own capture of the
// screen only exists once locked.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    // One line on face unlock: what is missing, what is happening, or how
    // many faces there are.
    readonly property string faceReading: {
        if (!FaceService.known)
            return Tr.t("Checking…")
        if (!FaceService.camera)
            return ""
        if (!FaceService.installed)
            return Tr.t("Not set up")
        if (!FaceService.wired)
            return Tr.t("Half set up")
        if (FaceService.busy === "adding")
            return Tr.t("Adding a face…")
        if (FaceService.busy === "removing")
            return Tr.t("Removing…")
        switch (FaceService.outcome) {
        case "added": return Tr.t("Face added")
        case "no face": return Tr.t("No face seen — try with more light")
        case "several faces": return Tr.t("More than one face in view")
        case "too dark": return Tr.t("Too dark for the camera")
        case "failed": return Tr.t("The face was not added")
        }
        const count = FaceService.faces.length
        if (!FaceService.listed)
            return ""
        return count === 0 ? Tr.t("No face yet")
            : Tr.t(count === 1 ? "%1 face" : "%1 faces").arg(count)
    }

    FileDialog {
        id: picker

        title: Tr.t("Choose a picture")
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: {
            const url = String(picker.selectedFile)
            SettingsService.set("userAvatar",
                url.startsWith("file://") ? url.slice(7) : url)
        }
    }


    // ── LOCK SCREEN ─────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "lock"
        spacing: root.spacing

        onVisibleChanged: if (visible) FaceService.refresh()

        SettingGroup {
            title: Tr.t("You")
            note: Tr.t("Left empty, both come from your account, as on the login screen.")
            hint: Tr.t("The name defaults to the account's full name (set with chfn) and the picture to ~/.face or AccountsService. Click the picture or drop an image on the card to change it.")

            // Click the picture to choose a file, or drop an image on the row.
            Item {
                Layout.fillWidth: true
                implicitHeight: 72

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Theme.radiusMedium
                    color: Theme.islandSurfaceHover
                    border.color: Theme.accent
                    border.width: 1
                    visible: drop.containsDrag
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 16

                    Item {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignVCenter

                        Avatar {
                            anchors.fill: parent
                            source: AccountService.avatar
                            initials: AccountService.initials
                        }

                        // Camera overlay on hover.
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Theme.scrim
                            opacity: faceMouse.containsMouse ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.durationFast }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰄄"
                                font.family: Theme.fontMono
                                font.pixelSize: 16
                                color: Theme.scrimText
                            }
                        }

                        MouseArea {
                            id: faceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: picker.open()
                        }
                    }

                    // The chosen path, the account's avatar, or a prompt.
                    SettingLabel {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        label: Tr.t("Picture")
                        reading: {
                            if (SettingsService.userAvatar !== "")
                                return SettingsService.userAvatar
                            if (AccountService.systemAvatar !== "")
                                return `${AccountService.systemAvatar} ${Tr.t("— the account's own")}`
                            return Tr.t("Click it, or drop an image here")
                        }
                    }

                    PillButton {
                        Layout.alignment: Qt.AlignVCenter
                        text: Tr.t("Clear")
                        icon: "󰜉"
                        implicitWidth: 92
                        implicitHeight: 30
                        visible: SettingsService.userAvatar !== ""
                        onClicked: SettingsService.set("userAvatar", "")
                    }
                }

                DropArea {
                    id: drop

                    anchors.fill: parent
                    // Stored as a path, not a file:// URL.
                    onDropped: event => {
                        if (event.urls.length === 0)
                            return
                        const url = String(event.urls[0])
                        SettingsService.set("userAvatar",
                            url.startsWith("file://") ? url.slice(7) : url)
                    }
                }
            }

            SettingField {
                label: Tr.t("Name")
                placeholder: AccountService.systemName
                value: SettingsService.userName
                onEdited: text => SettingsService.set("userName", text)
            }
        }

        // Each tile is the lock's own clock, drawn small over the wallpaper.
        SettingGroup {
            title: Tr.t("Clock")
            note: Tr.t("The login screen always draws it stacked.")
            hint: Tr.t("The login screen runs before anyone has signed in, so it cannot read your settings.")

            SettingTiles {
                label: Tr.t("Style")

                Repeater {
                    model: [
                        { id: "stacked", label: "Stacked" },
                        { id: "inline", label: "Inline" }
                    ]

                    PreviewTile {
                        id: clockTile

                        required property var modelData

                        stageHeight: 120
                        caption: Tr.t(clockTile.modelData.label)
                        selected: SettingsService.lockClock === clockTile.modelData.id
                        onPicked: SettingsService.set("lockClock", clockTile.modelData.id)

                        Image {
                            id: clockGround

                            anchors.fill: parent
                            source: WallpaperService.currentWallpaper
                                ? `file://${WallpaperService.currentWallpaper}` : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                            asynchronous: true
                            sourceSize.width: 320
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: clockGround
                            visible: clockGround.status === Image.Ready
                            blurEnabled: true
                            blur: 1
                            blurMax: 16
                        }

                        LockClock {
                            anchors.centerIn: parent
                            style: clockTile.modelData.id
                            at: new Date(2026, 0, 1, 9, 41)
                            scale: clockTile.modelData.id === "stacked" ? 0.17 : 0.2
                        }
                    }
                }
            }
        }

        SettingGroup {
            title: Tr.t("Background")
            note: Tr.t("Just enough to make the text underneath unreadable.")
            hint: Tr.t("The preview uses the wallpaper, since the lock screen's own capture is taken when it locks. It applies the same blur with the capsule on top, so you can judge how it reads.")

            SettingSlider {
                label: Tr.t("Blur")
                value: SettingsService.lockBlur
                from: 8
                to: 64
                unit: " px"
                onMoved: value => SettingsService.set("lockBlur", Math.round(value))
            }

            SettingBlock {
                ClippingRectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    radius: Theme.radiusSmall
                    color: Theme.island
                    border.color: Theme.islandBorder
                    border.width: 1
                    contentUnderBorder: true

                    Image {
                        id: sample

                        anchors.fill: parent
                        source: WallpaperService.currentWallpaper
                            ? `file://${WallpaperService.currentWallpaper}` : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                        asynchronous: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: sample
                        visible: sample.status === Image.Ready
                        blurEnabled: true
                        blur: 1
                        blurMax: SettingsService.lockBlur
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: sample.status !== Image.Ready
                        text: Tr.t("No wallpaper to show")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }

                    // A capsule on top, to judge legibility at this blur.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: 196
                        height: 38
                        radius: height / 2
                        color: Theme.island

                        Text {
                            anchors.centerIn: parent
                            text: Tr.t("Type to unlock")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }

        // Face unlock: what the machine has, the faces howdy keeps, and trying
        // one the way the lock does. Everything that needs root goes through
        // FaceService's helper, which asks for the password itself.
        SettingGroup {
            title: Tr.t("Face unlock")
            note: Tr.t("The lock screen only, with the infrared camera.")
            hint: Tr.t("howdy keeps the faces where only root can read them, so adding or removing one asks for your password. The login screen, sudo and polkit still ask for the password.")

            SettingRow {
                label: Tr.t("Face unlock")
                reading: root.faceReading
                alarm: FaceService.outcome !== "" && FaceService.outcome !== "added"
                locked: FaceService.known && !FaceService.camera
                reason: Tr.t("Needs an infrared camera")

                PillButton {
                    visible: FaceService.known && FaceService.camera
                    text: !FaceService.installed ? Tr.t("Set up")
                        : !FaceService.wired ? Tr.t("Finish setting up")
                        : Tr.t("Add a face")
                    icon: "󰄀"
                    active: true
                    enabled: FaceService.busy === "" && !FaceService.installer.running
                    implicitWidth: 136
                    implicitHeight: 30
                    onClicked: {
                        if (!FaceService.installed)
                            FaceService.install("face")
                        else if (!FaceService.wired)
                            FaceService.install("system")
                        else
                            FaceService.add()
                    }
                }
            }

            // The scan, the lock's own ring. The password dialog comes first,
            // and the camera only once it is answered.
            SettingBlock {
                visible: FaceService.busy === "adding"

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 176

                    FaceRing {
                        id: scanRing

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        diameter: 108
                        scanning: FaceService.busy === "adding"
                        shown: 1
                    }

                    Padlock {
                        anchors.centerIn: scanRing
                        scale: 1.5
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: Tr.t("Confirm with your password, then look at the camera")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.text
                    }
                }
            }

            SettingBlock {
                visible: FaceService.ready && FaceService.faces.length > 0
                    && FaceService.busy !== "adding"

                Text {
                    text: Tr.t("FACES")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                    color: Theme.textMuted
                }

                Repeater {
                    model: ScriptModel {
                        values: FaceService.faces
                        objectProp: "id"
                    }

                    RowLayout {
                        id: kept

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "󰄀"
                            font.family: Theme.fontMono
                            font.pixelSize: 14
                            color: Theme.accent
                        }

                        // howdy names an unlabelled model "Model #n"; the
                        // page counts them instead.
                        Text {
                            Layout.fillWidth: true
                            text: /^Model #\d+$/.test(kept.modelData.label)
                                ? Tr.t("Face %1").arg(kept.index + 1) : kept.modelData.label
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                        }

                        Text {
                            text: Qt.formatDate(new Date(kept.modelData.added.replace(" ", "T")), "d MMM yyyy")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }

                        PillButton {
                            text: Tr.t("Remove")
                            enabled: FaceService.busy === ""
                            implicitHeight: 26
                            onClicked: FaceService.remove(kept.modelData.id)
                        }
                    }
                }
            }

            // The lock's own conversation, so a match here is a match there.
            SettingRow {
                visible: FaceService.ready && FaceService.faces.length > 0
                    && FaceService.busy !== "adding"
                label: Tr.t("Try it")
                reading: FaceService.trial === "looking" ? Tr.t("Looking…")
                    : FaceService.trial === "matched" ? Tr.t("Recognised")
                    : FaceService.trial === "missed" ? Tr.t("Not recognised") : ""
                alarm: FaceService.trial === "missed"

                PillButton {
                    text: Tr.t("Try")
                    icon: "󰄄"
                    enabled: FaceService.trial !== "looking" && FaceService.busy === ""
                    implicitWidth: 112
                    implicitHeight: 30
                    onClicked: FaceService.tryFace()
                }
            }
        }
    }


    // ── WHEN YOU LEAVE ──────────────────────────────────────────────────────

    SettingGroup {
        visible: root.tab === "idle"
        title: Tr.t("When you leave it alone")
        note: Tr.t("All three are off by default.")
        hint: Tr.t("The shell uses the compositor's idle notifications, and media that inhibits idle (mpv, browsers) holds all three off. Set screen off after the lock, since the lock captures the screen as it starts; suspend always locks first and is skipped if the lock does not come up.")

        SettingSlider {
            label: Tr.t("Lock after")
            value: SettingsService.idleLock
            from: 0
            to: 60
            unit: " min"
            reading: SettingsService.idleLock === 0
                ? Tr.t("Never") : `${SettingsService.idleLock} min`
            onMoved: value => SettingsService.set("idleLock", Math.round(value))
        }

        // Warns when the screen would turn off before the lock: the lock
        // captures the desktop as it goes up and cannot capture a screen that
        // is already off.
        SettingSlider {
            label: Tr.t("Screen off after")
            value: SettingsService.idleScreen
            from: 0
            to: 60
            unit: " min"
            reading: {
                if (SettingsService.idleScreen === 0)
                    return Tr.t("Never")
                if (SettingsService.idleLock === 0
                        || SettingsService.idleScreen >= SettingsService.idleLock)
                    return `${SettingsService.idleScreen} min`
                return `${SettingsService.idleScreen} min · ${Tr.t("before the lock")}`
            }
            onMoved: value => SettingsService.set("idleScreen", Math.round(value))
        }

        SettingSlider {
            label: Tr.t("Suspend after")
            value: SettingsService.idleSuspend
            from: 0
            to: 60
            unit: " min"
            reading: SettingsService.idleSuspend === 0
                ? Tr.t("Never") : `${SettingsService.idleSuspend} min`
            onMoved: value => SettingsService.set("idleSuspend", Math.round(value))
        }
    }
}
