-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   K E Y B I N D S                                                        │
-- │   keyboard and mouse bindings                                            │
-- │                                                                          │
-- │   github.com/andreumassanet/impasto                                      │
-- │                                                                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

-- No bind uses /, ., ' or `: they are shifted or dead keys on a Spanish layout.

local apps    = require("modules.programs")
local mainMod = "SUPER"


-- ── PROFILE KEYS ────────────────────────────────────────────────────────────

-- The shell writes the active profile's bindings to keys.tsv
-- (description<TAB>combination, empty = unbound) and reloads Hyprland when
-- they change. Descriptions are the keys, so renaming one drops its binding
-- from every profile. The combinations below are the fallback.
--
-- A line from a bind added in Settings → Keys carries two more fields:
-- description<TAB>combination<TAB>kind<TAB>target. The Lua config has no
-- declaration for it, so it is bound from here at the end.
local function profile_keys()
    local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
    local combinations = {}
    local customs      = {}
    local file         = io.open(state .. "/quickshell/keys.tsv")
    if not file then
        return combinations, customs
    end
    for line in file:lines() do
        local description, combination, kind, target =
            line:match("^([^#\t][^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
        if not description then
            description, combination = line:match("^([^#\t][^\t]*)\t(.*)$")
        end
        if description then
            combinations[description] = combination or ""
            if kind then
                customs[description] = { kind = kind, target = target or "" }
            end
        end
    end
    file:close()
    return combinations, customs
end

local combinations, customs = profile_keys()

-- `hl.bind`, on the profile's combination for this description.
local function bind(combination, action, options)
    local chosen = combinations[options.description]
    if chosen == nil then
        chosen = combination
    end
    if chosen ~= "" then
        hl.bind(chosen, action, options)
    end
end


-- ── BINDS ───────────────────────────────────────────────────────────────────

hl.config({
    binds = {
        workspace_back_and_forth = true,
    },
})


-- ── APPLICATIONS ────────────────────────────────────────────────────────────

bind(mainMod .. " + Return", hl.dsp.exec_cmd(apps.terminal),     { description = "Applications · Open a terminal" })
bind(mainMod .. " + E",      hl.dsp.exec_cmd(apps.file_manager), { description = "Applications · Open the file manager" })
bind(mainMod .. " + B",      hl.dsp.exec_cmd(apps.browser),      { description = "Applications · Open the browser" })


-- ── WINDOWS ─────────────────────────────────────────────────────────────────

-- · floating size
--
-- A floated window keeps its tiled size, which for a lone window is the whole
-- workspace. Float it at a fraction of the monitor instead, centred.
local FLOAT_FRACTION = 0.6

-- Resize and centre only when going tiled → floating; the state must be read
-- before the toggle.
local function float_centred()
    local window = hl.get_active_window()
    if not window then
        return
    end

    local was_floating = window.floating
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    if was_floating then
        return
    end

    local monitor = hl.get_active_monitor()
    if not monitor then
        return
    end

    -- The monitor reports physical pixels; the dispatcher takes logical ones.
    local scale = monitor.scale or 1
    hl.dispatch(hl.dsp.window.resize({
        x     = math.floor(monitor.width / scale * FLOAT_FRACTION),
        y     = math.floor(monitor.height / scale * FLOAT_FRACTION),
        exact = true,
    }))
    hl.dispatch(hl.dsp.window.center())
end

bind(mainMod .. " + Q",           hl.dsp.window.close(), { description = "Windows · Close the focused window" })
bind(mainMod .. " + SHIFT + Q",   hl.dsp.window.kill(),  { description = "Windows · Kill the focused window" })
bind(mainMod .. " + F",           hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Windows · Full screen" })
bind(mainMod .. " + ALT + F",     hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),  { description = "Windows · Maximise, keeping the bar" })
bind(mainMod .. " + ALT + Space", float_centred,          { description = "Windows · Float or tile the window" })
bind(mainMod .. " + P",           hl.dsp.window.pseudo(), { description = "Windows · Toggle pseudo-tiling" })
bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"), { description = "Windows · Flip the split direction" })

-- · move focus
bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }), { description = "Windows · Focus the window left" })
bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }), { description = "Windows · Focus the window right" })
bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }), { description = "Windows · Focus the window up" })
bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }), { description = "Windows · Focus the window down" })

