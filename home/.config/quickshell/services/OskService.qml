// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O S K   S E R V I C E                                                  │
// │   on-screen keyboard · its state, its labels and the keys it sends       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keys go out as evdev keycodes through ydotool, so the compositor reads them
// through the user's own layout and no window needs to give up its focus. The
// labels are that same layout's, from `compositor.py keymap`.
Singleton {
    id: root

    property bool open: false
    property bool pinned: false

    // 0 off, 1 for the next key, 2 locked.
    property int shiftMode: 0
    // AltGr, Ctrl and Alt: held for the next key, or let go by a second press.
    property var latched: ({})

    readonly property var shiftKeys: [42, 54]
    readonly property int altGrKey: 100

    // {iso, keys: {keycode: [plain, shift, altgr]}}, for the first layout
    // loaded, which is the one ydotool's device starts in.
    property var keymap: null

    readonly property string layout:
        String(CompositorService.value("input:kb_layout", "us")).split(",")[0].trim() || "us"
    readonly property string variant:
        String(CompositorService.value("input:kb_variant", "")).split(",")[0].trim()

    readonly property bool altGr: root.latched[root.altGrKey] === true

    // The text on a key: the shifted or AltGr level when one is active,
    // falling back to the plain one.
    function label(keycode: int): string {
        const levels = root.keymap?.keys?.[keycode]
        if (!levels)
            return ""
        if (root.altGr && levels[2])
            return levels[2]
        if (root.shiftMode > 0 && levels[1])
            return levels[1]
        return levels[0]
    }

    // The AltGr level drawn small in the corner, as keyboards print it: on
    // digits and signs, and the euro wherever it is. A letter's own third
    // level is left off, or every key would carry one.
    function third(keycode: int): string {
        const levels = root.keymap?.keys?.[keycode]
        if (!levels || root.altGr || !levels[2] || levels[2] === levels[0])
            return ""
        const letter = levels[0].toLowerCase() !== levels[0].toUpperCase()
        return !letter || levels[2] === "€" ? levels[2] : ""
    }

    // Does nothing while the `osk` setting is off.
    function toggle(): void {
        if (SettingsService.osk)
            root.open = !root.open
    }

    onOpenChanged: {
        if (root.open) {
            daemon.running = true
            if (!root.keymap)
                reader.running = true
        } else {
            root.releaseAll()
        }
    }
    onLayoutChanged: root.reload()
    onVariantChanged: root.reload()

    function reload(): void {
        root.keymap = null
        if (root.open)
            reader.running = true
    }

    function send(keys: var): void {
        Quickshell.execDetached(["ydotool", "key", "--key-delay", "0"].concat(keys))
    }

    // A plain key: down and up, with the latched modifiers around it.
    function tap(keycode: int): void {
        root.send([`${keycode}:1`, `${keycode}:0`])
        if (root.shiftMode === 1)
            root.setShift(0)
        if (Object.keys(root.latched).length > 0)
            root.releaseLatched()
    }

    function setShift(mode: int): void {
        if (mode > 0 && root.shiftMode === 0)
            root.send([`${root.shiftKeys[0]}:1`])
        else if (mode === 0 && root.shiftMode > 0)
            root.send(root.shiftKeys.map(code => `${code}:0`))
        root.shiftMode = mode
    }

    function toggleLatch(keycode: int): void {
        const next = Object.assign({}, root.latched)
        if (next[keycode]) {
            delete next[keycode]
            root.send([`${keycode}:0`])
        } else {
            next[keycode] = true
            root.send([`${keycode}:1`])
        }
        root.latched = next
    }

    function releaseLatched(): void {
        root.send(Object.keys(root.latched).map(code => `${code}:0`))
        root.latched = {}
    }

    function releaseAll(): void {
        root.setShift(0)
        root.releaseLatched()
    }

    // ydotoold, as the user unit the package ships; starting it twice is a
    // no-op.
    Process {
        id: daemon

        command: ["systemctl", "--user", "start", "ydotool.service"]
    }

    Process {
        id: reader

        command: [Quickshell.shellPath("scripts/compositor.py"), "keymap", root.layout, root.variant]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keymap = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the keymap:", error)
                }
            }
        }
    }
}
