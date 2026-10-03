// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   M O D U L E                                                    │
// │   pet · the active pet, the shelf when open                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The module around `PetFace`: the chip, and the detail where the pet is fed,
// played with and swapped. The ring is progress to the next level, white
// because it warns about nothing. The shelf has one slot per species; clicking
// a sleeping pet brings it out.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: PetService.subscribe()
    Component.onDestruction: PetService.release()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    Component {
        id: chip

        Item {
            Item {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight

                RingIndicator {
                    anchors.fill: parent
                    thickness: 2.5
                    progress: PetService.progress
                    trackColor: Theme.indicatorDim
                    fillColor: Theme.indicator

                    PetFace {
                        anchors.centerIn: parent
                        size: Math.round(Theme.capsuleHeight * 0.56)
                        lively: true
                    }
                }
            }
        }
    }

    // The pet is the mark and its level the figure; then progress to the
    // next level, feeding and play, and the shelf.
    Component {
        id: detail

        ModuleCard {
            // Hatched pets show their name, then their species.
            title: PetService.titleOf(PetService.pet)
            subtitle: PetService.moodLine
            figure: PetService.hatched ? `Lv ${PetService.level}` : ""

            mark: Item {
                anchors.fill: parent

                PetFace {
                    id: bigFace

                    anchors.centerIn: parent
                    size: Theme.cardMark
                    lively: true

                    // Idle bob; a hop pauses it for its own length.
                    SequentialAnimation {
                        id: bob
                        running: !hop.running && PetService.mood !== "asleep" && Theme.lively
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: bigFace; property: "anchors.verticalCenterOffset"
                            to: -2; duration: 1400; easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: bigFace; property: "anchors.verticalCenterOffset"
                            to: 0; duration: 1400; easing.type: Easing.InOutSine
                        }
                    }

                    SequentialAnimation {
                        id: hop

                        NumberAnimation {
                            target: bigFace; property: "anchors.verticalCenterOffset"
                            to: -10; duration: 130; easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: bigFace; property: "anchors.verticalCenterOffset"
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

            CardLimit {
                name: "Next level"
                fraction: PetService.progress
                tint: bigFace.coat
                note: `${PetService.xp}/${PetService.threshold}`
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.cardRow
                spacing: 9

                PillButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    implicitHeight: Theme.cardRow
                    text: PetService.canFeed ? "Feed" : "Fed"
                    enabled: PetService.canFeed
                    onClicked: PetService.feed()
                }

                PillButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    implicitHeight: Theme.cardRow
                    text: PetService.canPlay ? "Play" : "Played"
                    enabled: PetService.canPlay
                    onClicked: PetService.play()
                }
            }

            // ── SHELF ───────────────────────────────────────────────────────

            PetShelf {
                id: shelf

                Layout.fillWidth: true
                Layout.preferredHeight: shelf.slot
            }
        }
    }
}