-- · cycle windows
bind("ALT + Tab",         hl.dsp.window.cycle_next(),                 { repeating = true, description = "Windows · Next window" })
bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), { repeating = true, description = "Windows · Previous window" })

-- · move the window itself
bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }), { description = "Windows · Move the window left" })
bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }), { description = "Windows · Move the window right" })
bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }), { description = "Windows · Move the window up" })
bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }), { description = "Windows · Move the window down" })

-- · drag and resize with the mouse
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Windows · Drag the window" })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Windows · Resize the window" })


-- ── WORKSPACES ──────────────────────────────────────────────────────────────

-- The workspace each screen was showing before the one it shows now.
-- `workspace_back_and_forth` only reaches the plain dispatcher, and the
-- numbers use `on_current_monitor`; Hyprland's own previous is one for the
-- whole desk, which on two screens is the wrong one.
local before  = {}
local showing = {}

-- Seeded, so the first press of the number already showing has somewhere to
-- go back to. At the first parse there may be no monitors yet, and the event
-- below fills it in.
for _, monitor in ipairs(hl.get_monitors() or {}) do
    if monitor.active_workspace then
        showing[monitor.name] = monitor.active_workspace.id
    end
end

hl.on("workspace.active", function(workspace)
    local monitor = workspace and workspace.monitor
    if not monitor then
        return
    end
    local name = monitor.name
    if showing[name] ~= nil and showing[name] ~= workspace.id then
        before[name] = showing[name]
    end
    showing[name] = workspace.id
end)

-- The number of the workspace already here goes back to the one before it.
local function to_workspace(index)
    return function()
        local monitor = hl.get_active_monitor()
        local active  = hl.get_active_workspace()
        local back    = monitor and before[monitor.name]
        local target  = index
        if active and active.id == index and back and back ~= index then
            target = back
        end
        hl.dispatch(hl.dsp.focus({ workspace = target, on_current_monitor = true }))
    end
end

-- · SUPER + [1-9,0] switches; adding SHIFT moves the window there
--
-- The ten are shared by every screen, and a number brings its workspace to
-- the screen you are on rather than taking you to the screen it is on:
-- `on_current_monitor` swaps the two screens' workspaces where it has to.
for i = 1, 10 do
    local key = i % 10  -- 10 maps to the 0 key
    bind(mainMod .. " + " .. key,         to_workspace(i),
         { description = "Workspaces · Go to workspace " .. i })
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }),
         { description = "Workspaces · Move the window to workspace " .. i })
end

-- · scroll wheel to cycle through the ones on this screen
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m+1" }), { description = "Workspaces · Next workspace" })
bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "m-1" }), { description = "Workspaces · Previous workspace" })


-- ── SCREENS ─────────────────────────────────────────────────────────────────

-- · the keyboard, and the workspace under it, across screens. A window
-- · crosses with the window keys above: with nothing that way, they hand it
-- · to the next screen.

-- The two screens trade what they are showing, and the keyboard goes with the
-- workspace. Moving it instead buries the other screen's workspace behind
-- this one and leaves a new empty one where you were. The direction is
-- resolved by moving the keyboard first: nothing that way leaves it where it
-- was and changes nothing.
local function trade_workspace(direction)
    return function()
        local here = hl.get_active_monitor()
        if not here then
            return
        end

        hl.dispatch(hl.dsp.focus({ monitor = direction }))

        local there = hl.get_active_monitor()
        if not there or there.name == here.name then
            return
        end

        hl.dispatch(hl.dsp.workspace.swap_monitors({ monitor1 = here.name, monitor2 = there.name }))
    end
