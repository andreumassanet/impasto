// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P E T   S E R V I C E                                                  │
// │   a family of small creatures · one out, the rest on the shelf           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pets that live on the bar and level up while they are looked after.
//
// Experience comes only from feeding, playing and keeping the pet out on the
// bar. There is no death and no penalty for neglect: a neglected pet is
// hungry, lonely or asleep. Nothing is ever reset either; the family grows by
// one egg at each level milestone, rolled from the species it lacks.
//
// Only the pet that is out shows on the bar, earns experience and gets
// hungry; the rest keep their timestamps frozen on the shelf. Everything is
// stored in one JSON file; moods are derived from timestamps, never stored.
Singleton {
    id: root

    // Reading this constructs the singleton; `ModuleService.has` asks for it.
    readonly property bool ready: true

    property int watchers: 0

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // ── SPECIES ─────────────────────────────────────────────────────────────

    // Tints are palette tokens, so each species follows the wallpaper. Labels
    // are proper names and are not translated.
    readonly property var species: [
        { id: "dot",    label: "Dot",    tint: "accent", ears: "round" },
        { id: "sprout", label: "Sprout", tint: "green",  ears: "leaf" },
        { id: "ember",  label: "Ember",  tint: "red",    ears: "tuft" },
        { id: "sol",    label: "Sol",    tint: "yellow", ears: "none" },
        { id: "drift",  label: "Drift",  tint: "blue",   ears: "droop" }
    ]

    function speciesOf(record: var): var {
        const wanted = record ? record.species : ""
        return root.species.find(kind => kind.id === wanted) ?? root.species[0]
    }

    // ── STYLES ──────────────────────────────────────────────────────────────

    // How a creature is drawn, whichever species it is: one file per style in
    // `components/pets`, and `SettingsService.petStyle` holds the id. The
    // species decide colour and silhouette, the style decides the finish.
    readonly property var styles: [
        { id: "creature", label: "Creature", note: "A different animal for each species." },
        { id: "plush",    label: "Plush",    note: "One round body, shaded." },
        { id: "paper",    label: "Paper",    note: "Flat, cut from two tones." },
        { id: "pixel",    label: "Pixel",    note: "A sprite, sixteen cells across." }
    ]

    // ── FAMILY ──────────────────────────────────────────────────────────────

    // Records: `{ species, name, level, xp, fedAt, playedAt, hatchedAt,
    // restedAt }`. Held here and only mirrored into the adapter (see
    // STORAGE).
    property var family: []
    property int active: 0

    readonly property int activeIndex:
        Math.max(0, Math.min(root.active, root.family.length - 1))

    readonly property var pet: root.family[root.activeIndex] ?? null

    readonly property string name: root.pet ? root.pet.name : ""
    readonly property int level: root.pet ? root.pet.level : 1
    readonly property int xp: root.pet ? root.pet.xp : 0
    readonly property var speciesInfo: root.speciesOf(root.pet)

    // An egg hatches at its first meal or game (`reward` sets the stamp).
    readonly property bool hatched: root.pet ? root.pet.hatchedAt > 0 : false

    function recordAt(index: int): var {
        return root.family[index] ?? null
    }

    // ── COLLECTION ──────────────────────────────────────────────────────────

    // Total family level at which each next egg is laid. Summed across the
    // family, and only the pet that is out earns, so progress means rotating
    // them.
    readonly property var milestones: [6, 16, 30, 50]

    readonly property int totalLevel:
        root.family.reduce((sum, entry) => sum + entry.level, 0)

    readonly property bool complete: root.family.length >= root.species.length

    readonly property int nextEggAt:
        root.complete ? 0 : root.milestones[Math.max(0, root.family.length - 1)]

    readonly property int levelsToNextEgg:
        root.complete ? 0 : Math.max(0, root.nextEggAt - root.totalLevel)

    readonly property real eggProgress: {
        if (root.complete)
            return 1
        const from = root.family.length < 2
            ? 0 : root.milestones[root.family.length - 2]
        const span = Math.max(1, root.nextEggAt - from)
        return Math.max(0, Math.min(1, (root.totalLevel - from) / span))
    }

    // ── WRITING ─────────────────────────────────────────────────────────────

    // Records are plain objects in a `var`, so in-place changes do not
    // notify; every change rebuilds and reassigns the list.
    function replace(index: int, record: var): var {
        return root.family.map((entry, at) => at === index ? record : entry)
    }

    // Species rolled from those the family lacks, when the egg is laid, so
    // the speckles can hint at the coat.
    function newborn(list: var): var {
        const taken = list.map(entry => entry.species)
        const left = root.species.filter(kind => taken.indexOf(kind.id) < 0)
        const kind = left.length > 0
            ? left[Math.floor(Math.random() * left.length)]
            : root.species[0]
        return {
            species: kind.id,
            name: "",
            level: 1,
            xp: 0,
            fedAt: 0,
            playedAt: 0,
            hatchedAt: 0,
            restedAt: 0
        }
    }

    // Works on the list in hand, since the caller is about to replace
    // `family`. A loop: one reward can cross two milestones.
    function earned(list: var): var {
        let grown = list
        while (grown.length < root.species.length) {
            const total = grown.reduce((sum, entry) => sum + entry.level, 0)
            if (total < root.milestones[grown.length - 1])
                break
            grown = grown.concat([root.newborn(grown)])
        }
        return grown
    }

    // ── LEVELS ──────────────────────────────────────────────────────────────

    // Linear and shallow.
    function thresholdFor(at: int): int {
        return 40 + 20 * at
    }

    readonly property int threshold: root.thresholdFor(root.level)
    readonly property real progress:
        Math.max(0, Math.min(1, root.xp / root.threshold))

    signal celebrated(int level)
    signal played()
    signal laid()

    // One write for the stamp, the experience, level-ups and any eggs laid.
    function reward(amount: int, changes: var): void {
        if (!root.pet)
            return
        const grown = Object.assign({}, root.pet, changes ?? {})
        if (grown.hatchedAt <= 0)
            grown.hatchedAt = Date.now()
        grown.xp += amount
        let reached = 0
        while (grown.xp >= root.thresholdFor(grown.level)) {
            grown.xp -= root.thresholdFor(grown.level)
            grown.level += 1
            reached = grown.level
        }
        const list = root.replace(root.activeIndex, grown)
        const full = root.earned(list)
        root.family = full
        root.saver.restart()
        if (reached > 0)
            root.celebrated(reached)
        if (full.length > list.length) {
            root.laid()
            // Eggs can arrive while nothing shows the pet, so announce them.
            if (SettingsService.onBar("pet"))
                OsdService.requested("󰪯", "A new egg on the shelf", -1)
        }
    }

    // ── CARE ────────────────────────────────────────────────────────────────

    // Generous: feeding and playing are the whole active game.
    readonly property real feedCooldown: 90 * 60000
    readonly property real playCooldown: 5 * 60000

    // Runs while something shows the pet or it is on the bar: the trickle
    // below depends on the mood, which is read through this clock.
    readonly property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        enabled: root.watchers > 0 || SettingsService.onBar("pet")
    }

    // A zero stamp reads as "just now", so a fresh hatch is not starving.
    function agoOf(stamp: real): real {
        return stamp > 0 ? Math.max(0, root.clock.date.getTime() - stamp) : 0
    }

    readonly property real fedAgo: root.agoOf(root.pet ? root.pet.fedAt : 0)
    readonly property real playedAgo: root.agoOf(root.pet ? root.pet.playedAt : 0)

    readonly property bool canFeed:
        !!root.pet && (root.pet.fedAt <= 0 || root.fedAgo >= root.feedCooldown)
    readonly property bool canPlay:
        !!root.pet && (root.pet.playedAt <= 0 || root.playedAgo >= root.playCooldown)

    function feed(): void {
        if (!root.canFeed)
            return
        root.reward(25, { fedAt: Date.now() })
    }

    // Time since the last game pays a capped bonus, so coming back later is
    // worth more than grinding the cooldown.
    function play(): void {
        if (!root.canPlay)
            return
        const bonus = Math.min(18, Math.floor(root.playedAgo / 3600000) * 3)
        root.reward(12 + bonus, { playedAt: Date.now() })
        root.played()
    }

    function renameAt(index: int, text: string): void {
        if (index < 0 || index >= root.family.length)
            return
        const named = Object.assign({}, root.family[index], {
            name: (text ?? "").trim().slice(0, 24)
        })
        root.family = root.replace(index, named)
        root.saver.restart()
    }

    function rename(text: string): void {
        root.renameAt(root.activeIndex, text)
    }

    // ── SHELF ───────────────────────────────────────────────────────────────

    signal brought(int index)

    // The pet going back records when it fell asleep; the one waking has that
    // time added to its stamps, so time on the shelf does not count.
    function bringOut(index: int): void {
        if (index < 0 || index >= root.family.length || index === root.activeIndex)
            return
        const now = Date.now()
        const list = root.family.slice()
        list[root.activeIndex] = Object.assign({}, list[root.activeIndex], {
            restedAt: now
        })
        const waking = Object.assign({}, list[index])
        const slept = waking.restedAt > 0 ? Math.max(0, now - waking.restedAt) : 0
        if (waking.fedAt > 0)
            waking.fedAt += slept
        if (waking.playedAt > 0)
            waking.playedAt += slept
        waking.restedAt = 0
        list[index] = waking
        root.family = list
        root.active = index
        root.saver.restart()
        root.brought(index)
    }

    // ── MOOD ────────────────────────────────────────────────────────────────

    // Derived, never stored. Checked in order: long neglect reads as asleep,
    // and hunger outranks loneliness.
    readonly property string mood: {
        const fed = root.fedAgo
        const played = root.playedAgo
        if (fed > 16 * 3600000 && played > 16 * 3600000)
            return "asleep"
        if (fed > 6 * 3600000)
            return "peckish"
        if (played > 8 * 3600000)
            return "lonely"
        if (fed < 3 * 3600000 && played < 2 * 3600000)
            return "beaming"
        return "content"
    }

    // Everyone on the shelf is asleep.
    function moodAt(index: int): string {
        return index === root.activeIndex ? root.mood : "asleep"
    }

    readonly property string moodLine: {
        if (!root.hatched)
            return "An egg — feed it and it will hatch"
        switch (root.mood) {
        case "beaming": return "Beaming"
        case "peckish": return "Peckish — a snack is owed"
        case "lonely":  return "Lonely — nobody has played today"
        case "asleep":  return "Fast asleep"
        }
        return "Content"
    }

    function titleOf(record: var): string {
        if (!record)
            return "Egg"
        if (record.hatchedAt <= 0)
            return "Egg"
        return record.name !== "" ? record.name : root.speciesOf(record).label
    }

    // ── COMPANY ─────────────────────────────────────────────────────────────

    // A trickle of experience for being out on the bar: only while hatched,
    // awake and with the screen unlocked, so a machine left on overnight
    // earns nothing and an egg never hatches by itself. Keyed on the bar
    // placement rather than on `watchers`, i.e. whether a chip is drawn.
    readonly property int companyEvery: 5 * 60000
    readonly property int companyXp: 1

    readonly property Timer company: Timer {
        interval: root.companyEvery
        repeat: true
        running: root.hatched && SettingsService.onBar("pet")
            && !LockService.locked && root.mood !== "asleep"
        onTriggered: root.reward(root.companyXp, null)
    }

    // ── STORAGE ─────────────────────────────────────────────────────────────

    // `family` is the source of truth; the adapter is only its copy on disk.
    // A FileView that writes on every adapter change re-applies its own
    // writes, so two changes in one turn (a swap is two) interleave and one is
    // lost, and an adapter property read right after assignment returns the
    // old value. So both fields are mirrored once the turn settles, written
    // in one go, and the file is not watched.
    readonly property Timer saver: Timer {
        interval: 120
        onTriggered: {
            state.family = root.family
            state.active = root.active
            root.file.writeAdapter()
        }
    }

    readonly property FileView file: FileView {
        path: `${SettingsService.stateDirectory}/pet.json`

        onLoaded: root.adopt()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.adopt()
        }

        JsonAdapter {
            id: state

            property var family: []
            property int active: 0
        }
    }

    // Loads the saved family. Otherwise migrates a single-pet save (a flat
    // record the adapter drops, so it is read from the raw text), or lays the
    // first egg.
    function adopt(): void {
        if (root.family.length > 0)
            return
        if (state.family.length > 0) {
            root.family = state.family
            root.active = state.active
            return
        }
        let previous = null
        try {
            previous = JSON.parse(root.file.text())
        } catch (error) {
            previous = null
        }
        // The adapter failed to parse a family that is in the file. Trust the
        // text rather than seed a new egg over it.
        if (previous && previous.family && previous.family.length > 0) {
            root.family = previous.family
            root.active = previous.active ?? 0
            return
        }
        if (previous && previous.species) {
            root.family = [{
                species: previous.species,
                name: previous.name ?? "",
                level: Math.max(1, previous.level ?? 1),
                xp: Math.max(0, previous.xp ?? 0),
                fedAt: previous.fedAt ?? 0,
                playedAt: previous.playedAt ?? 0,
                hatchedAt: previous.hatchedAt ?? 0,
                restedAt: 0
            }]
        } else {
            root.family = [root.newborn([])]
        }
        root.active = 0
        root.saver.restart()
    }
}
