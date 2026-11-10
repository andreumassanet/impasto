// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G I T H U B   M O D U L E                                              │
// │   github · yearly count, contribution graph when open                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// Yearly count, streak and the contribution grid. Desktop only
// (`bar: false` in the catalogue). Shows the reading's age, since it comes
// from the network.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: GithubService.subscribe()
    Component.onDestruction: GithubService.release()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ModuleCard {
            title: GithubService.user !== "" ? GithubService.user : "GitHub"
            subtitle: {
                const parts = [Tr.t("contributions this year")]
                if (GithubService.streak > 0)
                    parts.push(Tr.t("%1-day streak").arg(GithubService.streak))
                if (GithubService.age !== "")
                    parts.push(GithubService.age)
                return parts.join(" · ")
            }
            figure: GithubService.totalLabel

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: 0
                trackColor: Theme.indicatorDim

                Text {
                    anchors.centerIn: parent
                    text: "󰊤"
                    font.family: Theme.fontMono
                    font.pixelSize: 20
                    color: Theme.indicator
                }
            }

            ContributionGrid {
                Layout.fillWidth: true
                Layout.preferredHeight: GithubService.cardGrid
                weeks: GithubService.weeks
                // As many recent weeks as fit the island; the full year is the
                // widget's.
                maxWeeks: 30
                spacing: 3
            }
        }
    }
}
