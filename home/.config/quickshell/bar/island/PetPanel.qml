// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   P A N E L                                                      │
// │   pet panel · the active pet and the family                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The pet: the creature that is out (feed, play, name it) and, below, the
// family, where the one that is out is swapped.
ColumnLayout {
    id: root

    signal closed()

    spacing: 14

    Component.onCompleted: PetService.subscribe()
    Component.onDestruction: PetService.release()

    // ── CURRENT ─────────────────────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        spacing: 18

        Item {
            Layout.preferredWidth: 84
            Layout.preferredHeight: 84
            Layout.alignment: Qt.AlignVCenter

            PetFace {
                id: face

                anchors.centerIn: parent
                size: 76
                lively: true

                // An idle bob, and a hop when played with that pauses the bob
                // for its duration. Same as the module's detail.
                SequentialAnimation {
                    running: !hop.running && PetService.mood !== "asleep"
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: face; property: "anchors.verticalCenterOffset"
                        to: -3; duration: 1400; easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: face; property: "anchors.verticalCenterOffset"
                        to: 0; duration: 1400; easing.type: Easing.InOutSine
                    }
                }

                SequentialAnimation {
                    id: hop

                    NumberAnimation {
                        target: face; property: "anchors.verticalCenterOffset"
                        to: -12; duration: 130; easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: face; property: "anchors.verticalCenterOffset"
                        to: 0; duration: 190; easing.type: Easing.OutBounce
                    }
                }

                Connections {
                    target: PetService
                    function onPlayed(): void { hop.restart() }
                    function onCelebrated(level: int): void { hop.restart() }
                    function onBrought(index: int): void { hop.restart() }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // The name is edited in place. An egg has none and says so.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 24

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !PetService.hatched
                        text: Tr.t("Egg")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    TextInput {
                        id: named

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PetService.hatched
                        text: PetService.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        color: Theme.text
                        selectByMouse: true
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        clip: true

                        onTextEdited: PetService.rename(named.text)
                        Keys.onEscapePressed: {
                            named.text = ""
                            PetService.rename("")
                        }

                        // Unnamed, the species as a greyed placeholder.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: named.text === ""
                            text: PetService.speciesInfo.label
                            font: named.font
                            color: Theme.textMuted
                        }
                    }
                }

                Text {
                    visible: PetService.hatched
                    text: Tr.t("Lv %1").arg(PetService.level)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }

            Text {
                Layout.fillWidth: true
                text: PetService.moodLine
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                UsageBar {
                    Layout.fillWidth: true
                    progress: PetService.progress
                    fillColor: face.coat
                }

                Text {
                    text: `${PetService.xp}/${PetService.threshold}`
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            PillButton {
                Layout.fillWidth: true
                implicitWidth: 88
                text: Tr.t(PetService.canFeed ? "Feed" : "Fed")
                enabled: PetService.canFeed
                onClicked: PetService.feed()
            }

            PillButton {
                Layout.fillWidth: true
                implicitWidth: 88
                text: Tr.t(PetService.canPlay ? "Play" : "Played")
                enabled: PetService.canPlay
                onClicked: PetService.play()
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.hairline
    }

    // ── FAMILY ──────────────────────────────────────────────────────────────

    PetFamily {
        Layout.fillWidth: true
    }

    Item { Layout.fillHeight: true }
}