end

bind(mainMod .. " + ALT + left",          hl.dsp.focus({ monitor = "l" }), { description = "Screens · Focus the screen left" })
bind(mainMod .. " + ALT + right",         hl.dsp.focus({ monitor = "r" }), { description = "Screens · Focus the screen right" })
bind(mainMod .. " + ALT + SHIFT + left",  trade_workspace("l"), { description = "Screens · Take the workspace to the screen left" })
bind(mainMod .. " + ALT + SHIFT + right", trade_workspace("r"), { description = "Screens · Take the workspace to the screen right" })


-- ── MEDIA KEYS ──────────────────────────────────────────────────────────────

-- · volume and brightness; brightness goes through the shell, which knows
-- · the focused screen and how to dim it
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Media · Volume up" })
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Media · Volume down" })
bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, description = "Media · Mute output" })
bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, description = "Media · Mute microphone" })
bind("XF86MonBrightnessUp",   hl.dsp.global("quickshell:brightnessUp"),                          { locked = true, repeating = true, description = "Media · Brightness up" })
bind("XF86MonBrightnessDown", hl.dsp.global("quickshell:brightnessDown"),                        { locked = true, repeating = true, description = "Media · Brightness down" })

-- · Acer laptops send XF86Launch6 for the microphone key
bind("XF86Launch6",           hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, description = "Media · Mute microphone (Acer)" })

-- · player; distinct descriptions so each key can be rebound separately
bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media · Play or pause" })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media · Play or pause, from the pause key" })
bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Media · Next track" })
bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Media · Previous track" })


-- ── SESSION ─────────────────────────────────────────────────────────────────

-- · the power button opens the session menu instead of powering off (logind
-- · is told to ignore it, see system/etc/systemd/logind.conf.d/). Some
-- · machines never report a short press, so the menu has keyboard binds too.
bind(mainMod .. " + X",         hl.dsp.global("quickshell:session"), { description = "Session · Session menu" })
bind("CTRL + ALT + Delete",     hl.dsp.global("quickshell:session"), { description = "Session · Session menu, from CTRL + ALT + Delete" })
bind("XF86PowerOff",            hl.dsp.global("quickshell:session"), { description = "Session · Session menu, from the power button" })
bind(mainMod .. " + L",         hl.dsp.global("quickshell:lock"),    { description = "Session · Lock the screen" })
bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"), { description = "Session · Exit Hyprland" })


-- ── UTILITIES ───────────────────────────────────────────────────────────────

-- · dpms actually powers the panel off, unlike brightness 0. Only this bind
-- · wakes it (key/mouse wake is off). The dispatcher toggles; it ignores
-- · a state argument.
bind(mainMod .. " + SHIFT + D", hl.dsp.dpms(), { locked = true, description = "Utilities · Turn the screen off or back on" })
bind(mainMod .. " + CTRL + R",  hl.dsp.exec_cmd("pkill -x quickshell; pkill -x qs; sleep 0.5; qs -d"), { description = "Utilities · Restart the shell" })


-- ── SHELL ───────────────────────────────────────────────────────────────────

-- · global shortcuts registered by the shell
bind(mainMod .. " + Space",     hl.dsp.global("quickshell:launcher"),   { description = "Shell · Open the launcher" })
bind(mainMod .. " + A",         hl.dsp.global("quickshell:controls"),   { description = "Shell · Open the control centre" })
bind(mainMod .. " + TAB",       hl.dsp.global("quickshell:overview"),   { description = "Shell · Open the workspace overview" })
bind(mainMod .. " + comma",     hl.dsp.global("quickshell:settings"),   { description = "Shell · Open settings" })
bind(mainMod .. " + T",         hl.dsp.global("quickshell:appearance"), { description = "Shell · Open appearance" })
bind(mainMod .. " + SHIFT + T", hl.dsp.global("quickshell:palette"),    { description = "Shell · Open the palette" })
bind(mainMod .. " + U",         hl.dsp.global("quickshell:stats"),      { description = "Shell · Open system statistics" })
bind(mainMod .. " + SHIFT + P", hl.dsp.global("quickshell:pet"),        { description = "Shell · Open the pet" })
bind(mainMod .. " + G",         hl.dsp.global("quickshell:games"),      { description = "Shell · Open the games" })
bind(mainMod .. " + S",         hl.dsp.global("quickshell:notes"),      { description = "Shell · Open the notes" })
bind(mainMod .. " + K",         hl.dsp.global("quickshell:board"),      { description = "Shell · Open the task board" })

