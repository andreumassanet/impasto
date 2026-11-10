// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M A R K E T S   M O D U L E                                            │
// │   a watchlist · the first pair charted, the rest under it                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// The first pair's price and change on the chip; the detail charts it and
// lists the others with a line each. Shows the reading's age, since it comes
// from the network.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: MarketsService.subscribe()
    Component.onDestruction: MarketsService.release()

    readonly property var lead: MarketsService.lead

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ModuleCard {
            title: root.lead ? root.lead.name : Tr.t("Markets")
            subtitle: {
                if (!root.lead)
                    return MarketsService.pairs.length === 0 ? Tr.t("Nothing on the list") : Tr.t("No prices")
                const parts = [`${root.lead.base}/${root.lead.quote}`,
                               MarketsService.change(root.lead)]
                if (MarketsService.age !== "")
                    parts.push(MarketsService.age)
                return parts.join(" · ")
            }
            figure: root.lead ? MarketsService.price(root.lead) : ""

            mark: Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: MarketsService.glyph(root.lead)
                font.family: Theme.fontMono
                font.pixelSize: 28
                color: MarketsService.tint(root.lead)
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: MarketsService.chartHeight

                Sparkline {
                    anchors.fill: parent
                    values: MarketsService.shape(root.lead)
                    stroke: MarketsService.tint(root.lead)
                    thickness: 2
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    visible: root.lead !== null
                    text: root.lead ? root.lead.span : ""
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                }
            }

            Repeater {
                model: ScriptModel {
                    values: MarketsService.others
                }

                RowLayout {
                    id: line

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.cardRow
                    spacing: 10

                    Text {
                        Layout.preferredWidth: Theme.cardLabel
                        text: line.modelData.kind === "currency"
                            ? `${line.modelData.base}/${line.modelData.quote}` : line.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }

                    Sparkline {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        values: MarketsService.shape(line.modelData)
                        stroke: MarketsService.tint(line.modelData)
                        showDot: false
                    }

                    Text {
                        text: MarketsService.price(line.modelData)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Theme.text
                    }

                    Text {
                        Layout.preferredWidth: 62
                        horizontalAlignment: Text.AlignRight
                        text: MarketsService.change(line.modelData)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.features: { "tnum": 1 }
                        color: MarketsService.tint(line.modelData)
                    }
                }
            }
        }
    }
}
