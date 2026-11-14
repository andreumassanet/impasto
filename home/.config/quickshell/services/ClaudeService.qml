// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C L A U D E   S E R V I C E                                            │
// │   usage against a reference · read from the transcripts                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Claude Code usage for the current five-hour block and the last seven days.
//
// Token and message counts come from the transcripts on disk, where every
// assistant turn records its usage. Percentages are the account's own, the
// figures `/usage` shows: the session, the week, and a week per model where
// the plan has one (`claude_usage.py limits`).
//
// Runs only while subscribed; the first transcript pass is a full scan.
Singleton {
    id: root

    // The block is five hours; two-minute resolution is plenty.
    readonly property int pollInterval: 120000

    property int watchers: 0
    property bool available: false

    // Query once on construction: the bar only builds the module once
    // `available` is true, so nothing would subscribe otherwise.
    Component.onCompleted: root.refresh()

    property real blockStart: 0
    property real blockEnd: 0
    property int blockTokens: 0
    property int blockMessages: 0
    property int weekTokens: 0
    property int weekMessages: 0
    property int peakBlockTokens: 0
    property int peakWeekTokens: 0


    // ── PERCENTAGES ─────────────────────────────────────────────────────────
    //
    // Only the account's own figures are shown as percentages; local peaks
    // are never used as a denominator.
    readonly property bool sessionMeasured: root.limitsKnown
    readonly property bool weeklyMeasured: root.limitsKnown
    readonly property bool measured: root.limitsKnown

    readonly property real sessionFraction:
        root.limitsKnown ? Math.max(0, Math.min(1, root.sessionUsed)) : 0

    readonly property real weeklyFraction:
        root.limitsKnown ? Math.max(0, Math.min(1, root.weekUsed)) : 0

    // Wall clock, so the countdown advances between polls.
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0
    }

    // Prefer the account's reset time: the transcripts only know when this
    // machine first wrote into the block, which may be after it started.
    readonly property real blockEnds:
        root.limitsKnown && root.sessionResets > 0 ? root.sessionResets : root.blockEnd

    readonly property real remaining: {
        if (!root.available && !root.limitsKnown)
            return 0
        return Math.max(0, root.blockEnds * 1000 - root.clock.date.getTime())
    }

    readonly property real elapsed: {
        // The window is always five hours; only its end moves.
        const span = root.limitsKnown && root.sessionResets > 0
            ? 5 * 3600 * 1000
            : (root.blockEnd - root.blockStart) * 1000
        if ((!root.available && !root.limitsKnown) || span <= 0)
            return 0
        return Math.max(0, Math.min(1, 1 - root.remaining / span))
    }

    // "resets in 3 h 53 min"
    readonly property string resetsIn: {
        if (!root.available && !root.limitsKnown)
            return ""
        const minutes = Math.ceil(root.remaining / 60000)
        if (minutes <= 0)
            return Tr.t("resets now")
        const hours = Math.floor(minutes / 60)
        return hours > 0
            ? Tr.t("resets in %1 h %2 min").arg(hours).arg(minutes % 60)
            : Tr.t("resets in %1 min").arg(minutes)
    }

    // Coloured only past the warning thresholds, and only against a real
    // ceiling. Fixed indicator hues rather than the palette, so the meaning
    // is stable; neutral at rest like the other rings.
    readonly property color tint: {
        if (!root.available && !root.limitsKnown)
            return Theme.indicatorDim
        if (root.limited)
            return Theme.indicatorBad
        if (!root.measured)
            return Theme.indicator
        const worst = Math.max(root.sessionFraction, root.weeklyFraction,
            ...root.models.map(model => model.used))
        if (worst >= 0.85)
            return Theme.indicatorBad
        if (worst >= 0.6)
            return Theme.indicatorWarn
        return Theme.indicator
    }

    // The fraction spent when the account's figures are known, otherwise the
    // block's elapsed time.
    readonly property real gauge: root.measured
        ? Math.max(root.sessionFraction, root.weeklyFraction)
        : root.elapsed

    // The rows of its card: each limit and the session's count, or the
    // session's and the week's counts when the limits are unknown.
    readonly property int rows: root.limitsKnown ? 3 + root.models.length : 2

    // "84 messages", "1.2k messages".
    function messages(count: int): string {
        return Tr.t(count === 1 ? "%1 message" : "%1 messages").arg(root.compact(count))
    }

    // 1.2k, 34k, 8.7M.
    function compact(tokens: int): string {
        if (tokens >= 1000000)
            return `${(tokens / 1000000).toFixed(1)}M`
        if (tokens >= 1000)
            return `${Math.round(tokens / 1000)}k`
        return `${tokens}`
    }

    function percent(fraction: real): string {
        return `${Math.round(fraction * 100)}%`
    }

    function subscribe(): void {
        root.watchers += 1
        root.refresh()
        root.askLimits()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function refresh(): void {
        root.query.running = true
    }

    function askLimits(): void {
        root.limitsQuery.running = true
    }

    readonly property Timer poller: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    // ── ACCOUNT LIMITS ──────────────────────────────────────────────────────
    //
    // One request to the account's usage endpoint (`claude_usage.py
    // limits`). Polled every ten minutes, and only while subscribed.
    readonly property int limitsInterval: 600000

    property bool limitsKnown: false
    property real sessionUsed: 0
    property real weekUsed: 0
    property real sessionResets: 0
    property real weekResets: 0
    property string claim: ""
    property string plan: ""
    // A week per model, where the plan has one: `{ name, used, resets }`.
    property var models: []

    // The headers report a rate limit before requests start failing.
    property bool limited: false

    readonly property Timer limitsPoller: Timer {
        interval: root.limitsInterval
        repeat: true
        running: root.watchers > 0
        onTriggered: root.askLimits()
    }

    readonly property Process limitsQuery: Process {
        command: [Quickshell.shellPath("scripts/claude_usage.py"), "limits"]
        stdout: StdioCollector {
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the Claude limits:", error)
                    return
                }
                if (report.available !== true) {
                    // No credentials, no network, or an expired token. The
                    // counts still work; percentages are hidden, not stale.
                    root.limitsKnown = false
                    return
                }
                if (report.session) {
                    root.sessionUsed = report.session.used
                    root.sessionResets = report.session.resets
                }
                if (report.week) {
                    root.weekUsed = report.week.used
                    root.weekResets = report.week.resets
                }
                root.claim = report.claim ?? ""
                root.plan = report.plan ?? ""
                root.models = report.models ?? []
                root.limited = report.status === "rate_limited"
                    || [report.session, report.week].concat(root.models)
                        .some(window => window && window.used >= 1)
                root.limitsKnown = true
            }
        }
    }

    readonly property Process query: Process {
        command: [Quickshell.shellPath("scripts/claude_usage.py")]
        stdout: StdioCollector {
            // Per stream, not per chunk: partial JSON doesn't parse.
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the Claude usage report:", error)
                    return
                }
                root.available = report.available === true
                if (!root.available)
                    return
                root.blockStart = report.blockStart
                root.blockEnd = report.blockEnd
                root.blockTokens = report.blockTokens
                root.blockMessages = report.blockMessages
                root.weekTokens = report.weekTokens
                root.weekMessages = report.weekMessages
                root.peakBlockTokens = report.peakBlockTokens
                root.peakWeekTokens = report.peakWeekTokens
            }
        }
    }
}
