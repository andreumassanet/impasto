-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   H Y P R L A N D                                                        │
-- │   wayland compositor · entry point                                       │
-- │                                                                          │
-- │   github.com/andreumassanet/impasto                                      │
-- │                                                                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

-- Lua config (Hyprland 0.55+); hyprlang is deprecated.
-- https://wiki.hypr.land/Configuring/Start/
--
-- This file only loads the modules in modules/, in order. Hyprland runs each
-- require in its own scope: an error in one module will not break the rest.
--
-- After each module, ~/.config/hypr/custom/<module>.lua is loaded if it
-- exists, so a local change can override the module without editing a file
-- that `setup update` installs. Nothing installs into custom/.

local function load(name)
    require("modules." .. name)
    if package.searchpath("custom." .. name, package.path) then
        require("custom." .. name)
    end
end

load("monitors")
load("autostart")
load("env")
load("look")
load("animations")
load("input")
load("keybinds")
load("windowrules")
