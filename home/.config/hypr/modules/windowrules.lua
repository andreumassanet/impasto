-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   W I N D O W R U L E S                                                  │
-- │   per-window rules                                                       │
-- │                                                                          │
-- │   github.com/andreumassanet/impasto                                      │
-- │                                                                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

-- ── GENERAL ─────────────────────────────────────────────────────────────────

-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- · ignore maximize requests from every app
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- · workaround for XWayland dragging issues
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})


-- ── SHELL ───────────────────────────────────────────────────────────────────

-- · the settings window is a regular toplevel; float it instead of tiling.
-- · The title is set by settings/SettingsWindow.qml.
hl.window_rule({
    name  = "quickshell-settings",
    match = {
        -- A regex, not a Lua pattern.
        class = "^(org\\.quickshell)$",
        title = "^(Settings)$",
    },

    float  = true,
    center = true,
    size   = {980, 680},
})


-- · imv, a look at one picture from the desk or from yazi, floats over the
-- · layout instead of reflowing it.
hl.window_rule({
    name  = "imv-float",
    match = { class = "^(imv)$" },

    float  = true,
    center = true,
    size   = "monitor_w*0.7 monitor_h*0.7",
})


-- · satty, opened by the capture surface without --fullscreen
hl.window_rule({
    name  = "satty-float",
    match = { class = "^(com\\.gabm\\.satty)$" },

    float  = true,
    center = true,
    size   = {1200, 800},
})


-- · the terminal the packages panel runs pacman in
hl.window_rule({
    name  = "packages-terminal",
    match = { class = "^(impasto-packages)$" },

    float  = true,
    center = true,
    size   = {1000, 620},
})


-- ── APPS ────────────────────────────────────────────────────────────────────

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = {20, "monitor_h-120"},
    float = true,
})

hl.window_rule({
    name  = "xlispg-floater",
    match = { class = "^Xlispg$" },  -- exact class as reported by hyprctl

    float  = true,
    center = true,
})

-- · Chromium/Electron touchpad scrolling
--
-- Chromium's Wayland backend scales every axis delta by kWheelDelta /
-- kAxisValueScale = 53 / 10 (ui/ozone/platform/wayland/host/
-- wayland_pointer.cc), so it scrolls 5.3× faster than GTK/Qt. 0.19 ≈ 1/5.3.
-- Chrome web apps report `chrome-<id>-Default`.
hl.window_rule({
    name  = "chromium-touchpad-scroll",
    match = { class = "^(google-chrome|chrome-.*|discord|code)$" },

    scroll_touchpad = 0.19,
})


-- ── MATLAB ──────────────────────────────────────────────────────────────────

hl.window_rule({
    name  = "matlab-main-tiling",
    match = {
        class         = "^MATLAB R2025b Update.*$",
        initial_title = "^MATLAB$",
    },

    tile = true,
})

hl.window_rule({
    name  = "matlab-figures-float",
    match = {
        class = "^MATLAB R2025b Update.*$",
        title = "^Figures$",
    },

    float  = true,
    center = true,
})

hl.window_rule({
    name  = "matlab-opening-fix",
    match = {
        class         = "^MATLAB R2025b Update.*$",
        initial_title = "^Opening...$",
    },

    float  = true,
    center = true,
})

hl.window_rule({
    name  = "matlab-addons-float",
    match = {
        class = "^MATLAB R2025b Update.*$",
        title = "^Add-On Explorer$",
    },

    float  = true,
    center = true,
    size   = {1000, 800},
})

hl.window_rule({
    name  = "aa-practices-float",
    match = {
        class = "^practice[0-9]+-Main$",
        title = "^Practice [0-9]+.*$",
    },

    float  = true,
    center = true,
})


-- ── LAYERS ──────────────────────────────────────────────────────────────────

-- · blur behind the desktop widgets, so translucent backgrounds stay legible
--
-- The layer covers the whole screen, so ignore_alpha is required or the
-- entire wallpaper gets blurred. 0.15 is below the widget opacity slider's
-- 20% floor.
hl.layer_rule({
    name  = "impasto-desktop-blur",
    match = { namespace = "^(impasto-desktop)$" },

    blur         = true,
    ignore_alpha = 0.15,
})
