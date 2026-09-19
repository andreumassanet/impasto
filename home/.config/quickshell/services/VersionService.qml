// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   V E R S I O N   S E R V I C E                                          │
// │   what is installed · and what the checkout it came from has waiting     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Two halves of one figure. What `setup sync` recorded — the version, the
// branch, and the checkout the copy came from — and what `version.py` finds
// that checkout's remote has since. Nothing is pulled from here: the update
// runs in a terminal, because it asks for a password and ends by reloading
// this shell.
Singleton {
    id: root

    // Half an hour, the pending packages' own interval: opening the page
    // again within it reads the last answer rather than the network.
    readonly property int freshness: 1800000

    // ── WHAT IS INSTALLED ───────────────────────────────────────────────────
    //
    // The version, the branch it came from, and the checkout it was copied
    // out of, a line each. Missing until the first sync, and without the
    // third line on a desk last synced by an older installer.

    readonly property FileView file: FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/impasto/version`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.checkStale()
    }

    readonly property var lines: (root.file.loaded ? root.file.text() : "").trim().split("\n")
    readonly property string version: (root.lines[0] ?? "").trim()
    readonly property string branch: (root.lines[1] ?? "").trim()
    readonly property string repo: (root.lines[2] ?? "").trim()

    // ── WHAT IS WAITING ─────────────────────────────────────────────────────

    // A check has come back, whatever it said.
    property bool answered: false
    // The checkout is there, and it is a repository. A path recorded by a
    // sync and since deleted is the case this tells apart.
    property bool available: false
    property bool checking: false
    // The remote did not answer. The counts below are then the last fetch's.
    property bool offline: false

    property int behind: 0
    // Commits of your own the remote has not: what stops a fast-forward.
    property int ahead: 0
    property string upstream: ""
    // What the version would read after the update, `git describe`'s shape.
    property string target: ""
    // `{ hash, subject }`, newest first, the first few of `behind`.
    property var commits: []
    // 0 until the first answer.
    property real checkedAt: 0

    function check(): void {
        if (root.checking || root.repo === "")
            return
        root.checking = true
        root.query.command = [Quickshell.shellPath("scripts/version.py"),
                              "check", root.repo]
        root.query.running = true
    }

    // What opening the page asks for: the network only when the last answer
    // is old enough to be worth another.
    function checkStale(): void {
        if (root.checkedAt <= 0 || Date.now() - root.checkedAt > root.freshness)
            root.check()
    }

    readonly property Process query: Process {
        onExited: root.checking = false
        stdout: StdioCollector {
            onStreamFinished: {
                let report = null
                try {
                    report = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the version report:", error)
                    return
                }
                root.answered = true
                root.available = report.available === true
                if (!root.available) {
                    root.behind = 0
                    root.ahead = 0
                    root.target = ""
                    root.commits = []
                    // `checkedAt` stays where it was, so opening the page
                    // asks again: a checkout that comes back is found.
                    return
                }
                root.upstream = report.upstream ?? ""
                root.behind = report.behind ?? 0
                root.ahead = report.ahead ?? 0
                root.target = report.target ?? ""
                root.commits = report.commits ?? []
                root.offline = report.offline === true
                root.checkedAt = Date.now()
            }
        }
    }

    // ── THE UPDATE ──────────────────────────────────────────────────────────

    // Detached, never a `Process`: the install ends by reloading this shell,
    // and a child of it would go with the reload halfway through.
    //
    // The packages panel's terminal, down to the line it ends on: one window
    // for everything the shell hands to a command that asks questions and
    // wants a password. The window rule floats it, and the path goes in as an
    // argument rather than spliced into the script.
    function update(): void {
        if (root.repo === "")
            return
        Quickshell.execDetached(["kitty", "--class", "impasto-update",
                                 "--title", "impasto update",
                                 "sh", "-c", PackagesService.holdScript, "sh",
                                 `${root.repo}/setup`, "update"])
    }
}
