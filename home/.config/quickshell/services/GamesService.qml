// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G A M E S   S E R V I C E                                              │
// │   arcade · game registry and best scores                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// The arcade's registry and best scores.
//
// A game is a file in `bar/island/games/`, a row here and a row in
// `GameBoard`. The row carries the board size so the island can take its shape
// before the game is loaded. Records live in `games.json` in the state
// directory, written on a debounce rather than on every adapter change.
Singleton {
    id: root

    // Reading this constructs the singleton; `ModuleService.has` uses it.
    readonly property bool ready: true

    // ── CATALOGUE ───────────────────────────────────────────────────────────
    //
    //   id      file name in lower case, and the key in the record
    //   name    proper noun, not translated
    //   icon    glyph on its card
    //   tint    palette token, never a hex
    //   width   board size in pixels; the island adds the strip and padding
    //   height
    //   unit    points or moves
    //   lower   true where fewer is better
    readonly property var catalogue: [
        { id: "whack", name: "Whack-a-Mole", icon: "󰣪", tint: "green",
          width: 520, height: 440, unit: "points", lower: false },
        { id: "snake", name: "Snake Sprint", icon: "󱔎", tint: "green",
          width: 520, height: 520, unit: "points", lower: false },
        { id: "flood", name: "Flood Colors", icon: "󰖌", tint: "blue",
          width: 520, height: 560, unit: "moves", lower: true },
        { id: "mini2048", name: "2048 Mini", icon: "󰎠", tint: "blue",
          width: 480, height: 520, unit: "points", lower: false },
        { id: "lights", name: "Lights Out", icon: "󰛨", tint: "yellow",
          width: 460, height: 500, unit: "moves", lower: true },
        // Its slabs use the tint plus the other three hues, so it takes the
        // one that stays distinct from green, yellow and blue.
        { id: "hextris", name: "Hextris", icon: "󰋘", tint: "red",
          width: 520, height: 560, unit: "points", lower: false },
        { id: "bots", name: "Bot Bash", icon: "󰚩", tint: "red",
          width: 520, height: 520, unit: "points", lower: false },
        { id: "target", name: "Target Smash", icon: "󰓾", tint: "red",
          width: 560, height: 460, unit: "points", lower: false },
        { id: "space", name: "Space Blaster", icon: "󱓞", tint: "blue",
          width: 520, height: 600, unit: "points", lower: false },
        { id: "tetris", name: "Tetris", icon: "▙", tint: "accent",
          width: 460, height: 600, unit: "points", lower: false },
        { id: "solitaire", name: "Solitaire", icon: "♠", tint: "green",
          width: 760, height: 560, unit: "moves", lower: true }
    ]

    function entry(id: string): var {
        return root.catalogue.find(item => item.id === id) ?? null
    }

    readonly property var tints: ({
        accent: Theme.accent,
        green: Theme.green,
        yellow: Theme.yellow,
        red: Theme.red,
        blue: Theme.blue
    })

    function tintOf(id: string): color {
        const item = root.entry(id)
        return item ? (root.tints[item.tint] ?? Theme.accent) : Theme.accent
    }

    // ── SIZES ───────────────────────────────────────────────────────────────
    //
    // Declared rather than measured, so the island can morph before the panel
    // that fills it exists.
    readonly property int shelfWidth: 940
    readonly property int shelfHeight: 196
    readonly property int stripHeight: 28
    readonly property int stripGap: 12

    function panelSize(id: string): var {
        const item = root.entry(id)
        if (!item)
            return { width: root.shelfWidth, height: root.shelfHeight }
        return {
            width: item.width + 2 * Theme.panelPadding,
            height: item.height + root.stripHeight + root.stripGap + 2 * Theme.panelPadding
        }
    }

    // The game on screen, or "" for the shelf. `lastOpened` is where the
    // shelf scrolls back to.
    property string playing: ""
    property string lastOpened: ""

    function open(id: string): void {
        if (!root.entry(id))
            return
        root.playing = id
        root.lastOpened = id
    }

    function leave(): void {
        root.playing = ""
    }

    // ── RECORDS ─────────────────────────────────────────────────────────────
    //
    // `{ best, plays, playedAt }` per game played; unplayed games have no
    // entry.
    property var bests: ({})

    function recordOf(id: string): var {
        return root.bests[id] ?? null
    }

    function played(id: string): bool {
        return root.recordOf(id) !== null
    }

    function bestOf(id: string): int {
        const record = root.recordOf(id)
        return record ? record.best : 0
    }

    function playsOf(id: string): int {
        const record = root.recordOf(id)
        return record ? record.plays : 0
    }

    readonly property int totalPlays:
        root.catalogue.reduce((sum, item) => sum + root.playsOf(item.id), 0)

    // Most recently played game; the chip and the widget lead with it.
    readonly property string lastPlayed: {
        let best = ""
        let when = 0
        for (const item of root.catalogue) {
            const record = root.recordOf(item.id)
            if (record && record.playedAt > when) {
                when = record.playedAt
                best = item.id
            }
        }
        return best
    }

    // Played games, most recent first.
    readonly property var ranked: root.catalogue
        .filter(item => root.played(item.id))
        .sort((left, right) => root.recordOf(right.id).playedAt - root.recordOf(left.id).playedAt)

    signal newBest(string id, int score)

    // Records a finished round. Returns true if it beat the best.
    function record(id: string, score: int): bool {
        const item = root.entry(id)
        if (!item)
            return false
        // Ignore empty rounds. Move-counted puzzles never score zero.
        if (score <= 0 && !item.lower)
            return false
        const previous = root.recordOf(id)
        const better = previous === null
            || (item.lower ? score < previous.best : score > previous.best)
        const next = Object.assign({}, root.bests)
        next[id] = {
            best: better ? score : previous.best,
            plays: (previous ? previous.plays : 0) + 1,
            playedAt: Date.now()
        }
        root.bests = next
        root.saver.restart()
        if (better) {
            root.newBest(id, score)
            // No announcement for a first score.
            if (previous !== null)
                OsdService.requested(item.icon, Tr.t("New best · %1 %2").arg(item.name).arg(score), -1)
        }
        return better
    }

    // ── STORAGE ─────────────────────────────────────────────────────────────

    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: {
            state.bests = root.bests
            root.file.writeAdapter()
        }
    }

    readonly property FileView file: FileView {
        path: `${SettingsService.stateDirectory}/games.json`

        onLoaded: root.bests = state.bests ?? ({})
        // First run: no file yet, so write the empty record rather than
        // treating the miss as an error.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
        }

        JsonAdapter {
            id: state

            property var bests: ({})
        }
    }
}
