// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L O C K   S E R V I C E                                                │
// │   session lock state · background capture and authentication             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

import "../theme"

// Locks the session through ext-session-lock instead of an external locker,
// so the desktop can stay on screen behind the lock, blurred.
//
// The screenshot is a grim process rather than a ScreencopyView because it
// has to finish before the lock surface is mapped. It goes to the runtime
// directory (tmpfs, user-only) and is deleted on unlock.
//
// The password is handed straight to PAM's `respond` and never stored. A face
// is a second PAM conversation beside it, where `./setup face` has put howdy.
Singleton {
    id: root

    property bool locked: false

    // `locked` is the request; this is the compositor confirming the screen
    // is covered.
    property bool secure: false

    property bool authenticating: false
    property string message: ""
    property bool failed: false

    // From the moment the lock is answered until the surface has let go of
    // the desktop; `locked` falls after it.
    property bool leaving: false

    // Two stages, shared by every screen: at rest the clock alone, awake the
    // account, the field and the power buttons. A key or a click wakes it,
    // Escape or a while untouched puts it back.
    property bool awake: false

    // How long an awake screen waits untouched before going back to its
    // clock.
    readonly property int awakeFor: 30000

    function rouse(): void {
        if (!root.locked || root.leaving)
            return
        root.awake = true
        root.drowse.restart()
    }

    // Surfaces clear their field when this falls.
    function rest(): void {
        root.drowse.stop()
        root.awake = false
        root.failed = false
        root.message = ""
    }

    readonly property Timer drowse: Timer {
        interval: root.awakeFor
        // A password being checked is not a screen left alone.
        onTriggered: root.authenticating ? root.drowse.restart() : root.rest()
    }

    readonly property string shotDirectory:
        `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/quickshell`
    readonly property string shotPath: `${root.shotDirectory}/lock.jpg`

    // Bumped per capture so the Image source changes and Qt does not serve
    // the previous lock's cached frame.
    property int shotSerial: 0
    property bool shotReady: false

    readonly property string shotSource:
        root.shotReady ? `file://${root.shotPath}?v=${root.shotSerial}` : ""

    signal unlocked()

    // ── LOCKING ─────────────────────────────────────────────────────────────

    // False while a panel is still on screen and would end up in the
    // screenshot. Bound in `shell.qml`, which can see the bar.
    property bool shellQuiet: true

    property bool pendingCapture: false

    function lock(): void {
        if (root.locked)
            return
        root.message = ""
        root.failed = false
        root.leaving = false
        root.rest()
        root.faceScanning = false
        root.faceMatched = false
        root.faceCheck.running = true
        root.shotReady = false
        // Capture first, surface second — and only once the island has
        // closed, or the screenshot shows the panel the lock came from.
        root.pendingCapture = true
        root.attemptCapture()
    }

    function attemptCapture(): void {
        if (!root.pendingCapture)
            return
        if (!root.shellQuiet) {
            root.settleFrame.stop()
            root.quietGiveUp.restart()
            return
        }
        root.settleFrame.restart()
    }

    onShellQuietChanged: root.attemptCapture()

    // grim reads the compositor, not this scene graph, and there is no signal
    // for "the frame is on screen": two frames at 60 Hz.
    readonly property Timer settleFrame: Timer {
        interval: 32
        onTriggered: root.beginCapture()
    }

    // Lock anyway if the shell never settles: an untidy screenshot is better
    // than an unlocked machine.
    readonly property Timer quietGiveUp: Timer {
        interval: 900
        onTriggered: {
            console.warn("The shell did not settle; locking with whatever is on screen.")
            root.beginCapture()
        }
    }

    function beginCapture(): void {
        if (!root.pendingCapture)
            return
        root.pendingCapture = false
        root.settleFrame.stop()
        root.quietGiveUp.stop()
        root.capture.running = true
    }

    // grim hangs instead of failing when the output is already powered off,
    // and the lock only goes up in `onExited`, hence the timeout. JPEG, since
    // the picture is shown blurred and PNG takes seconds over a painting on a
    // large or doubled screen.
    readonly property Process capture: Process {
        command: ["sh", "-c",
            `mkdir -p '${root.shotDirectory}' && timeout 2 grim -t jpeg -q 90 '${root.shotPath}'`]

        // Lock whether or not the screenshot worked.
        onExited: (code, status) => {
            root.shotSerial += 1
            root.shotReady = code === 0
            root.locked = true
            root.faceMisses = 0
            root.faceQuietUntil = 0
            root.begin()
        }
    }

    function forget(): void {
        root.shotReady = false
        root.eraser.running = true
    }

    readonly property Process eraser: Process {
        command: ["rm", "-f", root.shotPath]
    }

    // ── AUTHENTICATING ──────────────────────────────────────────────────────

    // A PAM conversation ends after a refusal, so every attempt starts a new
    // one.
    function begin(): void {
        if (pam.active)
            pam.abort()
        root.authenticating = false
        pam.start()
    }

    function submit(password: string): void {
        if (root.authenticating || root.leaving)
            return
        // Enter on an empty field asks for the camera instead.
        if (password === "") {
            root.scan()
            return
        }
        root.failed = false
        root.message = ""

        // PAM has normally asked by now. If not, restart it and let the user
        // retry rather than keep the password around until it does.
        if (!pam.responseRequired) {
            root.begin()
            root.message = "Not ready — press Enter again"
            return
        }

        root.authenticating = true
        pam.respond(password)
    }

    readonly property PamContext pam: PamContext {
        // The same stack hyprlock's PAM file includes.
        config: "login"

        onCompleted: result => {
            root.authenticating = false
            if (result === PamResult.Success) {
                root.release()
                return
            }
            // The face got there first; the lock is already on its way out.
            if (root.leaving || root.faceMatched)
                return
            root.failed = true
            root.message = result === PamResult.MaxTries
                ? "Too many attempts"
                : "Wrong password"
            root.begin()
        }

        onError: error => {
            root.authenticating = false
            root.failed = true
            root.message = "Authentication is unavailable"
            console.warn("PAM error while unlocking:", error)
        }
    }

    // ── FACE ────────────────────────────────────────────────────────────────

    // A PAM service of its own, `impasto-face`, beside the password and never
    // inside `login`: a face that is not recognised does not count against
    // the password's attempts, and the password never waits for the camera.
    // Ready where `./setup system` put the service and `./setup face` put howdy.
    property bool faceReady: false

    // From howdy's first message, which is the camera coming on, until the
    // scan ends. A refusal with nothing said first is howdy declining to look
    // (no face enrolled, the lid shut), and shows nothing.
    property bool faceScanning: false
    property bool faceMatched: false
    signal faceMissed()

    // A scan starts on a key, the pointer or the lid, never on its own: the
    // camera would otherwise find the face that has just locked the screen.
    // A miss rests long enough for its shake to be seen, and after three only
    // Enter on an empty field asks again.
    readonly property int faceRest: 1500
    readonly property int faceIdle: 5000
    readonly property int faceTries: 3
    property int faceMisses: 0
    property real faceQuietUntil: 0

    // How long the ring holds a match before the lock lets go.
    readonly property int faceHold: 650

    function wake(): void {
        if (root.faceMisses >= root.faceTries || Date.now() < root.faceQuietUntil)
            return
        root.scan()
    }

    function scan(): void {
        if (!root.locked || !root.secure || !root.faceReady || root.leaving
                || root.faceMatched || root.face.active)
            return
        root.face.start()
    }

    readonly property Process faceCheck: Process {
        command: ["sh", "-c",
            "test -f /etc/pam.d/impasto-face && test -f /usr/lib/security/pam_howdy.so"]
        onExited: code => root.faceReady = code === 0
    }

    readonly property PamContext face: PamContext {
        config: "impasto-face"

        onPamMessage: root.faceScanning = true

        onCompleted: result => {
            const looked = root.faceScanning
            root.faceScanning = false
            if (!root.locked || root.leaving)
                return
            if (result === PamResult.Success) {
                root.faceMatched = true
                root.faceHoldTimer.restart()
                return
            }
            root.faceQuietUntil = Date.now() + (looked ? root.faceRest : root.faceIdle)
            if (looked) {
                root.faceMisses += 1
                root.faceMissed()
            }
        }

        onError: error => console.warn("PAM error while looking for a face:", error)
    }

    readonly property Timer faceHoldTimer: Timer {
        interval: root.faceHold
        onTriggered: root.release()
    }

    // ── UNLOCKING ───────────────────────────────────────────────────────────

    // Both conversations end here. The surface relaxes its blur while
    // `leaving`, and the lock falls once it has.
    function release(): void {
        if (root.leaving)
            return
        root.leaving = true
        root.leave.restart()
    }

    readonly property Timer leave: Timer {
        interval: Theme.durationMorph
        onTriggered: {
            if (root.pam.active)
                root.pam.abort()
            if (root.face.active)
                root.face.abort()
            root.faceHoldTimer.stop()
            root.locked = false
            root.rest()
            root.forget()
            root.unlocked()
        }
    }
}
