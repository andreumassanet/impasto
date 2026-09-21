// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S H E L L                                                              │
// │   quickshell entry point · windows and top-level wiring                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import "./bar"
import "./capture"
import "./desktop"
import "./dock"
import "./lock"
import "./services"
import "./settings"

// Entry point: the windows, the services that must start at boot, and the
// wiring between services that may not reference each other.
ShellRoot {
    id: root

    // Singletons are built on first use. Each of these has to be running from
    // boot, not from the moment a panel first reads it.
    Component.onCompleted: {
        // Restores the saved palette.
        void ThemeService.activeId
        // Builds the launcher index ahead of the first open.
        void LauncherService.applications
        // Keeps history, so the graph has data before the panel opens.
        void StatsService.ready
        // Re-applies the animation preset and every other overridden
        // Hyprland option.
        void CompositorService.animationPreset
        // Re-applies the monitor arrangement kept for this set of screens.
        void MonitorService.loaded
        // Writes the profile's keys to keys.tsv for keybinds.lua.
        void ShortcutService.catalogue
        // Reads the user's name and face ahead of the first lock.
        void AccountService.user
        // Probes for hyprpicker, so the first press is not the one that asks.
        void PickerService.available
        // Starts the clipboard watcher.
        void ClipboardService.count
        // Probes the monitor source, so the first take is not silent, and
        // picks up a take left running by a previous shell.
        void RecorderService.available
        // Restores the night light.
        void SunsetService.available
        // Arms the idle monitors.
        void IdleService.lockAfter
        // Seeds the example profiles on a first install.
        void ProfileService.arrived
    }

    // ── SCREENS ─────────────────────────────────────────────────────────────
    //
    // Single-screen surfaces are Variants over a list of one. A PanelWindow
    // whose ShellScreen is destroyed (output unplugged) does not recover when
    // handed a new one; Variants destroys and rebuilds the window with the
    // list, which does.

    // The island is the same bar on every screen, and one of them is LIVE: the
    // screen being worked on. It changes hands the moment the focus does —
    // nothing is created and nothing is destroyed, so the crossing costs no
    // frame and what is under the pointer is always what answers it. It waits
    // only while a panel is open, since moving then is a panel closing itself.
    // The primary is the fallback, and is where the widgets and the decks stay
    // whatever the island does.
    property string islandName: MonitorService.effectivePrimaryName

    readonly property string wantedIslandName: {
        const focused = HyprlandService.focusedMonitor
        for (const screen of Quickshell.screens)
            if (screen.name === focused)
                return focused
        return MonitorService.effectivePrimaryName
    }

    onWantedIslandNameChanged: root.settleIsland()

    function settleIsland(): void {
        root.claimIsland(root.wantedIslandName)
    }

    // A bar saying the pointer is on it (`Bar.claimed`), which is the same
    // answer the compositor's focus gives a moment earlier — except when the
    // pointer was warped there rather than walked.
    function claimIsland(name: string): void {
        if (name === "" || root.islandName === name || (root.island?.expanded ?? false))
            return
        root.islandName = name
    }

    readonly property Connections islandRests: Connections {
        target: root.island

        function onExpandedChanged(): void {
            root.settleIsland()
        }
    }

    // `islandName` with a screen that is not plugged in resolved away, so an
    // output leaving never leaves every bar inert.
    readonly property string liveScreenName: {
        for (const screen of Quickshell.screens)
            if (screen.name === root.islandName)
                return root.islandName
        return MonitorService.effectivePrimaryName
    }

    // The live bar's island. Notifiable through `instances` and through each
    // bar's own `live`, so it follows the flag rather than a window.
    readonly property var island: {
        for (const bar of bars.instances)
            if (bar.live)
                return bar.island
        return null
    }

    // ── BARS ────────────────────────────────────────────────────────────────
    //
    // One bar per screen, exactly one of them live. A layer surface cannot
    // change output — handed another screen it is destroyed and a new one is
    // created — so an island that travelled was a bar built on the far screen
    // and torn down on this one, with its clock and its workspaces animating
    // in from nothing over the identical drawing already there. Measured on
    // two screens: the hour greyed out and the workspace pill slid back from
    // the wrong screen's, for about 290 ms, every crossing. Every screen
    // carrying the whole bar and one flag deciding which is live costs one
    // transparent surface per screen and no frames at all.

    // The space the bars keep, held per screen and never rebuilt, so swapping
    // one kind of bar for another moves no windows.
    Variants {
        model: Quickshell.screens

        BarReserve {
            required property var modelData

            screen: modelData
        }
    }

    Variants {
        id: bars

        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            live: modelData.name === root.liveScreenName

            onClaimed: root.claimIsland(modelData.name)
        }
    }

    // Widgets under the windows, on every screen: a row carries the screen it
    // is on, and every board has a grid of its own.
    Variants {
        model: Quickshell.screens

        Desktop {
            required property var modelData

            screen: modelData
        }
    }

    // The dock has no per-screen state, so it is on every screen.
    Variants {
        model: Quickshell.screens

        Dock {
            required property var modelData

            screen: modelData
            live: modelData.name === root.liveScreenName

            // The dock cannot see the island, so it asks.
            onLauncherRequested: root.island?.toggle("launcher")
        }
    }

    // Notes docked on the screen edges, on every screen, for the desktop's
    // reason. A deck is a row like a widget and carries its screen too.
    Variants {
        model: Quickshell.screens

        Deck {
            required property var modelData

            screen: modelData
        }
    }

    // A normal window rather than an island panel, so the island stays
    // visible while its settings change.
    SettingsWindow {
        id: settingsWindow

        // The palette and wallpaper pickers live on the island.
        onPanelRequested: panel => root.island?.open(panel)
    }

    // The control centre's gear. The island has already closed itself.
    Connections {
        target: root.island

        function onSettingsRequested(): void {
            settingsWindow.open()
        }
    }

    Connections {
        target: DesktopService

        function onSettingsRequested(): void {
            root.island?.close()
            settingsWindow.open()
        }
    }

    // The bar's settings button, which closes the window it opened.
    Connections {
        target: ModuleService

        function onSettingsRequested(): void {
            root.toggleSettings()
        }
    }

    // Optional clipboard wipe on lock. Joined here so neither service depends
    // on the other. Password-manager copies are never stored in the first
    // place; this covers everything else.
    Connections {
        target: LockService

        function onLockedChanged(): void {
            if (LockService.locked && SettingsService.clipboardWipeOnLock)
                ClipboardService.wipe()
        }
    }

    // ext-session-lock. The bar is not on screen while it is up.
    LockScreen {}

    // The lock screenshots the desktop before covering it, so it waits until
    // the island is collapsed and settled.
    Binding {
        target: LockService
        property: "shellQuiet"
        value: !root.island || (!root.island.expanded && root.island.settled)
    }

    // Global shortcuts: keybinds.lua binds a key to the name, and the action
    // lives here, so a new panel needs no compositor config.
    GlobalShortcut {
        name: "launcher"
        description: "Open the island launcher"
        onPressed: root.island?.toggle("launcher")
    }

    // ── LID ─────────────────────────────────────────────────────────────────
    //
    // Handled here rather than with `switch:` binds in Lua. MonitorService's
    // display profile is the one owner of whether the panel is lit, and it is
    // re-applied on hotplug and after config reloads. A `switch:` bind in the
    // same file as `hl.monitor()` calls is also silently not registered, and
    // a runtime monitor rule does not survive a reload.
    GlobalShortcut {
        name: "lidClosed"
        description: "The laptop lid was closed"
        onPressed: MonitorService.lid(true)
    }

    // Opening the lid is somebody sitting down, and the lock looks for them.
    GlobalShortcut {
        name: "lidOpened"
        description: "The laptop lid was opened"
        onPressed: {
            MonitorService.lid(false)
            LockService.wake()
        }
    }

    GlobalShortcut {
        name: "controls"
        description: "Open the island quick controls"
        onPressed: root.island?.toggle("controls")
    }

    // The brightness keys act on the focused screen, which only the shell
    // knows how to dim. A held key repeats the press.
    GlobalShortcut {
        name: "brightnessUp"
        description: "Raise the focused screen's brightness"
        onPressed: BrightnessService.step(5)
    }

    GlobalShortcut {
        name: "brightnessDown"
        description: "Lower the focused screen's brightness"
        onPressed: BrightnessService.step(-5)
    }

    GlobalShortcut {
        name: "overview"
        description: "Open the workspace overview"
        onPressed: root.island?.toggle("overview")
    }

    GlobalShortcut {
        name: "stats"
        description: "Open the system statistics"
        onPressed: root.island?.toggle("stats")
    }

    GlobalShortcut {
        name: "session"
        description: "Open the session menu"
        onPressed: root.island?.toggle("session")
    }

    GlobalShortcut {
        name: "lock"
        description: "Lock the screen"
        onPressed: LockService.lock()
    }

    // An open panel holds the keyboard exclusively, which beats a normal
    // window, so the island closes first or the window cannot be typed in.
    function toggleSettings(): void {
        if (!settingsWindow.shown)
            root.island?.close()
        settingsWindow.toggle()
    }

    GlobalShortcut {
        name: "settings"
        description: "Open the settings window"
        onPressed: root.toggleSettings()
    }

    GlobalShortcut {
        name: "appearance"
        description: "Open the island appearance panel"
        onPressed: root.island?.toggle("appearance")
    }

    // Same panel, on the palette strip. Each name only closes from its own
    // strip.
    GlobalShortcut {
        name: "palette"
        description: "Open the island appearance panel on the palettes"
        onPressed: root.island?.toggle("palette")
    }

    GlobalShortcut {
        name: "pet"
        description: "Open the pet"
        onPressed: root.island?.toggle("pet")
    }

    GlobalShortcut {
        name: "games"
        description: "Open the games"
        onPressed: root.island?.toggle("games")
    }

    GlobalShortcut {
        name: "notes"
        description: "Open the notes"
        onPressed: root.island?.toggle("notes")
    }

    GlobalShortcut {
        name: "board"
        description: "Open the task board"
        onPressed: root.island?.toggle("board")
    }

    GlobalShortcut {
        name: "keys"
        description: "Show every key"
        onPressed: root.island?.toggle("keys")
    }

    GlobalShortcut {
        name: "packages"
        description: "Open the packages"
        onPressed: root.island?.toggle("packages")
    }

    // The clipboard is a launcher mode: pressed again on that mode it closes,
    // pressed on another mode it switches. The query is set before opening
    // because with `launcherFits` the panel's height depends on it, and the
    // island is sized before the panel exists.
    GlobalShortcut {
        name: "clipboard"
        description: "Open the launcher on the clipboard"
        onPressed: {
            const sigil = SettingsService.launcherPrefix("clipboard")
            const showing = root.island?.state.openPanel === "launcher"
            if (showing && LauncherService.query.startsWith(sigil)) {
                root.island?.close()
                return
            }
            LauncherService.query = sigil
            root.island?.open("launcher")
        }
    }

    // hyprpicker freezes a screenshot of the screen, so an open panel has to
    // finish closing before it starts.
    GlobalShortcut {
        name: "picker"
        description: "Pick a colour off the screen"
        onPressed: {
            const wasOpen = root.island?.expanded ?? false
            root.island?.close()
            PickerService.pick(wasOpen ? PickerService.settle : 0)
        }
    }

    // ── CAPTURE ─────────────────────────────────────────────────────────────
    //
    // `capture` opens the surface in its last mode; the others preset a shape
    // or destination and are unbound by default. The photo is taken with
    // whatever panel is open, so a panel can be captured.
    function capture(shape: string, to: string): void {
        CaptureService.open(shape, "photo", to, 0)
    }

    GlobalShortcut {
        name: "capture"
        description: "Open the capture surface"
        onPressed: CaptureService.open("", "", "", 0)
    }

    GlobalShortcut {
        name: "captureRegion"
        description: "Capture a region"
        onPressed: root.capture("region", "file")
    }

    GlobalShortcut {
        name: "captureWindow"
        description: "Capture a window"
        onPressed: root.capture("window", "file")
    }

    GlobalShortcut {
        name: "captureScreen"
        description: "Capture the whole screen"
        onPressed: root.capture("screen", "file")
    }

    GlobalShortcut {
        name: "captureEdit"
        description: "Capture a region and annotate it"
        onPressed: root.capture("region", "editor")
    }

    GlobalShortcut {
        name: "captureText"
        description: "Read a region as text"
        onPressed: root.capture("region", "text")
    }

    GlobalShortcut {
        name: "record"
        description: "Start or stop recording the screen"
        onPressed: {
            root.island?.close()
            RecorderService.toggle()
        }
    }

    // Always built rather than behind a Loader: creating a layer surface at
    // capture time flashes a black frame over the screen being captured.
    CaptureOverlay {}

    // Region recording, joined here to keep the two services acyclic.
    Connections {
        target: CaptureService

        function onRecordRequested(shape: string, geometry: string): void {
            RecorderService.startAt(shape, geometry)
        }
    }

    // A new wallpaper re-derives the adaptive palette. Wired here so the
    // dependency runs one way: the theme knows about wallpapers, not the
    // reverse.
    Connections {
        target: WallpaperService

        function onApplied(path: string): void {
            ThemeService.reloadAdaptiveColors()
        }
    }

    // ── IPC ─────────────────────────────────────────────────────────────────
    //
    // Every palette push hangs off WallpaperService.applied, which only fires
    // inside this process. External callers (Thunar's "Set as Wallpaper")
    // come in here instead of running theme_manager.py directly:
    //   qs ipc call wallpaper set <path>
    IpcHandler {
        target: "wallpaper"

        function set(path: string): string {
            if (!path)
                return "usage: qs ipc call wallpaper set <path>"
            WallpaperService.apply(path)
            return path
        }
    }

    // `./setup sync` calls this once every file has landed. The reload the
    // shell starts on its own when a file changes can begin before the last
    // one is written, and then never sees it:
    //   qs ipc call shell reload
    IpcHandler {
        target: "shell"

        function reload(): void {
            Quickshell.reload(false)
        }
    }

}
