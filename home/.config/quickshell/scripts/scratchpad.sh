#!/usr/bin/env bash
# Toggle a scratchpad: the special workspace called NAME. When it holds no
# window and a command is given, the command is started on it first.
#
#   scratchpad.sh NAME [COMMAND]     COMMAND is a shell line: an app, or a script's path
set -euo pipefail

name="${1:?usage: scratchpad.sh NAME [COMMAND]}"
command_line="${2:-}"

window_count="$(hyprctl workspaces -j \
    | jq --arg name "special:$name" '[.[] | select(.name == $name) | .windows] | add // 0')"

if [[ $window_count -eq 0 && -n $command_line ]]; then
    # Its own systemd scope under UWSM, so the app does not die with the shell.
    if command -v uwsm-app >/dev/null; then
        command_line="uwsm-app -- sh -c $(printf '%q' "$command_line")"
    fi
    # A JSON string is a valid Lua string literal.
    lua_command="$(jq -Rn --arg command "$command_line" '$command')"
    hyprctl dispatch "hl.dsp.exec_cmd($lua_command, { workspace = \"special:$name\" })" >/dev/null
fi
hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$name\")" >/dev/null
