-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   A U T O S T A R T                                                      │
-- │   processes launched with the session                                    │
-- │                                                                          │
-- │   github.com/andreumassanet/impasto                                      │
-- │                                                                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

-- https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Quickshell owns org.freedesktop.Notifications, so no separate notification
-- daemon runs: only one process can hold that bus name.
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -d")        -- · bar and notifications (quickshell)
    hl.exec_cmd("awww-daemon")  -- · wallpaper
end)

-- · plugins (see input.lua, look.lua), built by `./setup plugins`
--
-- Only reload once something is built: otherwise hyprpm shows a headers
-- notification on every login. Its store is per user under /var/cache.
--
-- A terminal on `./setup plugins`, which asks for the password hyprpm needs,
-- when an install run outside the session left them to this one, or when
-- they no longer load because Hyprland was updated under them. `hyprpm
-- reload` reports success either way; the plugin list is what says.
local apps = require("modules.programs")
hl.on("hyprland.start", function()
    hl.exec_cmd('s="${XDG_STATE_HOME:-$HOME/.local/state}/impasto"; '
        .. 'if test -f "$s/plugins-pending"; then r=$(cat "$s/plugins-pending"); '
        .. 'elif test -d "/var/cache/hyprpm/$USER" && { hyprpm reload; '
        .. 'hyprctl plugin list | grep -q "^no plugins loaded" && hyprpm list | grep -q true; }; then r=$(sed -n 3p "$s/version"); '
        .. 'else exit 0; fi; '
        .. 'test -x "$r/setup" && ' .. apps.terminal .. ' --hold "$r/setup" plugins')
end)

-- · polkit agent
--
-- Without one, privileged requests (mounting a disk, etc.) fail silently.
local polkit_agent = "/usr/lib/polkit-kde-authentication-agent-1"
hl.on("hyprland.start", function()
    hl.exec_cmd("test -x " .. polkit_agent .. " && " .. polkit_agent)
end)
