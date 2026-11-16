// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M A C H I N E   S E R V I C E                                          │
// │   hardware and os summary                                                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Static facts about the machine: distribution, kernel, compositor, login
// shell, host and package count. Read on request (each time the control
// centre block is built) rather than polled. Unknown fields stay empty and
// `packages` stays null.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/machine.py")

    property bool ready: false
    property string os: ""
    property string kernel: ""
    property string host: ""
    property string wm: ""
    property string shell: ""
    property var packages: null
    // The distribution's logo as a file, and what fastfetch adds.
    property string logo: ""
    property string model: ""
    property var gpus: []

    function refresh(): void {
        if (root.reader.running)
            return
        root.reader.running = true
    }

    readonly property Process reader: Process {
        command: [root.script, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    const report = JSON.parse(text)
                    root.os = report.os ?? ""
                    root.kernel = report.kernel ?? ""
                    root.host = report.host ?? ""
                    root.wm = report.wm ?? ""
                    root.shell = report.shell ?? ""
                    root.packages = typeof report.packages === "number" ? report.packages : null
                    root.logo = report.logo ?? ""
                    root.model = report.model ?? ""
                    root.gpus = report.gpus ?? []
                    root.ready = true
                } catch (error) {
                    console.warn("Cannot parse the machine report:", error)
                }
            }
        }
    }
}
