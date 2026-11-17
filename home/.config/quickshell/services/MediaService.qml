// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M E D I A   S E R V I C E                                              │
// │   the player worth showing · mpris over d-bus                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

import "."

// Picks one MPRIS player and exposes it flatly: the one that is playing,
// otherwise the first controllable one, so a paused track stays on the island.
// A player with nothing in it does not count: a browser keeps one registered,
// stopped and without a title, after the tab that played has gone.
Singleton {
    id: root

    // The browser a player belongs to: Brave's own players are named
    // `<name>.instance<pid>`; KDE's browser extension says it in `kde:pid`.
    function pidOf(player: var): int {
        return Number((/\.instance(\d+)$/.exec(player?.dbusName ?? "") ?? [])[1]
            ?? player?.metadata?.["kde:pid"] ?? 0)
    }

    // `playerctld` registers a player that mirrors the last active one: the
    // same track under a second entry, so it is left out. A browser's own
    // player says little (a site's "Title • Artist" and no cover or album);
    // KDE's extension, where it is installed, sends the whole track for the
    // same browser, so that one stands in for it.
    readonly property var players: {
        const all = Mpris.players.values.filter(player => !player.dbusName.endsWith(".playerctld"))
        const extended = all.filter(player => player.dbusName.endsWith(".plasma-browser-integration"))
            .map(player => root.pidOf(player))
        return all.filter(player => player.isPlaying || (player.trackTitle ?? "") !== "")
            .filter(player => player.dbusName.endsWith(".plasma-browser-integration")
                || root.pidOf(player) === 0 || extended.indexOf(root.pidOf(player)) < 0)
    }

    // A browser registers one player for the whole process, whatever tab or
    // web app plays; `nameOf` finds what is really playing from its windows.
    readonly property var browserPattern: /brave|chrom|firefox|vivaldi|zen|librewolf|opera|edge/i

    function isBrowser(player: var): bool {
        return root.browserPattern.test(`${player?.desktopEntry ?? ""} ${player?.identity ?? ""}`)
    }

    // What to call a player: the web app or site it plays in when it is a
    // browser ("Spotify", "YouTube"), else the name it gives itself. Browser
    // players are `<name>.instance<pid>`; the windows of that pid tell.
    function nameOf(player: var): string {
        const own = player?.identity ?? ""
        if (!root.isBrowser(player))
            return own
        const pid = root.pidOf(player)
        // Scratchpad and minimized windows play too; `clients` leaves them out.
        const windows = [...HyprlandService.clients, ...HyprlandService.specialClients,
                         ...HyprlandService.minimizedClients].filter(client => client.pid === pid)
        const title = player.trackTitle ?? ""
        const isApp = client => /^(crx_|brave-.+-)/.test(client.class)
        // The window showing this track: a web app is named by its desktop
        // entry, a tab by the site in its title ("<page> - <site> - <browser>").
        // A background tab has no window title to read: it stays the browser.
        const showing = title === "" ? null : windows.find(client => client.title.startsWith(title))
        // A process that is only one web app is that app, playing or not.
        const app = showing && isApp(showing) ? showing : (windows.length === 1 && isApp(windows[0]) ? windows[0] : null)
        if (app) {
            const entry = DesktopEntries.heuristicLookup(app.class)
            if (entry)
                return entry.name
        }
        if (showing) {
            const site = showing.title.slice(title.length).split(" - ").map(part => part.trim())
                .filter(part => part !== "" && part !== own)[0]
            if (site)
                return site
        }
        return own
    }

    // The player picked in the media panel; the one playing otherwise, and
    // the first it can control.
    property var chosen: null

    function choose(player: var): void {
        root.chosen = player
        // A player that is paused pushes no position: ask for one.
        if (root.available)
            root.active.positionChanged()
    }

    readonly property MprisPlayer active: {
        if (root.chosen && root.players.indexOf(root.chosen) >= 0)
            return root.chosen
        const playing = root.players.find(player => player.isPlaying)
        if (playing)
            return playing
        return root.players.find(player => player.canControl) ?? null
    }

    readonly property bool available: root.active !== null

    // For "which one am I driving": how many players there are, and the
    // 1-based place of the active one among them (0 with none).
    readonly property int count: root.players.length
    readonly property int index: root.players.indexOf(root.active) + 1

    // The next (+1) or previous (-1) player, wrapping. The pick stays until
    // that player goes away, wherever it was made from.
    function cycle(step: int): void {
        if (root.count < 2)
            return
        const at = Math.max(0, root.index - 1)
        root.choose(root.players[(at + step + root.count) % root.count])
    }

    function select(identity: string): bool {
        const found = root.players.find(player => player.identity === identity)
        if (!found)
            return false
        root.choose(found)
        return true
    }
    readonly property bool playing: root.available && root.active.isPlaying

    readonly property string title: root.available ? (root.active.trackTitle ?? "") : ""
    readonly property string artist: root.available ? (root.active.trackArtist ?? "") : ""
    readonly property string album: root.available ? (root.active.trackAlbum ?? "") : ""
    readonly property string artUrl: root.available ? (root.active.trackArtUrl ?? "") : ""
    readonly property string identity: root.available ? root.nameOf(root.active) : ""
    readonly property bool browser: root.available && root.isBrowser(root.active)

    readonly property bool canNext: root.available && root.active.canGoNext
    readonly property bool canPrevious: root.available && root.active.canGoPrevious
    readonly property bool canToggle: root.available && root.active.canTogglePlaying
    readonly property bool canSeek: root.available && root.active.canSeek && root.length > 0

    // Seconds. Streams report no length, so `progress` stays at 0.
    // A browser stream reports a length of days or none: neither is a length.
    readonly property real length: {
        const reported = root.available ? (root.active.length ?? 0) : 0
        return reported > 0 && reported < 86400 ? reported : 0
    }
    readonly property real position: root.available ? (root.active.position ?? 0) : 0
    readonly property bool seekable: root.length > 0
    readonly property real progress: root.seekable
        ? Math.max(0, Math.min(1, root.position / root.length))
        : 0

    // MPRIS does not push position, so it is polled only while something on
    // screen holds a subscribe().
    property int watchers: 0

    readonly property Timer positionTimer: Timer {
        // Often enough for a seek bar and lyrics to follow the music.
        interval: 250
        repeat: true
        running: root.watchers > 0 && root.playing && root.seekable
        onTriggered: {
            if (root.available)
                root.active.positionChanged()
        }
    }

    // The windows' titles change with the track: keep them fresh while a
    // browser player could be named from them.
    onPlayersChanged: HyprlandService.loadClients()

    readonly property Timer windowsTimer: Timer {
        interval: 5000
        repeat: true
        running: root.watchers > 0 && root.players.some(player => root.isBrowser(player))
        triggeredOnStart: true
        onTriggered: HyprlandService.loadClients()
    }

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function toggle(): void {
        if (root.canToggle)
            root.active.togglePlaying()
    }

    function next(): void {
        if (root.canNext)
            root.active.next()
    }

    // `fraction` of the track's length.
    function seek(fraction: real): void {
        if (!root.canSeek)
            return
        root.active.position = Math.max(0, Math.min(1, fraction)) * root.length
    }

    function previous(): void {
        if (root.canPrevious)
            root.active.previous()
    }
}
