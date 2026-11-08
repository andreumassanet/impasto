// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I D L E   S E R V I C E                                                │
// │   idle actions · lock, screen off and suspend timeouts                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Idle lock, screen off and suspend, in place of hypridle.
//
// Quickshell's `IdleMonitor` speaks `ext-idle-notify` directly, so timeouts
// follow the settings live with no daemon to restart. A timeout of zero means
// never. `respectInhibitors` lets video players hold all three off.
Singleton {
    id: root

    // Minutes; `IdleMonitor` takes seconds.
    readonly property int lockAfter: SettingsService.idleLock
    readonly property int screenAfter: SettingsService.idleScreen
    readonly property int suspendAfter: SettingsService.idleSuspend

    // Keeps the screen on: while set, none of the three acts. Not stored, so
    // a new session starts as the settings say.
    property bool keepAwake: false

    // A screen already turned off by idle comes back on when keeping awake
    // starts: nothing but this and SUPER + SHIFT + D wakes it.
    onKeepAwakeChanged: {
        if (root.keepAwake)
            root.screen(true)
    }

    readonly property IdleMonitor lockWatch: IdleMonitor {
        enabled: root.lockAfter > 0 && !root.keepAwake
        timeout: root.lockAfter * 60
        respectInhibitors: true

        // `lock()` is a no-op when already locked.
        onIsIdleChanged: {
            if (lockWatch.isIdle)
                LockService.lock()
        }
    }

    readonly property IdleMonitor screenWatch: IdleMonitor {
        enabled: root.screenAfter > 0 && !root.keepAwake
        timeout: root.screenAfter * 60
        respectInhibitors: true
        onIsIdleChanged: root.screen(!screenWatch.isIdle)
    }

    readonly property IdleMonitor sleepWatch: IdleMonitor {
        enabled: root.suspendAfter > 0 && !root.keepAwake
        timeout: root.suspendAfter * 60
        respectInhibitors: true

        // The session action locks and waits for the compositor to confirm
        // before suspending.
        onIsIdleChanged: {
            if (sleepWatch.isIdle)
                SessionService.run("suspend")
        }
    }

    // The dpms dispatcher toggles and ignores the state it is given, so this
    // sends a Lua chunk that reads the monitor and toggles only on mismatch,
    // making both directions idempotent.
    //
    // Waking matters: `key_press_enables_dpms` and `mouse_move_enables_dpms`
    // are off, so only this and `SUPER + SHIFT + D` turn the panel back on.
    // Only the first monitor is handled.
    function screen(on: bool): void {
        const disagrees = on ? "not m.dpms_status" : "m.dpms_status"
        Hyprland.dispatch(`function() local m = hl.get_monitors()[1]`
            + ` if m and ${disagrees} then hl.dispatch(hl.dsp.dpms()) end end`)
    }
}
