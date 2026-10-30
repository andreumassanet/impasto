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
-- Your own changes go in ~/.config/hypr/custom/, not in the modules: a file
-- there named like a module (custom/keybinds.lua for modules/keybinds.lua) is
-- loaded right after it, so it can change what the module set, and `setup`
-- never writes to custom/, so an update cannot touch it. A file that is not
-- there is skipped. To change a key, unbind it first:
--
--   hl.unbind("SUPER + D")
--   hl.bind("SUPER + D", hl.dsp.exec_cmd("drawio"), { description = "App: draw.io" })

-- Loads custom/NAME.lua when there is one, found where `require` would look.
local function load_custom(name)
    if package.searchpath("custom." .. name, package.path) then
        -- A file of the user's with an error must not stop the modules after it.
        local loaded, failure = pcall(require, "custom." .. name)
        if not loaded then
            print("hypr custom/" .. name .. ".lua: " .. tostring(failure))
        end
    end
end

for _, name in ipairs({
    "monitors",
    "autostart",
    "env",
    "look",
    "animations",
    "input",
    "keybinds",
    "windowrules",
}) do
    require("modules." .. name)
    load_custom(name)
end
