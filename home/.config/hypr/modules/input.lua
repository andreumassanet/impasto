-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   I N P U T                                                              │
-- │   keyboard, mouse and touchpad                                           │
-- │                                                                          │
-- │   github.com/andreumassanet/impasto                                      │
-- │                                                                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0,  -- range -1.0 to 1.0; 0 means unmodified

        repeat_delay = 300,
        repeat_rate  = 40,

        touchpad = {
            natural_scroll = true,
            -- libinput's own rate. Chromium is corrected per window in
            -- windowrules.lua. Tune live with:
            --   hyprctl eval 'hl.config({ input = { touchpad = { scroll_factor = 0.8 } } })'
            scroll_factor  = 1.0,
        },

        accel_profile = "flat",
    },
})


-- ── CURSOR ──────────────────────────────────────────────────────────────────

hl.config({
    cursor = {
        -- Hide after 5 s idle rather than on key press, so the pointer does
        -- not vanish after every shortcut.
        inactive_timeout = 5,
    },
})

-- · shake to find (hypr-dynamic-cursors, built by `./setup plugins`)
--
-- The config is parsed once before the plugin loads and again after, so the
-- guard skips the block on the first pass.
--
-- Tuned to jump to one size on a small shake and shrink back quickly
-- (plugin defaults: 6/4/4/2000). Tune live with:
--   hyprctl eval 'hl.config({ plugin = { dynamic_cursors = { shake = { timeout = 800 } } } })'
if hl.plugin.dynamic_cursors ~= nil then
    hl.config({
        plugin = {
            dynamic_cursors = {
                mode  = "none",     -- no tilt or rotate; magnification only
                shake = {
                    enabled   = true,
                    threshold = 4.0,    -- lower than 6.0: a smaller shake triggers it
                    base      = 3.0,    -- the size it jumps to
                    speed     = 0.0,    -- 0: one size, no creeping growth while shaking
                    influence = 0.0,    -- shake intensity does not change the size
                    timeout   = 500,    -- ms it stays big after you stop shaking
                },
            },
        },
    })
end

-- · three-finger horizontal swipe switches workspace
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
