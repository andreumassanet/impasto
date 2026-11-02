// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S C R E E N   T I M E   S E R V I C E                                  │
// │   screen time · what is in front, recorded, and read back by period      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Time in each application, counted while the session is unlocked. It stops
// when the session locks or the idle setting turns the screen off; a screen
// turned off by hand, to leave something running, still counts.
// `screentime.py record` keeps the clock and the files; this tells it what
// happens. The panel's numbers are
// `screentime.py report`, read when it opens and each minute after.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/screentime.py")

    // ── RECORDING ───────────────────────────────────────────────────────────

    readonly property bool away: LockService.locked
        || (IdleService.screenWatch.enabled && IdleService.screenWatch.isIdle)

    readonly property Process recorder: Process {
        command: [root.script, "record"]
        stdinEnabled: true
        running: true
        onStarted: {
            root.send(`focus ${HyprlandService.focusedClass}`)
            if (root.away)
                root.send("away")
        }
        onExited: root.restart.start()
    }

    // A recorder that died is started again, but not in a loop.
    readonly property Timer restart: Timer {
        interval: 30000
        onTriggered: root.recorder.running = true
    }

    function send(line: string): void {
        if (root.recorder.running)
            root.recorder.write(line.replace(/\n/g, " ") + "\n")
    }

    onAwayChanged: {
        if (!root.away)
            root.send("back")
        else
            root.send("away")
    }

    readonly property Connections focus: Connections {
        target: HyprlandService
        function onFocusedClassChanged(): void {
            root.send(`focus ${HyprlandService.focusedClass}`)
        }
    }

    readonly property Connections lock: Connections {
        target: LockService
        function onUnlocked(): void {
            root.send("unlock")
        }
    }

    readonly property Connections notifications: Connections {
        target: NotificationService
        function onReceived(appName: string): void {
            root.send(`notify ${appName}`)
        }
    }

    // ── THE REPORT ──────────────────────────────────────────────────────────

    // "day", "week" or "month", around `date` (YYYY-MM-DD).
    property string view: "day"
    property string date: root.today()
    property var report: null

    readonly property bool loaded: root.report !== null
    readonly property bool empty: root.loaded && root.report.since === ""
    readonly property bool current: root.loaded
        && root.report.from <= root.report.today && root.report.today <= root.report.to

    property int watchers: 0

    function subscribe(): void {
        root.watchers += 1
        root.view = "day"
        root.date = root.today()
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // Asked again while a report was being read: read once more after it.
    property bool stale: false

    readonly property Process reader: Process {
        onExited: {
            if (root.stale) {
                root.stale = false
                root.refresh()
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const reply = JSON.parse(text)
                    if (!reply.error)
                        root.report = reply
                } catch (error) {
                    console.warn("Cannot read the screen time:", error)
                }
            }
        }
    }

    function refresh(): void {
        if (root.reader.running) {
            root.stale = true
            return
        }
        root.reader.command = [root.script, "report", root.view, root.date]
        root.reader.running = true
    }

    onViewChanged: if (root.watchers > 0) root.refresh()
    onDateChanged: if (root.watchers > 0) root.refresh()

    // The period being looked at grows while it is open.
    readonly property Timer tick: Timer {
        interval: 60000
        repeat: true
        running: root.watchers > 0 && root.current
        onTriggered: root.refresh()
    }

    // ── DATES ───────────────────────────────────────────────────────────────

    function key(date: date): string {
        return Qt.formatDate(date, "yyyy-MM-dd")
    }

    function today(): string {
        return root.key(new Date())
    }

    function dateOf(day: string): date {
        const parts = day.split("-").map(Number)
        return new Date(parts[0], parts[1] - 1, parts[2])
    }

    // One period back or forward, never past the one holding today.
    function step(by: int): void {
        const date = root.dateOf(root.date)
        if (root.view === "day")
            date.setDate(date.getDate() + by)
        else if (root.view === "week")
            date.setDate(date.getDate() + 7 * by)
        else
            date.setMonth(date.getMonth() + by, 1)
        const next = root.key(date)
        root.date = next > root.today() ? root.today() : next
    }

    readonly property bool canGoBack: root.loaded && root.report.since !== ""
        && root.report.from > root.report.since
    readonly property bool canGoForward: root.loaded && root.report.to < root.report.today

    function show(view: string, day: string): void {
        root.view = view
        root.date = day
    }

    // ── APPLICATIONS ────────────────────────────────────────────────────────

    // Clients whose desktop entry names too broad a category.
    readonly property var categoryOverrides: ({
        "vesktop.desktop": "social"
    })

    readonly property var categoryNames: ({
        development: "Development", social: "Social", internet: "Internet",
        entertainment: "Entertainment", games: "Games", creativity: "Creativity",
        productivity: "Productivity", utilities: "Utilities", other: "Other"
    })

    // Freedesktop categories, most telling first.
    function categoryOf(id: string, categories: var, windowClass: string): string {
        if (root.categoryOverrides[id])
            return root.categoryOverrides[id]
        if (windowClass.startsWith("steam_app_"))
            return "games"
        const has = names => names.some(name => categories.indexOf(name) >= 0)
        if (has(["Game"]))
            return "games"
        if (has(["Development", "IDE", "TextEditor", "TerminalEmulator"]))
            return "development"
        if (has(["InstantMessaging", "Chat", "Email"]))
            return "social"
        if (has(["WebBrowser"]))
            return "internet"
        if (has(["AudioVideo", "Audio", "Video", "Music", "Player"]))
            return "entertainment"
        if (has(["Graphics", "Photography"]))
            return "creativity"
        if (has(["Office", "Education", "Science"]))
            return "productivity"
        if (has(["Network"]))
            return "internet"
        if (has(["Utility", "System", "Settings", "FileManager"]))
            return "utilities"
        return "other"
    }

    // A window class as the dock would name it: the entry's name and icon,
    // and the group it is counted in.
    function appOf(windowClass: string, names: var): var {
        // The shell's own window is the settings.
        if (windowClass === "org.quickshell")
            return { key: windowClass, name: Tr.t("Settings"), icon: "preferences-system", category: "utilities" }
        const id = DockService.idFor(windowClass)
        const entry = id !== "" ? DockService.entryOf(id) : null
        // A Steam game has no entry of its own; it wears Steam's icon.
        const steam = !entry && windowClass.startsWith("steam_app_")
            ? DockService.entryOf(DockService.idFor("steam")) : null
        return {
            key: windowClass,
            name: entry ? entry.name : (names[windowClass] ?? windowClass),
            icon: (entry ?? steam)?.icon ?? "",
            category: root.categoryOf(id, entry ? (entry.categories ?? []) : [], windowClass)
        }
    }

    // A report as the views draw it: each class as an app, the apps and the
    // groups by time, the first `shades` groups ranked, and the chart's
    // buckets as seconds per ranked group with the rest last.
    readonly property int shades: 4

    function digest(report: var): var {
        const lookup = ({})
        const classes = report ? report.classes : ({})
        const names = report ? (report.names ?? {}) : ({})
        for (const key of Object.keys(classes))
            lookup[key] = key === "" ? null : root.appOf(key, names)

        // The desktop is in the total, never in the list.
        const apps = Object.keys(classes)
            .filter(key => key !== "")
            .map(key => Object.assign({ seconds: classes[key] }, lookup[key]))
            .sort((a, b) => b.seconds - a.seconds)

        const totals = ({})
        for (const app of apps)
            totals[app.category] = (totals[app.category] ?? 0) + app.seconds
        const categories = Object.keys(totals)
            .map(id => ({ id: id, name: Tr.t(root.categoryNames[id]), seconds: totals[id] }))
            .sort((a, b) => (a.id === "other") - (b.id === "other") || b.seconds - a.seconds)
        const ranked = categories
            .filter(category => category.id !== "other")
            .slice(0, root.shades)
            .map(category => category.id)

        const rankOf = key => lookup[key] ? ranked.indexOf(lookup[key].category) : -1
        const stack = bucket => {
            const parts = new Array(root.shades + 1).fill(0)
            for (const key of Object.keys(bucket ?? {})) {
                const rank = rankOf(key)
                parts[rank >= 0 ? rank : root.shades] += bucket[key]
            }
            return parts
        }

        return {
            lookup: lookup, apps: apps, categories: categories, ranked: ranked,
            stacks: report ? report.chart.map(stack) : [],
            recent: report && report.recent ? report.recent.map(day => stack(day.classes)) : [],
            sessions: report && report.sessions
                ? report.sessions.map(session => session.concat([rankOf(session[2])])) : []
        }
    }

    readonly property var shown: root.digest(root.report)

    readonly property var lookup: root.shown.lookup
    readonly property var apps: root.shown.apps
    readonly property var categories: root.shown.categories
    readonly property var ranked: root.shown.ranked
    readonly property var stacks: root.shown.stacks

    function rankOf(windowClass: string): int {
        const app = root.lookup[windowClass]
        return app ? root.ranked.indexOf(app.category) : -1
    }

    // ── TODAY ───────────────────────────────────────────────────────────────
    //
    // What the chip and the desk show: today, and the week up to it, read
    // each minute while one of them is up.

    property var summary: null
    readonly property var todayDigest: root.digest(root.summary)

    readonly property real todayTotal: root.summary ? root.summary.total : 0
    readonly property real todayBaseline: root.summary ? root.summary.baseline : 0
    readonly property var todayLead: root.todayDigest.apps[0] ?? null

    // Seconds per ranked group today, the rest (the desktop too) last.
    readonly property var todayParts: {
        const parts = new Array(root.shades + 1).fill(0)
        for (const category of root.todayDigest.categories) {
            const rank = root.todayDigest.ranked.indexOf(category.id)
            parts[rank >= 0 ? rank : root.shades] += category.seconds
        }
        parts[root.shades] += Math.max(0, root.todayTotal - parts.reduce((a, b) => a + b, 0))
        return parts
    }

    // The desk's line under the total: the most used app, or what is wrong.
    readonly property string todayNote: !root.summary ? ""
        : root.summary.since === "" ? Tr.t("Counting from now")
        : root.todayLead ? `${root.todayLead.name} · ${root.duration(root.todayLead.seconds)}`
        : Tr.t("Nothing yet today")

    // Against the week before, as a short phrase: "+44 min", "−12 min".
    readonly property string todayCompared: {
        if (root.todayBaseline <= 0)
            return ""
        const gap = root.todayTotal - root.todayBaseline
        return `${gap >= 0 ? "+" : "−"}${root.duration(Math.abs(gap))}`
    }

    // Today against the week's average day, for a ring that fills.
    readonly property real todayFraction: root.todayBaseline > 0
        ? Math.min(1, root.todayTotal / root.todayBaseline) : 0

    property int followers: 0

    function follow(): void {
        root.followers += 1
        root.readSummary()
    }

    function unfollow(): void {
        root.followers = Math.max(0, root.followers - 1)
    }

    readonly property Process summaryReader: Process {
        command: [root.script, "summary"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.summary = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot read today's screen time:", error)
                }
            }
        }
    }

    function readSummary(): void {
        if (!root.summaryReader.running)
            root.summaryReader.running = true
    }

    readonly property Timer summaryTick: Timer {
        interval: 60000
        repeat: true
        running: root.followers > 0
        onTriggered: root.readSummary()
    }

    // "6:31", for a chip.
    function short(seconds: real): string {
        const minutes = Math.floor(seconds / 60)
        return `${Math.floor(minutes / 60)}:${String(minutes % 60).padStart(2, "0")}`
    }

    // ── WORDS ───────────────────────────────────────────────────────────────

    function duration(seconds: real): string {
        const minutes = Math.round(seconds / 60)
        const hours = Math.floor(minutes / 60)
        const rest = minutes % 60
        if (hours === 0)
            return seconds > 0 && minutes === 0 ? "< 1 min" : `${minutes} min`
        return rest === 0 ? `${hours} h` : `${hours} h ${rest} min`
    }

    function clock(epoch: real): string {
        const format = SettingsService.clockFormat.indexOf("AP") >= 0
            || SettingsService.clockFormat.indexOf("ap") >= 0 ? "h:mm AP" : "HH:mm"
        return Tr.date(new Date(epoch * 1000), format)
    }
}
