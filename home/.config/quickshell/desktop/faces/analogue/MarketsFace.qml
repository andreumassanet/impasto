// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M A R K E T S   F A C E                                                │
// │   a watchlist · the first pair on a chart recorder                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"
import "../../../services"

// The first pair's history on a recorder's paper, the pen in the colour of
// the day's move. The price under it on a square, beside it on a wide face.
Item {
    id: root

    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)

    readonly property var lead: MarketsService.lead

    Instrument {
        anchors.fill: parent
        family: root.family
        ink: root.ink
        line: root.lead
            ? `${root.lead.base} ${MarketsService.short(root.lead)}  ${MarketsService.change(root.lead)}`
            : MarketsService.pairs.length === 0 ? Tr.t("Nothing on the list") : Tr.t("No prices")
        reading: MarketsService.price(root.lead)
        note: root.lead
            ? `${root.lead.base}/${root.lead.quote} · ${MarketsService.change(root.lead)} · ${root.lead.period}`
            : MarketsService.pairs.length === 0 ? Tr.t("Nothing on the list") : Tr.t("No prices")

        Recorder {
            anchors.fill: parent
            ink: root.ink
            values: MarketsService.shape(root.lead)
            pen: root.lead ? MarketsService.tint(root.lead) : root.ink.muted
        }
    }
}
