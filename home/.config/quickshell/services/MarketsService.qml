// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M A R K E T S   S E R V I C E                                          │
// │   a watchlist of prices · coins and currencies                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Prices for the pairs named in the settings, via `scripts/markets.py`: a
// coin's from CoinGecko, a currency's from the ECB's daily rates.
//
// Polls only while something is subscribed and keeps the last good reading
// when a request fails. The first pair is the one the bar and the small
// faces show.
Singleton {
    id: root

    readonly property int pollInterval: 300000

    property int watchers: 0
    property bool available: false

    // { base, quote, kind, name, price, change, series, span, period }, in
    // the order the settings name them.
    property var items: []

    // Pairs neither source knows, for the settings.
    property var unknown: []

    property date readAt: new Date(0)

    readonly property var lead: root.items.length > 0 ? root.items[0] : null

    // The pairs after the first, listed under its chart on the detail.
    readonly property var others: root.items.slice(1, 5)

    // The detail's height: the heading, the chart, a row per other pair.
    readonly property int chartHeight: 64
    readonly property int cardHeight: root.others.length > 0
        ? Theme.cardHeight(root.others.length, Theme.cardRowGap + root.chartHeight)
        : Theme.cardHeight(0, root.chartHeight)

    // The pairs as the backend takes them: commas or spaces between.
    readonly property var pairs: SettingsService.markets.split(/[\s,]+/).filter(text => text !== "")

    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    readonly property string age: {
        if (!root.available)
            return ""
        const minutes = Math.floor((root.clock.date.getTime() - root.readAt.getTime()) / 60000)
        if (minutes < 2)
            return Tr.t("just now")
        if (minutes < 60)
            return Tr.t("%1 min ago").arg(minutes)
        return Tr.t("%1 h ago").arg(Math.round(minutes / 60))
    }

    // ── FORMAT ──────────────────────────────────────────────────────────────
    //
    // Shared by every face, so a price reads the same on the bar and on the
    // desk.

    readonly property var signs: ({ USD: "$", EUR: "€", GBP: "£", JPY: "¥" })

    function grouped(text: string): string {
        const [whole, part] = text.split(".")
        const commas = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
        return part !== undefined ? `${commas}.${part}` : commas
    }

    function digits(item: var): string {
        const price = item.price
        if (item.kind === "currency")
            return price >= 100 ? price.toFixed(2) : price.toFixed(4)
        if (price >= 1000)
            return root.grouped(price.toFixed(0))
        if (price >= 1)
            return root.grouped(price.toFixed(2))
        return price.toPrecision(3)
    }

    // "$83,369" for a coin, "1.1206" for a rate, "0.512 CHF" where the quote
    // has no sign.
    function price(item: var): string {
        if (!item)
            return "—"
        if (item.kind === "currency")
            return root.digits(item)
        const sign = root.signs[item.quote]
        return sign ? `${sign}${root.digits(item)}` : `${root.digits(item)} ${item.quote}`
    }

    // "83.4k" and the like, for the chip and the small faces.
    function short(item: var): string {
        if (!item)
            return "—"
        const price = item.price
        if (item.kind === "coin" && price >= 1000000)
            return `${(price / 1000000).toFixed(2)}M`
        if (item.kind === "coin" && price >= 10000)
            return `${(price / 1000).toFixed(1)}k`
        return root.digits(item)
    }

    function change(item: var): string {
        if (!item)
            return ""
        const arrow = item.change >= 0 ? "▲" : "▼"
        return `${arrow} ${Math.abs(item.change).toFixed(2)}%`
    }

    function rising(item: var): bool {
        return !!item && item.change >= 0
    }

    // Up and down keep the fixed indicator hues, like any warning.
    function tint(item: var): color {
        if (!item)
            return Theme.text
        return item.change >= 0 ? Theme.indicatorGood : Theme.indicatorBad
    }

    // The series squeezed between its own low and high, for a Sparkline with
    // a ceiling of 1: a price moves a few percent, so a scale from zero would
    // draw it flat.
    function shape(item: var): var {
        if (!item || !item.series || item.series.length < 2)
            return []
        const low = Math.min(...item.series)
        const high = Math.max(...item.series)
        const range = high - low
        return item.series.map(value => range > 0 ? (value - low) / range : 0.5)
    }

    function glyph(item: var): string {
        if (!item)
            return "󰄨"
        if (item.kind === "currency")
            return "󰓡"
        switch (item.base) {
        case "BTC":
            return "󰠓"
        case "ETH":
            return "󰡪"
        }
        return item.change >= 0 ? "󰔵" : "󰔳"
    }

    // ── POLL ────────────────────────────────────────────────────────────────

    function subscribe(): void {
        root.watchers += 1
        const minutes = (new Date().getTime() - root.readAt.getTime()) / 60000
        if (!root.available || minutes > 4)
            root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // A refresh asked for while one runs goes again when it exits, with the
    // list as it is then; a running Process ignores being started.
    property bool again: false
    property var asked: []

    function refresh(): void {
        if (root.query.running) {
            root.again = true
            return
        }
        root.asked = root.pairs
        root.query.command = [Quickshell.shellPath("scripts/markets.py")].concat(root.asked)
        root.query.running = true
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    // A changed list is asked for at once, a moment after the typing stops.
    readonly property Timer settle: Timer {
        interval: 800
        onTriggered: root.refresh()
    }

    Connections {
        target: SettingsService

        function onMarketsChanged(): void {
            root.settle.restart()
        }
    }

    readonly property Process query: Process {
        onExited: if (root.again) {
            root.again = false
            root.refresh()
        }
        stdout: StdioCollector {
            onStreamFinished: {
                // An answer for a list since changed is not this list's.
                if (root.asked.join(" ") !== root.pairs.join(" "))
                    return
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the markets report:", error)
                    return
                }
                root.unknown = report.unknown ?? []
                // Keep the last good reading when a request failed; an
                // emptied list empties it.
                if (report.available !== true) {
                    if (root.pairs.length === 0 || report.complete === true) {
                        root.items = []
                        root.available = false
                    }
                    return
                }
                // A pair whose request failed keeps its last reading.
                let items = report.items
                if (report.complete !== true) {
                    const kept = pair => root.items.find(item =>
                        `${item.base}/${item.quote}` === pair)
                    const fresh = pair => items.find(item =>
                        `${item.base}/${item.quote}` === pair)
                    items = root.pairs.map(text => {
                        const [base, quote] = text.toUpperCase().split("/")
                        const pair = `${base}/${quote || "USD"}`
                        return fresh(pair) ?? kept(pair)
                    }).filter(item => item !== undefined)
                }
                root.items = items
                root.readAt = new Date()
                root.available = true
            }
        }
    }
}
