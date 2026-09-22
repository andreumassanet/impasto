// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A C C O U N T   S E R V I C E                                          │
// │   current user · name and avatar                                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The account's name and picture, which the lock screen and the login screen
// both show. Changed here, they are changed on the account itself — the full
// name through AccountsService, the picture where the login screen reads it —
// so the two screens never disagree. A name or picture kept only in settings
// is the older way, still honoured, and where the machine cannot share (no
// AccountsService, no `./setup system` since) it is still how they change.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/account.py")

    property string user: ""
    property string systemName: ""
    // The account's full name as it is, "" where none was ever set.
    property string fullName: ""
    property string systemAvatar: ""
    // AccountsService is running, so the full name can be changed.
    property bool accounts: false
    // The picture helper is installed, so the picture can be shared.
    property bool shared: false
    // A change is on its way; "name" or "picture".
    property string busy: ""
    // Why the last change did not happen, or "".
    property string failure: ""

    readonly property string name: SettingsService.userName !== ""
        ? SettingsService.userName
        : (root.systemName !== "" ? root.systemName : root.user)

    readonly property string avatar: SettingsService.userAvatar !== ""
        ? SettingsService.userAvatar
        : root.systemAvatar

    // Drawn when there is no picture: at most two initials.
    readonly property string initials: {
        const words = root.name.trim().split(/\s+/).filter(word => word !== "")
        if (words.length === 0)
            return "?"
        if (words.length === 1)
            return words[0].slice(0, 1).toUpperCase()
        return (words[0].slice(0, 1) + words[words.length - 1].slice(0, 1)).toUpperCase()
    }

    readonly property Process reader: Process {
        command: [root.script, "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    const report = JSON.parse(text)
                    root.user = report.user ?? ""
                    root.systemName = report.name ?? ""
                    root.fullName = report.fullName ?? ""
                    root.systemAvatar = report.avatar ?? ""
                    root.accounts = report.accounts === true
                    root.shared = report.shared === true
                } catch (error) {
                    console.warn("Cannot parse the account:", error)
                }
            }
        }
    }

    function read(): void {
        if (!root.reader.running)
            root.reader.running = true
    }

    // ── CHANGING THEM ───────────────────────────────────────────────────────

    // What changed a picture last, so an image at the same path is read again.
    property int revision: 0

    readonly property Process writer: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.failure = JSON.parse(text).error ?? ""
                } catch (error) {
                    root.failure = "not changed"
                }
            }
        }
        onExited: Qt.callLater(root.settle)
    }

    function settle(): void {
        if (root.busy === "picture" && root.failure === "")
            root.revision += 1
        root.busy = ""
        root.read()
    }

    function write(kind: string, args: var): void {
        root.failure = ""
        root.busy = kind
        root.writer.command = [root.script].concat(args)
        root.writer.running = true
    }

    // The name waits for the typing to stop: one change, not one a key.
    property string pendingName: ""
    readonly property Timer namePause: Timer {
        interval: 800
        onTriggered: {
            if (root.writer.running) {
                restart()
                return
            }
            SettingsService.set("userName", "")
            root.write("name", ["name", root.pendingName])
        }
    }

    function setName(text: string): void {
        if (!root.accounts) {
            SettingsService.set("userName", text)
            return
        }
        root.pendingName = text
        root.namePause.restart()
    }

    function setPicture(path: string): void {
        if (!root.shared) {
            SettingsService.set("userAvatar", path)
            return
        }
        if (root.writer.running)
            return
        SettingsService.set("userAvatar", "")
        root.write("picture", ["picture", path])
    }

    function clearPicture(): void {
        SettingsService.set("userAvatar", "")
        if (root.shared && !root.writer.running)
            root.write("picture", ["picture", "--clear"])
    }
}
