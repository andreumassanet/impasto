// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O S D   S E R V I C E                                                  │
// │   turns system changes into one transient island event                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Every ephemeral system change arrives at the island through one signal.
//
// Volume, brightness and battery all render in the same layer, so adding an
// event later means emitting `requested`, not writing another layer. A bar is
// drawn when `progress` is 0 or more; pass -1 for a message with no level.
Singleton {
    id: root

    signal requested(string icon, string label, real progress)

    // Where changes are announced (`SettingsService.osdStyle`). The island
    // draws every event under "island", only the ones with a level under
    // "notification" (a held volume key would flood the notifications), and
    // nothing under "off".
    readonly property string style: SettingsService.osdStyle

    function showsOnIsland(progress: real): bool {
        return root.style === "island" || (root.style === "notification" && progress >= 0)
    }

    // A transient notification is not kept in the history. It rides over a
    // full-screen window like any other notification on the island, and
    // do-not-disturb silences it like the rest.
    onRequested: (icon, label, progress) => {
        if (root.style === "notification" && progress < 0)
            Quickshell.execDetached(["notify-send", "--app-name=Impasto",
                "--expire-time=2500", "--hint=boolean:transient:true", "--", label])
    }

    // The new kinds of change, by group, each with its own switch.
    readonly property var groups: ({
        audio: SettingsService.osdAudio,
        radios: SettingsService.osdRadios,
        locks: SettingsService.osdLocks,
        session: SettingsService.osdSession
    })

    function announce(group: string, icon: string, label: string): void {
        if (root.armed && root.style !== "off" && root.groups[group])
            root.requested(icon, label, -1)
    }

    // Bindings fire once as they initialise. Emitting then would pop an OSD
    // every time the shell starts, so nothing is emitted until this is armed.
    property bool armed: false

    // One frame. Holding a volume key fires dozens of changes and the island
    // would stutter through every one of them.
    readonly property int debounce: 16

    // A device connecting reports its own volume, which is not the user asking
    // to see the volume. Ignore it for as long as the switch takes.
    property bool audioSuppressed: false
    readonly property int suppression: 2000

    readonly property Timer armTimer: Timer {
        interval: 600
        running: true
        onTriggered: {
            root.wasWifi = NetworkService.wifiEnabled
            root.wasBluetooth = BluetoothService.enabled
            root.wasAirborne = ControlsService.airborne
            root.armed = true
        }
    }

    readonly property Timer suppressionTimer: Timer {
        interval: root.suppression
        onTriggered: root.audioSuppressed = false
    }

    readonly property Timer volumeTimer: Timer {
        interval: root.debounce
        // Muted keeps the real level, so raising the volume while muted still
        // shows the new value. Skipped while the volume detail is open: its
        // slider already shows it, and the OSD would cover it.
        onTriggered: {
            if (ModuleService.openId === "volume")
                return
            root.requested(AudioService.icon,
                           `${AudioService.volume}%`,
                           AudioService.volume / 100)
        }
    }

    // The screen whose level changed, which is not always the focused one:
    // the backlight also moves on its own.
    property var brightnessDisplay: null

    readonly property Timer brightnessTimer: Timer {
        interval: root.debounce
        // Skipped while the brightness detail is open.
        onTriggered: {
            const display = root.brightnessDisplay
            if (!display || ModuleService.openId === "brightness")
                return
            root.requested(display.icon, `${display.slider}%`, display.slider / 100)
        }
    }

    readonly property Connections audio: Connections {
        target: AudioService
        enabled: root.armed && !root.audioSuppressed
        function onVolumeChanged(): void { root.volumeTimer.restart() }
        function onMutedChanged(): void { root.volumeTimer.restart() }
    }

    // Not on the reading: that also changes when the focus moves to another
    // screen, which is not the user asking to see it.
    readonly property Connections brightness: Connections {
        target: BrightnessService
        enabled: root.armed
        function onAdjusted(display): void {
            root.brightnessDisplay = display
            root.brightnessTimer.restart()
        }
    }

    // Not debounced: plugging in cannot repeat fast enough to need it.
    readonly property Connections battery: Connections {
        target: BatteryService
        enabled: root.armed
        function onChargingChanged(): void {
            root.requested(BatteryService.icon,
                           BatteryService.charging ? Tr.t("Charging") : Tr.t("On battery"),
                           BatteryService.percent / 100)
        }
    }

    // ── STATE CHANGES ───────────────────────────────────────────────────────
    //
    // Read off the services, so a change is announced whatever made it: a
    // key, a tile, `wpctl`, another program.

    readonly property Connections microphone: Connections {
        target: AudioService
        function onSourceMutedChanged(): void {
            root.announce("audio", AudioService.sourceIcon,
                          AudioService.sourceMuted ? Tr.t("Microphone muted") : Tr.t("Microphone live"))
        }
    }

    // Switching the default device moves the volume too, which the volume
    // readout would announce first; waiting a little lets the device name
    // replace it.
    property string deviceIcon: ""
    property string deviceLabel: ""

    readonly property Timer deviceTimer: Timer {
        interval: 300
        onTriggered: root.announce("audio", root.deviceIcon, root.deviceLabel)
    }

    readonly property Connections devices: Connections {
        target: AudioService
        enabled: root.armed && !root.audioSuppressed
        function onSinkChanged(): void {
            if (!AudioService.sink)
                return
            root.deviceIcon = "󰓃"
            root.deviceLabel = AudioService.sink.description || AudioService.sink.name
            root.deviceTimer.restart()
        }
        function onSourceChanged(): void {
            if (!AudioService.source)
                return
            root.deviceIcon = "󰍬"
            root.deviceLabel = AudioService.source.description || AudioService.source.name
            root.deviceTimer.restart()
        }
    }

    // Turning airplane mode on flips Wi-Fi and Bluetooth as well; one pass
    // after they settle says only the largest thing that happened.
    property bool wasWifi: false
    property bool wasBluetooth: false
    property bool wasAirborne: false

    readonly property Timer radiosTimer: Timer {
        interval: 200
        onTriggered: {
            const wifi = NetworkService.wifiEnabled
            const bluetooth = BluetoothService.enabled
            const airborne = ControlsService.airborne
            if (airborne !== root.wasAirborne)
                root.announce("radios", airborne ? "󰀝" : "󰀞",
                              airborne ? Tr.t("Airplane mode on") : Tr.t("Airplane mode off"))
            else if (wifi !== root.wasWifi)
                root.announce("radios", wifi ? "󰖩" : "󰖪",
                              wifi ? Tr.t("Wi-Fi on") : Tr.t("Wi-Fi off"))
            else if (bluetooth !== root.wasBluetooth)
                root.announce("radios", bluetooth ? "󰂯" : "󰂲",
                              bluetooth ? Tr.t("Bluetooth on") : Tr.t("Bluetooth off"))
            root.wasWifi = wifi
            root.wasBluetooth = bluetooth
            root.wasAirborne = airborne
        }
    }

    readonly property Connections radios: Connections {
        target: NetworkService
        function onWifiEnabledChanged(): void { root.radiosTimer.restart() }
    }

    readonly property Connections bluetooth: Connections {
        target: BluetoothService
        function onEnabledChanged(): void { root.radiosTimer.restart() }
    }

    readonly property Connections idle: Connections {
        target: IdleService
        function onKeepAwakeChanged(): void {
            root.announce("session", IdleService.keepAwake ? "󰅶" : "󰾪",
                          IdleService.keepAwake ? Tr.t("Keep awake on") : Tr.t("Keep awake off"))
        }
    }

    readonly property Connections focus: Connections {
        target: NotificationService
        function onDoNotDisturbChanged(): void {
            root.announce("session", NotificationService.doNotDisturb ? "󰂛" : "󰂚",
                          NotificationService.doNotDisturb ? Tr.t("Do not disturb on") : Tr.t("Do not disturb off"))
        }
    }

    readonly property Connections nightLight: Connections {
        target: SettingsService
        function onNightLightChanged(): void {
            root.announce("session", SunsetService.icon,
                          SettingsService.nightLight ? Tr.t("Night light on") : Tr.t("Night light off"))
        }
    }

    // ── LOCK KEYS ───────────────────────────────────────────────────────────
    //
    // Nothing pushes these: the compositor sends no event for a lock key. The
    // keyboard's LEDs are the state, so they are read in place (no process)
    // twice a second, and only while the group is on.
    //
    // shortcut: the first keyboard found at startup stands for all, since the
    // kernel keeps their LEDs in step; one plugged in later is not looked for
    // until the shell restarts.
    property string ledDirectory: ""

    readonly property Process ledProbe: Process {
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            // "/sys/class/leds/input3::capslock" becomes "/sys/class/leds/input3::".
            onStreamFinished: root.ledDirectory = text.trim().replace(/capslock$/, "")
        }
    }

    component LockKey: FileView {
        id: key

        required property string led
        required property string icon
        required property string name

        property bool known: false
        property bool on: false

        path: root.ledDirectory === "" ? "" : `${root.ledDirectory}${key.led}/brightness`
        watchChanges: false

        onLoaded: {
            const now = text().trim() !== "0"
            // The first reading is the starting state, not a change.
            if (key.known && now !== key.on)
                root.announce("locks", key.icon, `${key.name} ${now ? Tr.t("on") : Tr.t("off")}`)
            key.on = now
            key.known = true
        }
    }

    readonly property LockKey capsLock: LockKey { led: "capslock"; icon: "󰪛"; name: Tr.t("Caps Lock") }
    readonly property LockKey numLock: LockKey { led: "numlock"; icon: "󰎠"; name: Tr.t("Num Lock") }

    readonly property Timer lockTimer: Timer {
        interval: 500
        repeat: true
        running: root.ledDirectory !== "" && root.groups.locks && root.style !== "off"
        onTriggered: {
            root.capsLock.reload()
            root.numLock.reload()
        }
    }

    function suppressAudio(): void {
        root.audioSuppressed = true
        root.suppressionTimer.restart()
    }
}