-- · key sheet, read from `hyprctl binds`. H, since / is SHIFT + 7 on a
-- · Spanish layout
bind(mainMod .. " + H",         hl.dsp.global("quickshell:keys"),       { description = "Shell · Show every key" })

-- · packages panel (pacman + AUR); installs run in a terminal
bind(mainMod .. " + I",         hl.dsp.global("quickshell:packages"),   { description = "Shell · Open the packages" })

-- · clipboard history is a launcher mode
bind(mainMod .. " + V",         hl.dsp.global("quickshell:clipboard"),  { description = "Shell · Open the clipboard history" })

-- · colour picker (hyprpicker); the result goes to the clipboard
bind(mainMod .. " + SHIFT + C", hl.dsp.global("quickshell:picker"),     { description = "Shell · Pick a colour off the screen" })

-- · capture surface. The direct captures below are unbound by default and
-- · can be assigned in Settings → Keys.
bind(mainMod .. " + SHIFT + S", hl.dsp.global("quickshell:capture"), { description = "Shell · Open the capture surface" })
bind("Print",                   hl.dsp.global("quickshell:capture"), { description = "Shell · Open the capture surface, from Print" })
bind(mainMod .. " + SHIFT + R", hl.dsp.global("quickshell:record"),  { description = "Shell · Start or stop recording the screen" })
bind("", hl.dsp.global("quickshell:captureRegion"), { description = "Shell · Capture a region" })
bind("", hl.dsp.global("quickshell:captureWindow"), { description = "Shell · Capture a window" })
bind("", hl.dsp.global("quickshell:captureScreen"), { description = "Shell · Capture the whole screen" })
bind("", hl.dsp.global("quickshell:captureEdit"),   { description = "Shell · Capture a region and annotate it" })
bind("", hl.dsp.global("quickshell:captureText"),   { description = "Shell · Read a region as text" })


-- ── LID ─────────────────────────────────────────────────────────────────────

-- Plain `hl.bind`, not profile keys. Kept out of monitors.lua: a `switch:`
-- bind in the same file as `hl.monitor()` calls is silently never registered.
--
-- `switch:on` is the lid closing. `locked = true` so it also fires on the lock
-- screen. The shell decides what to do (Settings → Displays).
hl.bind("switch:on:Lid Switch",  hl.dsp.global("quickshell:lidClosed"),
        { locked = true, description = "Session · The laptop lid was closed" })
hl.bind("switch:off:Lid Switch", hl.dsp.global("quickshell:lidOpened"),
        { locked = true, description = "Session · The laptop lid was opened" })


-- ── ADDED IN SETTINGS ───────────────────────────────────────────────────────

-- Custom binds (Settings → Keys → Add a binding) that are not among the
-- declarations above, so `bind()` never saw them. A `shell` kind fires one of
-- shell.qml's GlobalShortcuts; a `command` kind runs what it targets. Only
-- those with a profile combination are bound, so an unbound one stays that
-- way until the user gives it a key.
for description, custom in pairs(customs) do
    local combination = combinations[description] or ""
    if combination ~= "" and custom.target ~= "" then
        local action
        if custom.kind == "shell" then
            action = hl.dsp.global("quickshell:" .. custom.target)
        else
            action = hl.dsp.exec_cmd(custom.target)
        end
        hl.bind(combination, action, { description = description })
    end
end
