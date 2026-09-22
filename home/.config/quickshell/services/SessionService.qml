// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E S S I O N   S E R V I C E                                          │
// │   lock, suspend, log out, reboot, shut down                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Session actions as data, rendered from one list. `destructive` marks the
// ones that end the session; PowerRow asks for confirmation, not this service.
Singleton {
    id: root

    readonly property var actions: [
        { id: "lock",     icon: "󰌾", label: "Lock",      destructive: false },
        { id: "suspend",  icon: "󰤄", label: "Suspend",   destructive: false },
        { id: "logout",   icon: "󰗽", label: "Log out",   destructive: true },
        { id: "reboot",   icon: "󰜉", label: "Restart",   destructive: true },
        { id: "shutdown", icon: "󰐥", label: "Shut down", destructive: true }
    ]

    readonly property Process runner: Process {}

    // Suspend only after the compositor confirms the lock, so the machine
    // never wakes showing the desktop. No confirmation within five seconds
    // means no suspend.
    property bool suspendWhenLocked: false

    readonly property Timer suspendGiveUp: Timer {
        interval: 5000
        onTriggered: {
            if (!root.suspendWhenLocked)
                return
            root.suspendWhenLocked = false
            console.warn("The session did not lock; not suspending.")
        }
    }

    readonly property Connections lockWatch: Connections {
        target: LockService

        function onSecureChanged(): void {
            if (LockService.secure && root.sleepPending) {
                root.sleepPending = false
                root.sleepHold.running = false
            }
            if (!LockService.secure || !root.suspendWhenLocked)
                return
            root.suspendWhenLocked = false
            root.suspendGiveUp.stop()
            root.exec(["systemctl", "suspend"])
        }
    }

    // ── SLEEP ───────────────────────────────────────────────────────────────

    // Every sleep locks first — the lid, a key, `systemctl suspend` — so the
    // machine never wakes on the desktop. A delay inhibitor makes logind wait
    // for the lock, at most InhibitDelayMaxSec (5 s by default), and is let go
    // once the compositor confirms it; waking takes it again.
    property bool sleepPending: false

    // `cat` waits on the shell's end of stdin, so the hold never outlives the
    // shell.
    readonly property Process sleepHold: Process {
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay",
            "--who=impasto", "--why=Locking the screen first", "cat"]
        stdinEnabled: true
        running: true
    }

    // logind's PrepareForSleep, true before sleeping and false after waking.
    readonly property Process sleepWatch: Process {
        command: ["dbus-monitor", "--system",
            "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const found = line.match(/^\s*boolean (true|false)$/)
                if (found)
                    root.sleeping(found[1] === "true")
            }
        }
    }

    function sleeping(going: bool): void {
        if (!going) {
            root.sleepPending = false
            root.sleepHold.running = true
            return
        }
        if (LockService.secure) {
            root.sleepHold.running = false
            return
        }
        root.sleepPending = true
        LockService.lock()
    }

    function run(actionId: string): void {
        switch (actionId) {
        case "lock":
            LockService.lock()
            break
        case "suspend":
            // Already locked (the idle service): `lock()` would be a no-op
            // and `secure` would never change.
            if (LockService.secure) {
                root.exec(["systemctl", "suspend"])
                break
            }
            root.suspendWhenLocked = true
            root.suspendGiveUp.restart()
            LockService.lock()
            break
        case "logout":
            Hyprland.dispatch("hl.dsp.exit()")
            break
        case "reboot":
            root.exec(["systemctl", "reboot"])
            break
        case "shutdown":
            root.exec(["systemctl", "poweroff"])
            break
        default:
            console.warn("Unknown session action:", actionId)
        }
    }

    function exec(command: var): void {
        root.runner.command = command
        root.runner.running = true
    }
}
