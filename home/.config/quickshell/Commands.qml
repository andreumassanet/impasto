// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O M M A N D S                                                        │
// │   the shell over ipc · what the impasto command calls                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import "./services"

// One IPC target per noun, reached as `qs ipc call <target> <verb> <args>`
// and, more kindly, as `impasto <target> <verb> <args>`. Every answer is a
// line of JSON: `{"ok": true, ...}` or `{"error": "..."}`, so a script or an
// assistant can read what happened and go on. Arguments arrive as strings;
// an optional one arrives empty.
Scope {
    id: root

    // The live bar's island, for the panels.
    property var island: null

    function ok(extra: var): string {
        return JSON.stringify(Object.assign({ ok: true }, extra ?? ({})))
    }

    function fail(message: string): string {
        return JSON.stringify({ error: message })
    }

    // "on", "off" or "toggle" against the current state; null if none.
    function switched(word: string, now: bool): var {
        const said = (word || "toggle").toLowerCase()
        if (["on", "true", "yes", "1"].indexOf(said) >= 0)
            return true
        if (["off", "false", "no", "0"].indexOf(said) >= 0)
            return false
        return said === "toggle" ? !now : null
    }

    // Helpers live here, not in a handler: every function of a handler is a
    // command, and a command takes only plain arguments.
    function noteRow(note: var): var {
        return { key: note.key, title: NotesService.titleOf(note), text: note.text,
                 tint: note.tint, archived: note.archived,
                 edited: new Date(note.edited).toISOString() }
    }

    function taskRow(task: var): var {
        return { key: task.key, text: task.text, notes: task.body, state: task.state,
                 due: task.due, overdue: TasksService.isOverdue(task) }
    }

    // A date as the board reads one: today, tomorrow, fri, 12 oct, +3,
    // 2026-10-12. Empty clears it; null is not a date.
    function day(when: string): var {
        if (!when)
            return ""
        const parsed = TasksService.parseDue(when)
        return parsed !== "" ? parsed : null
    }

    function machineDo(verb: string, name: string): string {
        if (!VmService.find(name))
            return root.fail(`no machine ${name}`)
        VmService.act(verb, name)
        return root.ok({ name: name, asked: verb })
    }

    // ── STATUS ──────────────────────────────────────────────────────────────

    IpcHandler {
        target: "status"

        function get(): string {
            return root.ok({
                timer: TimerService.running
                    ? { label: TimerService.label, left: TimerService.display, paused: TimerService.paused }
                    : null,
                media: MediaService.available
                    ? { title: MediaService.title, artist: MediaService.artist, playing: MediaService.playing }
                    : null,
                notes: NotesService.count,
                tasks: { todo: TasksService.countIn("todo"), doing: TasksService.countIn("doing"),
                         done: TasksService.countIn("done") },
                machines: VmService.running.map(machine => machine.name),
                palette: ThemeService.activeId,
                wallpaper: WallpaperService.chosen,
                layout: CompositorService.windowLayout,
                game: SettingsService.gameMode,
                focus: SettingsService.doNotDisturb,
                nightLight: SunsetService.on,
                volume: AudioService.volume,
                muted: AudioService.muted,
                brightness: BrightnessService.percent
            })
        }
    }

    // ── TIMER ───────────────────────────────────────────────────────────────

    IpcHandler {
        target: "timer"

        function start(duration: string, label: string): string {
            const milliseconds = TimerService.parse(duration)
            if (!(milliseconds > 0))
                return root.fail(`not a duration: "${duration}" (try 25m, 1h30m, 90s or 10:00)`)
            TimerService.start(milliseconds, label)
            return root.ok({ left: TimerService.display, label: TimerService.label })
        }

        function pause(): string {
            if (!TimerService.running)
                return root.fail("no timer is running")
            TimerService.pause()
            return root.ok({ left: TimerService.display })
        }

        function resume(): string {
            if (!TimerService.running)
                return root.fail("no timer is running")
            TimerService.resume()
            return root.ok({ left: TimerService.display })
        }

        function cancel(): string {
            if (!TimerService.running)
                return root.fail("no timer is running")
            TimerService.cancel()
            return root.ok()
        }

        function get(): string {
            return root.ok({ running: TimerService.running, paused: TimerService.paused,
                             label: TimerService.label, left: TimerService.display })
        }
    }

    // ── NOTES ───────────────────────────────────────────────────────────────

    IpcHandler {
        target: "note"

        function add(text: string, title: string, tint: string): string {
            if (!text && !title)
                return root.fail("a note needs some text")
            const tints = ["yellow", "pink", "blue", "green", "orange", "purple"]
            const key = NotesService.add(title || "", text || "", tints.indexOf(tint) >= 0 ? tint : "yellow")
            return root.ok({ key: key })
        }

        function list(): string {
            return root.ok({ notes: NotesService.live.map(note => root.noteRow(note)) })
        }

        function get(key: string): string {
            const note = NotesService.entry(key)
            return note ? root.ok({ note: root.noteRow(note) }) : root.fail(`no note ${key}`)
        }

        function append(key: string, text: string): string {
            const note = NotesService.entry(key)
            if (!note)
                return root.fail(`no note ${key}`)
            NotesService.update(key, { text: note.text ? `${note.text}\n${text}` : text })
            return root.ok({ key: key })
        }

        function archive(key: string): string {
            if (!NotesService.entry(key))
                return root.fail(`no note ${key}`)
            NotesService.archive(key, true)
            return root.ok({ key: key })
        }

        function remove(key: string): string {
            if (!NotesService.entry(key))
                return root.fail(`no note ${key}`)
            NotesService.remove(key)
            return root.ok({ key: key })
        }
    }

    // ── TASKS ───────────────────────────────────────────────────────────────

    IpcHandler {
        target: "task"

        readonly property var states: ["todo", "doing", "done"]

        function add(text: string, due: string, state: string, notes: string): string {
            if (!text)
                return root.fail("a task needs some text")
            const when = root.day(due)
            if (when === null)
                return root.fail(`not a date: "${due}" (try today, tomorrow, fri, 12 oct or 2026-10-12)`)
            if (state && states.indexOf(state) < 0)
                return root.fail(`not a state: "${state}" (todo, doing or done)`)
            const key = TasksService.add(text, when, state || "todo", notes || "")
            return root.ok({ key: key, due: when })
        }

        function list(state: string): string {
            if (state && states.indexOf(state) < 0)
                return root.fail(`not a state: "${state}" (todo, doing or done)`)
            const rows = state ? TasksService.inState(state) : TasksService.tasks
            return root.ok({ tasks: rows.map(task => root.taskRow(task)) })
        }

        function move(key: string, state: string): string {
            if (!TasksService.entry(key))
                return root.fail(`no task ${key}`)
            if (states.indexOf(state) < 0)
                return root.fail(`not a state: "${state}" (todo, doing or done)`)
            TasksService.setState(key, state)
            return root.ok({ key: key, state: state })
        }

        function done(key: string): string {
            return move(key, "done")
        }

        function due(key: string, when: string): string {
            if (!TasksService.entry(key))
                return root.fail(`no task ${key}`)
            const parsed = root.day(when)
            if (parsed === null)
                return root.fail(`not a date: "${when}"`)
            TasksService.setDue(key, parsed)
            return root.ok({ key: key, due: parsed })
        }

        function remove(key: string): string {
            if (!TasksService.entry(key))
                return root.fail(`no task ${key}`)
            TasksService.remove(key)
            return root.ok({ key: key })
        }
    }

    // ── PANELS ──────────────────────────────────────────────────────────────

    IpcHandler {
        target: "panel"

        readonly property var names: ["launcher", "controls", "overview", "appearance", "palette",
            "stats", "session", "pet", "games", "notes", "board", "keys", "packages",
            "machines", "wifi", "bluetooth", "sound", "microphone", "brightness", "nightlight"]

        function open(name: string): string {
            if (names.indexOf(name) < 0)
                return root.fail(`not a panel: "${name}" (${names.join(", ")})`)
            root.island?.open(name)
            return root.ok({ panel: name })
        }

        function close(): string {
            root.island?.close()
            return root.ok()
        }

        function list(): string {
            return root.ok({ panels: names })
        }
    }

    // ── VIRTUAL MACHINES ────────────────────────────────────────────────────

    IpcHandler {
        target: "machine"

        function list(): string {
            return root.ok({ machines: VmService.machines.map(machine => ({
                name: machine.name, title: machine.title, running: machine.running,
                paused: machine.paused, cores: machine.cores, memory: machine.ram
            })) })
        }

        function start(name: string): string { return root.machineDo("start", name) }
        function stop(name: string): string { return root.machineDo("stop", name) }
        function kill(name: string): string { return root.machineDo("kill", name) }
        function pause(name: string): string { return root.machineDo("pause", name) }
        function resume(name: string): string { return root.machineDo("resume", name) }
        function open(name: string): string { return root.machineDo("open", name) }
    }

    // ── MUSIC ───────────────────────────────────────────────────────────────

    IpcHandler {
        target: "media"

        function get(): string {
            return root.ok({ media: MediaService.available
                ? { title: MediaService.title, artist: MediaService.artist,
                    player: MediaService.identity, playing: MediaService.playing }
                : null })
        }

        function play(): string {
            if (!MediaService.available)
                return root.fail("nothing to play")
            if (!MediaService.playing)
                MediaService.toggle()
            return root.ok({ playing: true })
        }

        function pause(): string {
            if (!MediaService.available)
                return root.fail("nothing is playing")
            if (MediaService.playing)
                MediaService.toggle()
            return root.ok({ playing: false })
        }

        function toggle(): string {
            if (!MediaService.available)
                return root.fail("nothing to play")
            const playing = !MediaService.playing
            MediaService.toggle()
            return root.ok({ playing: playing })
        }

        function next(): string {
            if (!MediaService.canNext)
                return root.fail("no next track")
            MediaService.next()
            return root.ok()
        }

        function prev(): string {
            if (!MediaService.canPrevious)
                return root.fail("no previous track")
            MediaService.previous()
            return root.ok()
        }
    }

    // ── CAPTURE ─────────────────────────────────────────────────────────────

    // The interactive ones: the capture surface, as its key opens it. A
    // shot of the whole screen to a file needs no shell, and the command
    // takes it itself.
    IpcHandler {
        target: "capture"

        function open(shape: string): string {
            if (CaptureService.shapes.indexOf(shape) < 0)
                return root.fail(`not a shape: "${shape}" (${CaptureService.shapes.join(", ")})`)
            CaptureService.open(shape, "photo", "file", CaptureService.settle)
            return root.ok({ shape: shape })
        }
    }

    // ── THE DESK ────────────────────────────────────────────────────────────

    IpcHandler {
        target: "game"

        function set(word: string): string {
            const on = root.switched(word, SettingsService.gameMode)
            if (on === null)
                return root.fail("on, off or toggle")
            SettingsService.set("gameMode", on)
            return root.ok({ game: on })
        }
    }

    IpcHandler {
        target: "layout"

        function set(name: string): string {
            const ids = CompositorService.windowLayouts.map(entry => entry.id)
            if (name === "next" || name === "") {
                CompositorService.cycleLayout()
                return root.ok({ layout: CompositorService.windowLayout })
            }
            if (ids.indexOf(name) < 0)
                return root.fail(`not a layout: "${name}" (${ids.join(", ")} or next)`)
            CompositorService.remember("general:layout", name)
            return root.ok({ layout: name })
        }
    }

    IpcHandler {
        target: "focus"

        function set(word: string): string {
            const on = root.switched(word, SettingsService.doNotDisturb)
            if (on === null)
                return root.fail("on, off or toggle")
            if (on !== SettingsService.doNotDisturb)
                NotificationService.toggleDoNotDisturb()
            return root.ok({ focus: on })
        }
    }

    IpcHandler {
        target: "nightlight"

        function set(word: string): string {
            const on = root.switched(word, SunsetService.on)
            if (on === null)
                return root.fail("on, off or toggle")
            if (!SunsetService.available)
                return root.fail("the night light needs hyprsunset")
            if (on !== SunsetService.on)
                SunsetService.toggle()
            return root.ok({ nightLight: on })
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            SettingsService.set("barHidden", !SettingsService.barHidden)
        }
    }

    IpcHandler {
        target: "widgets"

        function toggle(): void {
            SettingsService.set("desktopHidden", !SettingsService.desktopHidden)
        }
    }

    // ── SOUND AND LIGHT ─────────────────────────────────────────────────────

    IpcHandler {
        target: "volume"

        function set(percent: string): string {
            const value = parseInt(percent)
            if (isNaN(value) || value < 0 || value > 100)
                return root.fail("a volume from 0 to 100")
            AudioService.setVolume(value)
            return root.ok({ volume: value })
        }

        function mute(word: string): string {
            const on = root.switched(word, AudioService.muted)
            if (on === null)
                return root.fail("on, off or toggle")
            if (on !== AudioService.muted)
                AudioService.toggleMute()
            return root.ok({ muted: on })
        }

        function get(): string {
            return root.ok({ volume: AudioService.volume, muted: AudioService.muted })
        }
    }

    IpcHandler {
        target: "brightness"

        function set(percent: string): string {
            const value = parseInt(percent)
            if (isNaN(value) || value < 0 || value > 100)
                return root.fail("a brightness from 0 to 100")
            BrightnessService.setPercent(value)
            return root.ok({ brightness: value })
        }

        function get(): string {
            return root.ok({ brightness: BrightnessService.percent })
        }
    }

    // ── LOOKS ───────────────────────────────────────────────────────────────

    IpcHandler {
        target: "theme"

        function list(): string {
            return root.ok({ current: ThemeService.activeId,
                             palettes: ThemeService.availableThemes.map(entry => ({ id: entry.id, name: entry.name })) })
        }

        function set(id: string): string {
            if (!ThemeService.availableThemes.some(entry => entry.id === id))
                return root.fail(`not a palette: "${id}" (impasto theme list)`)
            ThemeService.setTheme(id)
            return root.ok({ palette: id })
        }
    }

    IpcHandler {
        target: "wallpaper"

        // Kept as it was: Thunar's "Set as Wallpaper" calls it.
        function set(path: string): string {
            if (!path)
                return "usage: qs ipc call wallpaper set <path>"
            WallpaperService.apply(path)
            return path
        }

        function list(): string {
            return root.ok({ current: WallpaperService.chosen,
                             wallpapers: WallpaperService.wallpapers.concat(WallpaperService.animated) })
        }

        function random(): string {
            const all = WallpaperService.wallpapers.filter(path => path !== WallpaperService.chosen)
            if (all.length === 0)
                return root.fail("no other wallpaper")
            const path = all[Math.floor(Math.random() * all.length)]
            WallpaperService.apply(path)
            return root.ok({ wallpaper: path })
        }
    }

    // ── THE ISLAND SAYS SOMETHING ───────────────────────────────────────────

    IpcHandler {
        target: "osd"

        // Not `show`: `qs ipc show` is a command of its own.
        function say(text: string, icon: string): string {
            if (!text)
                return root.fail("say something")
            OsdService.requested(icon || "󰍡", text, -1)
            return root.ok()
        }
    }

    // ── SESSION ─────────────────────────────────────────────────────────────

    IpcHandler {
        target: "lock"

        function lock(): string {
            LockService.lock()
            return root.ok()
        }
    }

    IpcHandler {
        target: "shell"

        function reload(): void {
            Quickshell.reload(false)
        }
    }
}
