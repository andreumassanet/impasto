// The on-screen keyboard's state and its keys, sent with ydotool
// (end_4 ii's OSK, services/Ydotool.qml). `shiftMode`: 0 off, 1 once, 2 locked.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool open: false
    property bool pinned: false
    property int shiftMode: 0

    readonly property var shiftKeys: [42, 54]

    // Does nothing while the `osk` setting is off.
    function toggle(): void {
        if (SettingsService.osk)
            root.open = !root.open
    }

    onOpenChanged: {
        if (!root.open)
            root.releaseAllKeys()
    }

    function send(keys: var): void {
        Quickshell.execDetached(["ydotool", "key", "--key-delay", "0"].concat(keys))
    }

    function press(keycode: int): void {
        root.send([`${keycode}:1`])
    }

    function release(keycode: int): void {
        root.send([`${keycode}:0`])
    }

    function releaseShiftKeys(): void {
        root.send(root.shiftKeys.map(keycode => `${keycode}:0`))
        root.shiftMode = 0
    }

    function releaseAllKeys(): void {
        root.send(Array.from(Array(249).keys()).map(keycode => `${keycode}:0`))
        root.shiftMode = 0
    }
}
