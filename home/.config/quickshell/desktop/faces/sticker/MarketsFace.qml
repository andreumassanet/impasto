// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M A R K E T S   F A C E                                                │
// │   a watchlist · the day's move on a cookie, the price on a tag           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"

// The first pair's move, an arrow and a percentage on a lobed sticker in the
// colour of the move; the price on the tag beside it, or over its foot on a
// square.
Spread {
    id: face

    readonly property var lead: MarketsService.lead
    readonly property color tint: face.lead ? MarketsService.tint(face.lead) : face.ink.accent

    hue: face.tint
    line: face.lead ? `${face.lead.base} ${MarketsService.short(face.lead)}`
        : MarketsService.pairs.length === 0 ? Tr.t("Nothing listed") : Tr.t("No prices")
    reading: MarketsService.price(face.lead)
    note: face.lead ? `${face.lead.base}/${face.lead.quote} · ${face.lead.period}`
        : MarketsService.pairs.length === 0 ? Tr.t("nothing on the list") : Tr.t("no prices")

    Tone { id: tone; hue: face.tint }

    Cut {
        id: badge

        anchors.centerIn: parent
        width: parent.width * 0.9
        height: width
        shape: "cookie"
        lobes: 10
        depth: 0.05
        seed: face.seed
        fill: tone.fill

        Column {
            anchors.centerIn: parent

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !face.lead ? "–" : MarketsService.rising(face.lead) ? "▲" : "▼"
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(badge.side * 0.3)
                font.weight: Font.Bold
                color: tone.deep
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.lead ? `${Math.abs(face.lead.change).toFixed(1)}%` : ""
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(badge.side * 0.16)
                font.weight: Font.Bold
                color: tone.deep
            }
        }
    }
}
