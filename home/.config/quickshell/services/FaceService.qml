// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   F A C E   S E R V I C E                                                │
// │   face unlock · what the machine has, the faces kept, add and try        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// howdy keeps its models where only root reads them, so the faces are listed,
// added and removed through /usr/lib/impasto/face under pkexec: listing asks
// nothing of the active user, adding or removing asks for their password.
// Trying a face needs no root at all — it is the lock screen's own PAM
// conversation, `impasto-face`, run here.
Singleton {
    id: root

    // ── WHAT THE MACHINE HAS ────────────────────────────────────────────────

    // An infrared camera, which is all howdy can use.
    property bool camera: false
    // howdy itself, from `./setup face`.
    property bool installed: false
    // The helper, its policy and the lock's PAM service, from `./setup system`.
    property bool wired: false
    // The checks have come back.
    property bool known: false

    readonly property bool ready: root.camera && root.installed && root.wired

    readonly property Process probe: Process {
        command: ["sh", "-c",
            "camera=0; for d in /dev/video*; do [ -c \"$d\" ] || continue; "
            + "v4l2-ctl -d \"$d\" --list-formats 2>/dev/null | grep -q \"'GREY'\" && camera=1 && break; done; "
            + "installed=0; command -v howdy >/dev/null && installed=1; "
            + "wired=0; test -x /usr/lib/impasto/face "
            + "&& test -f /usr/share/polkit-1/actions/org.impasto.face.policy "
            + "&& test -f /etc/pam.d/impasto-face && test -f /usr/lib/security/pam_howdy.so && wired=1; "
            + "echo $camera $installed $wired"]
        stdout: StdioCollector {
            onStreamFinished: {
                const bits = text.trim().split(" ")
                root.camera = bits[0] === "1"
                root.installed = bits[1] === "1"
                root.wired = bits[2] === "1"
                root.known = true
                if (root.ready)
                    root.list()
            }
        }
    }

    function refresh(): void {
        if (!root.probe.running)
            root.probe.running = true
    }

    // What is missing is the installer's to put there, in the terminal every
    // command that asks for a password runs in: `face` for howdy and the
    // first face, `system` for the helper and its policy.
    readonly property Process installer: Process {
        onExited: root.refresh()
    }

    function install(verb: string): void {
        if (VersionService.repo === "" || root.installer.running)
            return
        root.installer.command = ["kitty", "--class", "impasto-update",
                                  "--title", `impasto ${verb}`,
                                  "sh", "-c", PackagesService.holdScript, "sh",
                                  `${VersionService.repo}/setup`, verb]
        root.installer.running = true
    }

    // ── THE FACES ───────────────────────────────────────────────────────────

    // `{ id, added, label }`, as howdy lists them; `added` is "YYYY-MM-DD hh:mm:ss".
    property var faces: []
    // The list has been read at least once since the machine was ready.
    property bool listed: false

    readonly property Process lister: Process {
        command: ["pkexec", "/usr/lib/impasto/face", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.faces = text.split("\n").filter(line => /^\d+,/.test(line)).map(root.parse)
                root.listed = true
            }
        }
    }

    // One CSV line: an id, the time, and a label quoted only when it has to be.
    function parse(line: string): var {
        const first = line.indexOf(",")
        const second = line.indexOf(",", first + 1)
        let label = line.slice(second + 1)
        if (label.startsWith("\"") && label.endsWith("\""))
            label = label.slice(1, -1).replace(/""/g, "\"")
        return { id: Number(line.slice(0, first)), added: line.slice(first + 1, second), label: label }
    }

    function list(): void {
        if (root.ready && !root.lister.running)
            root.lister.running = true
    }

    // ── CHANGING THEM ───────────────────────────────────────────────────────

    // "adding", "removing", or "" at rest.
    property string busy: ""
    // How the last add went: "", "added", or why it did not.
    property string outcome: ""

    // What howdy said on stderr, read when the stream ends rather than when
    // the process does, which can come first.
    property string complaint: ""

    readonly property Process changer: Process {
        stderr: StdioCollector {
            onStreamFinished: root.complaint = text
        }
        onExited: code => Qt.callLater(() => root.settle(code))
    }

    function settle(code: int): void {
        const was = root.busy
        root.busy = ""
        // 126 and 127 are pkexec's: the password dialog dismissed, or not
        // authorised. Nothing was tried, so nothing is reported.
        if (was === "adding")
            root.outcome = code === 0 ? "added"
                : code === 126 || code === 127 ? "" : root.reason(root.complaint)
        root.list()
    }

    // howdy's own words for a failed scan, down to the few worth telling apart.
    function reason(text: string): string {
        if (/No face detected/.test(text))
            return "no face"
        if (/Multiple faces/.test(text))
            return "several faces"
        if (/dark|black frames|bright/i.test(text))
            return "too dark"
        return "failed"
    }

    function add(): void {
        if (!root.ready || root.busy !== "")
            return
        root.outcome = ""
        root.complaint = ""
        root.busy = "adding"
        root.changer.command = ["pkexec", "/usr/lib/impasto/face", "add"]
        root.changer.running = true
    }

    function remove(id: int): void {
        if (!root.ready || root.busy !== "")
            return
        root.busy = "removing"
        root.changer.command = ["pkexec", "/usr/lib/impasto/face", "remove", String(id)]
        root.changer.running = true
    }

    // ── TRYING ONE ──────────────────────────────────────────────────────────

    // "", "looking", "matched" or "missed".
    property string trial: ""

    readonly property PamContext tryout: PamContext {
        config: "impasto-face"

        onPamMessage: root.trial = "looking"
        onCompleted: result => root.trial = result === PamResult.Success ? "matched" : "missed"
        onError: error => {
            console.warn("PAM error while trying a face:", error)
            root.trial = "missed"
        }
    }

    function tryFace(): void {
        if (!root.ready || root.tryout.active || root.faces.length === 0)
            return
        root.trial = "looking"
        root.tryout.start()
    }
}
