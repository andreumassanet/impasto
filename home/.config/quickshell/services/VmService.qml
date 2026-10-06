// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   V M   S E R V I C E                                                    │
// │   virtual machines · what there is, what runs, what is being fetched     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The machines `vms.py` keeps, read once at start (one may be running from
// before the shell) and then while one runs or the panel is open. The
// catalogue is read on the first open of the New tab; a fetch streams its
// progress here while the panel is closed too.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/vms.py")

    property var machines: []
    property var tools: ({})
    property int hostCores: 1
    property real hostMemory: 0
    property bool loaded: false

    readonly property bool ready: (root.tools.quickemu ?? false) && (root.tools.quickget ?? false)
    readonly property var running: root.machines.filter(machine => machine.running)
    readonly property int coresInUse: root.running.reduce(
        (total, machine) => total + (parseInt(machine.cores) || 0), 0)
    readonly property real memoryInUse: root.running.reduce(
        (total, machine) => total + (parseInt(machine.ram) || 0), 0)

    // The last thing that went wrong, said once on the panel.
    property string error: ""

    // Panels and glances that want live numbers.
    property int watchers: 0

    function subscribe(): void {
        root.watchers += 1
        root.refresh()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    // ── THE LIST ────────────────────────────────────────────────────────────

    readonly property Process lister: Process {
        command: [root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const state = JSON.parse(text)
                    root.machines = state.machines ?? []
                    root.tools = state.tools ?? ({})
                    root.hostCores = state.cores ?? 1
                    root.hostMemory = state.memory ?? 0
                    root.loaded = true
                } catch (error) {
                    console.warn("Cannot read the machines:", error)
                }
            }
        }
    }

    function refresh(): void {
        if (!root.lister.running)
            root.lister.running = true
    }

    // A machine shut down from inside notices nothing here; the list is read
    // again while one runs, and while the panel is up.
    readonly property Timer tick: Timer {
        interval: 3000
        repeat: true
        running: root.running.length > 0 || root.watchers > 0
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    // How long a machine has run, from the start `vms.py` reports. The list
    // is read every few seconds while one runs, which keeps this current.
    function uptime(started: int): string {
        if (started <= 0)
            return ""
        const seconds = Math.max(0, Math.floor(Date.now() / 1000) - started)
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor(seconds / 60) % 60
        return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")} h` : `${minutes} min`
    }

    function find(name: string): var {
        return root.machines.find(machine => machine.name === name) ?? null
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────

    // One at a time; each reads the list again when it is done.
    readonly property Process actor: Process {
        stdout: SplitParser {
            onRead: line => {
                try {
                    const reply = JSON.parse(line)
                    if (reply.error)
                        root.error = reply.error
                } catch (error) {}
            }
        }
        onExited: root.refresh()
    }

    property string busy: ""

    // One action at a time; false when another is still running, so a
    // caller can say so rather than report it done.
    function act(verb: string, name: string, extra: var): bool {
        if (root.actor.running)
            return false
        root.error = ""
        root.busy = name
        root.actor.command = [root.script, verb, name].concat(extra ?? [])
        root.actor.running = true
        return true
    }

    readonly property Connections done: Connections {
        target: root.actor
        function onRunningChanged(): void {
            if (!root.actor.running)
                root.busy = ""
        }
    }

    function start(name: string): void { root.act("start", name) }
    function open(name: string): void { root.act("open", name) }
    function pause(name: string): void { root.act("pause", name) }
    function resume(name: string): void { root.act("resume", name) }
    function stop(name: string): void { root.act("stop", name) }
    function kill(name: string): void { root.act("kill", name) }
    function remove(name: string): void { root.act("delete", name) }
    function snapshot(name: string, verb: string, tag: string): void { root.act("snapshot", name, [verb, tag]) }
    function setCores(name: string, cores: int): void { root.act("set", name, ["cores", String(cores)]) }
    function setMemory(name: string, gigabytes: int): void { root.act("set", name, ["ram", String(gigabytes)]) }

    // ── THE CATALOGUE ───────────────────────────────────────────────────────

    property var catalog: []
    readonly property bool catalogLoading: root.catalogReader.running

    readonly property Process catalogReader: Process {
        command: [root.script, "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.catalog = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot read the catalogue:", error)
                }
            }
        }
    }

    function loadCatalog(): void {
        if (root.catalog.length === 0 && !root.catalogReader.running)
            root.catalogReader.running = true
    }

    // ── FETCHING ONE ────────────────────────────────────────────────────────

    // { title, os, release, edition, progress } while quickget runs.
    property var fetching: null

    readonly property Process fetcher: Process {
        stdout: SplitParser {
            onRead: line => {
                try {
                    const reply = JSON.parse(line)
                    if (reply.progress !== undefined && root.fetching)
                        root.fetching = Object.assign({}, root.fetching, { progress: reply.progress })
                    else if (reply.error)
                        root.error = reply.error
                } catch (error) {}
            }
        }
        onExited: {
            root.fetching = null
            root.refresh()
        }
    }

    function create(system: var, release: string, edition: string,
                    cores: int, memory: int, disk: int): void {
        if (root.fetcher.running)
            return
        root.error = ""
        const title = [system.name, release, edition].filter(part => part !== "").join(" ")
        root.fetching = { title: title, os: system.os, release: release,
                          edition: edition, progress: 0 }
        root.fetcher.command = [root.script, "create", system.os, release]
            .concat(edition !== "" ? [edition] : [])
            .concat(["--cores", String(cores), "--ram", String(memory),
                     "--disk", String(disk), "--title", title])
        root.fetcher.running = true
    }

    function cancelCreate(): void {
        if (root.fetcher.running)
            root.fetcher.signal(15)
    }

    // ── HOW EACH SYSTEM LOOKS ───────────────────────────────────────────────

    // A Nerd Font mark for the systems it has one for; the rest are a
    // generic screen.
    readonly property var marks: ({
        "alma": "", "alpine": "", "android": "󰀲", "archcraft": "",
        "archlinux": "", "artixlinux": "", "biglinux": "", "cachyos": "",
        "centos-stream": "", "debian": "", "deepin": "", "devuan": "",
        "edubuntu": "", "elementary": "", "endeavouros": "",
        "fedora": "", "freebsd": "", "freedos": "󰉉", "garuda": "",
        "gentoo": "", "gnomeos": "", "guix": "", "kali": "",
        "kdeneon": "", "kolibrios": "󰉉", "kubuntu": "", "linuxmint": "",
        "lmde": "", "lubuntu": "", "macos": "", "mageia": "",
        "manjaro": "", "mxlinux": "", "nixos": "", "openbsd": "",
        "opensuse": "", "parrotsec": "", "popos": "", "reactos": "󰖳",
        "rockylinux": "", "slackware": "", "solus": "", "tails": "",
        "trisquel": "", "ubuntu": "", "ubuntu-budgie": "",
        "ubuntu-mate": "", "ubuntu-server": "", "ubuntu-unity": "",
        "ubuntucinnamon": "", "ubuntukylin": "", "ubuntustudio": "",
        "vanillaos": "", "void": "", "windows": "󰖳", "windows-server": "󰖳",
        "xubuntu": "", "zorin": ""
    })

    function mark(system: string): string {
        return root.marks[system] ?? "󰍹"
    }
}
