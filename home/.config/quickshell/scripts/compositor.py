#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   C O M P O S I T O R                                                    │
# │   live hyprland options, read and set                                    │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Read and set Hyprland options, and restore them after a reload.

`hyprctl getoption` answers in a different shape per option (int, float, bool,
string, or a CSS-style four-value string for gaps); they are normalised here.

The Lua config is never written. The shell keeps its values in its own
settings and re-applies them with `apply` at login and after every reload,
since a reload re-reads the config; `hypr/look.lua` holds the defaults.

`hyprctl keyword` does not work with a Lua config (it prints an error and
exits 0), so options are set with `hyprctl eval`, turning an option path into
the nested table the config would contain:

    general:snap:enabled  ->  hl.config({ general = { snap = { enabled = ... } } })

Success is the literal "ok" on stdout, not the exit status.
"""

import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

# The options the settings window exposes, and how to read each answer.
OPTIONS = [
    ("general:gaps_in", "gaps"),
    ("general:gaps_out", "gaps"),
    ("general:border_size", "int"),
    # dwindle, master or scrolling, for every workspace.
    ("general:layout", "str"),
    ("decoration:rounding", "int"),
    ("decoration:active_opacity", "float"),
    ("decoration:inactive_opacity", "float"),
    ("decoration:blur:enabled", "bool"),
    ("decoration:blur:size", "int"),
    ("decoration:blur:passes", "int"),
    ("input:kb_layout", "str"),
    # The layout-switch key; without one a second layout is unreachable.
    ("input:kb_options", "str"),
    ("input:repeat_rate", "int"),
    ("input:sensitivity", "float"),
]

# The xkb layout list. evdev is what Hyprland uses; base is its older name.
XKB_RULES = (
    "/usr/share/X11/xkb/rules/evdev.lst",
    "/usr/share/X11/xkb/rules/base.lst",
)

# Values are pasted into a Lua chunk, so they are validated first: numbers and
# booleans go unquoted; strings (layouts, and xkb options such as
# `grp:alt_shift_toggle`) are limited to characters that cannot end the string.
NUMBER = re.compile(r"-?\d+(\.\d+)?|true|false")
STRING = re.compile(r"[A-Za-z0-9_,:+-]*")


def lua_chunk(option, literal):
    """`decoration:blur:size` and `4` into `{ decoration = { blur = { size = 4 } } }`."""
    keys = [key for part in option.split(":") for key in part.split(".")]
    body = literal
    for key in reversed(keys):
        body = "{ %s = %s }" % (key, body)
    return body


def hyprctl(*arguments):
    if not shutil.which("hyprctl"):
        return None
    try:
        result = subprocess.run(
            ["hyprctl", *arguments], capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return result if result.returncode == 0 else None


def literal_for(option, value):
    """The Lua literal for a value, or None if it fails validation.

    This is the only check between the settings window and `hyprctl eval`.
    """
    kinds = dict(OPTIONS)
    if option not in kinds:
        return None
    text = str(value)
    if kinds[option] == "str":
        return f'"{text}"' if STRING.fullmatch(text) else None
    return text if NUMBER.fullmatch(text) else None


def get(option, kind):
    result = hyprctl("getoption", option, "-j")
    if result is None:
        return None
    try:
        payload = json.loads(result.stdout)
    except ValueError:
        return None

    if kind == "gaps":
        # Gaps answer as a CSS-style "3 3 3 3"; the first value is the one the
        # panel edits, and setting one sets all four.
        css = payload.get("css") or ""
        first = css.split()[0] if css.split() else None
        return int(first) if first and first.lstrip("-").isdigit() else payload.get("int")
    if kind == "int":
        return payload.get("int")
    if kind == "bool":
        # Answered as a JSON bool, not an int.
        value = payload.get("bool")
        return int(value) if isinstance(value, bool) else None
    if kind == "float":
        value = payload.get("float")
        return round(value, 3) if isinstance(value, (int, float)) else None
    return payload.get("str")


def layouts():
    """Every keyboard layout xkb knows, as {id, label}, from the rules list."""
    for path in XKB_RULES:
        try:
            with open(path, encoding="utf-8", errors="replace") as handle:
                lines = handle.read().splitlines()
        except OSError:
            continue

        found = []
        inside = False
        for line in lines:
            # The file is sections introduced by "! <name>"; everything until
            # the next "!" belongs to the one before it.
            if line.startswith("!"):
                inside = line.strip() == "! layout"
                continue
            if not inside or not line.strip():
                continue
            parts = line.strip().split(None, 1)
            if len(parts) == 2:
                found.append({"id": parts[0], "label": parts[1]})
        if found:
            return found
    return []


# ── THE CURSOR ──────────────────────────────────────────────────────────────
#
# One vector cursor, recoloured. `./setup cursors` fetches Bibata's SVGs into
# the state directory; this paints every shape's body in one colour, compiles
# it with `hyprcursor-util`, installs it and sets it. The outline stays white,
# or turns black when the colour is light. The busy spinner's four colours are
# not in the body set, so they survive.
#
# Each build gets a new name (`impasto-cursor-<n>`): hypr-dynamic-cursors
# caches the magnified cursor by theme name, so rebuilding under the same name
# leaves the shake cursor in the old colour. `impasto-cursor` itself is the
# seed `env.lua` names for the moment before the shell is up.
#
# Builds are serialised by a lock in the runtime directory, shared by every
# shell this user runs: Hyprland parses the theme inside `setcursor`, and a
# manifest removed or rewritten mid-parse crashes hyprcursor's parser and the
# compositor with it. The next serial is also derived from the icons
# directory, so two state directories cannot collide, and clean-up keeps the
# previous build, which a nested session may still be using.

STATE_DIR = (os.environ.get("XDG_STATE_HOME")
             or os.path.join(os.path.expanduser("~"), ".local", "state"))
CURSOR_SRC = os.path.join(STATE_DIR, "quickshell", "cursor-src")
CURSOR_ICONS = os.path.join(os.path.expanduser("~"), ".local", "share", "icons")
CURSOR_BASE = "impasto-cursor"
CURSOR_SERIAL = os.path.join(STATE_DIR, "quickshell", "cursor-serial")
CURSOR_LOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir(),
                           "impasto-cursor.lock")
CURSOR_KEEP = 2

# Bibata's body colours (black, and the orange of the arrows) and its white
# outline. The spinner's colours are deliberately absent.
CURSOR_BODY = ("#000000", "#ff8300")
CURSOR_OUTLINE = "#ffffff"


def accent_from_state():
    """The palette accent the shell last wrote to disk, for `./setup cursors`.

    The shell itself resolves "palette" and passes a `#rrggbb`.
    """
    path = os.path.join(STATE_DIR, "quickshell", "dynamic-colors.json")
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle).get("accent") or "#2e509e"
    except (OSError, ValueError):
        return "#2e509e"


def plugin_available(option):
    """Whether the plugin owning an option is loaded, so its toggle can dim.

    A loaded plugin's option answers `getoption` with a JSON object; otherwise
    hyprctl prints "no such option", which is not JSON.
    """
    if not option.startswith("plugin:"):
        return False
    result = hyprctl("getoption", option, "-j")
    if result is None:
        return False
    try:
        return isinstance(json.loads(result.stdout), dict)
    except ValueError:
        return False


def is_light(hexcolour):
    r, g, b = (int(hexcolour[i:i + 2], 16) for i in (1, 3, 5))
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 > 0.6


def recolour_svg(text, body, outline):
    # Through placeholders: replacing directly, a white body would be turned
    # black along with the outline when the outline flips.
    text = re.sub(re.escape(CURSOR_OUTLINE), "__OUTLINE__", text, flags=re.IGNORECASE)
    for source in CURSOR_BODY:
        text = re.sub(re.escape(source), "__BODY__", text, flags=re.IGNORECASE)
    return text.replace("__BODY__", body).replace("__OUTLINE__", outline)


def cursor_builds():
    """The serial builds on disk, newest first, as (serial, name)."""
    found = []
    try:
        for entry in os.listdir(CURSOR_ICONS):
            number = entry[len(CURSOR_BASE) + 1:]
            if entry.startswith(CURSOR_BASE + "-") and number.isdigit():
                found.append((int(number), entry))
    except OSError:
        pass
    return sorted(found, reverse=True)


def next_cursor_name():
    """The next never-before-used theme name, so the plugin reloads (see above)."""
    serial = 0
    try:
        with open(CURSOR_SERIAL, encoding="utf-8") as handle:
            serial = int(handle.read().strip() or "0")
    except (OSError, ValueError):
        serial = 0
    builds = cursor_builds()
    serial = max(serial, builds[0][0] if builds else 0) + 1
    try:
        os.makedirs(os.path.dirname(CURSOR_SERIAL), exist_ok=True)
        with open(CURSOR_SERIAL, "w", encoding="utf-8") as handle:
            handle.write(str(serial))
    except OSError:
        pass
    return "%s-%d" % (CURSOR_BASE, serial)


def build_cursor(hexcolour, size, seed=False):
    """Paint the base SVGs one colour, compile them, install and set them.

    `seed` builds the stable `impasto-cursor` env.lua names, for
    `./setup cursors`; otherwise each build takes the next serial name so the
    plugin reloads.
    """
    if not re.fullmatch(r"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})", hexcolour):
        sys.stderr.write("cursor takes a #rrggbb colour, got %r\n" % hexcolour)
        return 1
    # QML may pass Qt's #aarrggbb; the last six digits are the colour.
    hexcolour = "#" + hexcolour[-6:]
    if not shutil.which("hyprcursor-util"):
        sys.stderr.write("hyprcursor-util is not installed (package: hyprcursor)\n")
        return 1
    if not os.path.isfile(os.path.join(CURSOR_SRC, "manifest.hl")):
        sys.stderr.write("no cursor source at %s - run `./setup cursors`\n"
                         % CURSOR_SRC)
        return 1

    try:
        os.makedirs(os.path.dirname(CURSOR_LOCK), exist_ok=True)
        lock = open(CURSOR_LOCK, "w")
    except OSError as error:
        sys.stderr.write("cannot open the cursor lock: %s\n" % error)
        return 1
    with lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return install_cursor(hexcolour, size, seed)


def install_cursor(hexcolour, size, seed):
    """`build_cursor`'s work, run with the lock held."""
    name = CURSOR_BASE if seed else next_cursor_name()
    dest = os.path.join(CURSOR_ICONS, name)
    outline = "#000000" if is_light(hexcolour) else CURSOR_OUTLINE
    with tempfile.TemporaryDirectory() as work:
        src = os.path.join(work, "src")
        shutil.copytree(CURSOR_SRC, src)

        # The theme's name is the directory's, so `setcursor` resolves it.
        manifest = os.path.join(src, "manifest.hl")
        with open(manifest, encoding="utf-8") as handle:
            named = re.sub(r"(?m)^name\s*=.*$", "name = " + name, handle.read())
        with open(manifest, "w", encoding="utf-8") as handle:
            handle.write(named)

        for base, _, files in os.walk(src):
            for svg_name in files:
                if not svg_name.endswith(".svg"):
                    continue
                path = os.path.join(base, svg_name)
                with open(path, encoding="utf-8") as handle:
                    svg = handle.read()
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(recolour_svg(svg, hexcolour, outline))

        out = os.path.join(work, "out")
        os.makedirs(out, exist_ok=True)
        built = subprocess.run(
            ["hyprcursor-util", "--create", src, "--output", out],
            capture_output=True, text=True)
        theme = os.path.join(out, "theme_" + name)
        if built.returncode != 0 or not os.path.isdir(theme):
            sys.stderr.write("hyprcursor-util failed:\n" + (built.stderr or ""))
            return 1
        os.makedirs(CURSOR_ICONS, exist_ok=True)
        if os.path.isdir(dest):
            shutil.rmtree(dest)
        shutil.move(theme, dest)

    # Best effort: with no session there is nothing to set, but the theme is
    # built either way.
    hyprctl("setcursor", name, str(size))

    # Drop the older serial builds, keeping the seed, the one just set and
    # the one before it.
    if not seed:
        for _, entry in cursor_builds()[CURSOR_KEEP:]:
            if entry != name:
                shutil.rmtree(os.path.join(CURSOR_ICONS, entry), ignore_errors=True)
    return 0


RULES_FILE = os.path.expanduser("~/.config/hypr/modules/windowrules.lua")


def parse_lua_table(text, i):
    """Parse a Lua table literal; returns (entries, end).

    Entries are (key, value) pairs, key None for a positional value, value a
    string or a nested entry list. Not a Lua parser: it handles only the value
    types windowrules.lua uses (strings, numbers, booleans and tables).
    """
    entries = []
    key = None
    i += 1
    while i < len(text):
        char = text[i]
        if char.isspace() or char == ",":
            i += 1
            continue
        if char == "}":
            return entries, i + 1
        named = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*=", text[i:])
        if named and key is None:
            key = named.group(1)
            i += named.end()
            continue
        if char == '"':
            literal = re.match(r'"((?:[^"\\]|\\.)*)"', text[i:])
            value = literal.group(1).replace('\\\\', '\\')
            i += literal.end()
        elif char == "{":
            value, i = parse_lua_table(text, i)
        else:
            bare = re.match(r"[^,}\s]+", text[i:])
            value = bare.group(0)
            i += bare.end()
        entries.append((key, value))
        key = None
    return entries, i


def spell_value(value):
    if isinstance(value, list):
        parts = [spell_value(entry) for _key, entry in value]
        if all(re.fullmatch(r"-?\d+", part) for part in parts):
            return " × ".join(parts)
        return ", ".join(parts)
    return str(value)


def window_rules():
    """The rules in windowrules.lua, as shapes a panel can draw. Read-only."""
    try:
        with open(RULES_FILE, encoding="utf-8", errors="replace") as handle:
            source = handle.read()
    except OSError:
        return []
    # Line comments go first; no string in this file carries a "--".
    source = "\n".join(line.split("--", 1)[0] for line in source.splitlines())

    found = []
    for opening in re.finditer(r"hl\.window_rule\s*\(\s*\{", source):
        entries, _end = parse_lua_table(source, opening.end() - 1)
        name = ""
        matches = []
        effects = []
        for key, value in entries:
            if key == "name":
                name = str(value)
            elif key == "match" and isinstance(value, list):
                for criterion, wanted in value:
                    if wanted in ("true", "false"):
                        matches.append(criterion if wanted == "true"
                                       else f"not {criterion}")
                    else:
                        matches.append(f"{criterion} {spell_value(wanted)}")
            elif key is not None:
                shown = key.replace("_", " ")
                if value == "true":
                    effects.append(shown)
                elif value != "false":
                    effects.append(f"{shown} {spell_value(value)}")
        found.append({
            "name": name.replace("-", " "),
            "match": "  ·  ".join(matches),
            "effects": effects,
        })
    return found


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "get"

    if action == "layouts":
        print(json.dumps(layouts()))
    elif action == "available":
        if len(sys.argv) < 3:
            sys.stderr.write("Usage: compositor.py available plugin:<name>:<option>\n")
            sys.exit(1)
        print("true" if plugin_available(sys.argv[2]) else "false")
    elif action == "cursor":
        rest = sys.argv[2:]
        seed = "--seed" in rest
        rest = [arg for arg in rest if arg != "--seed"]
        if len(rest) >= 2:
            colour = accent_from_state() if rest[0] == "palette" else rest[0]
            sys.exit(build_cursor(colour, rest[1], seed=seed))
        sys.stderr.write("Usage: compositor.py cursor <#rrggbb|palette> <size> [--seed]\n")
        sys.exit(1)
    elif action == "rules":
        print(json.dumps(window_rules()))
    elif action == "get":
        print(json.dumps({option: get(option, kind) for option, kind in OPTIONS}))
    elif action in ("set", "apply"):
        if action == "set" and len(sys.argv) >= 4:
            wanted = {sys.argv[2]: sys.argv[3]}
        elif action == "apply" and len(sys.argv) >= 3:
            try:
                wanted = json.loads(sys.argv[2])
            except ValueError:
                sys.stderr.write("apply takes a JSON object of option -> value\n")
                sys.exit(1)
            if not isinstance(wanted, dict):
                sys.stderr.write("apply takes a JSON object of option -> value\n")
                sys.exit(1)
        else:
            sys.stderr.write("Usage: compositor.py set <option> <value>\n")
            sys.exit(1)

        chunks = []
        for option, value in wanted.items():
            literal = literal_for(option, value)
            if literal is None:
                sys.stderr.write(f"Refusing to set {option} to {value!r}\n")
                sys.exit(1)
            chunks.append(f"hl.config({lua_chunk(option, literal)})")

        if not chunks:
            sys.exit(0)

        # One eval for all of them: one per option is a process each and a
        # visible re-layout after every one.
        result = hyprctl("eval", " ".join(chunks))
        # hyprctl exits 0 regardless; only its output says whether it worked.
        if result is None or result.stdout.strip() != "ok":
            sys.stderr.write((result.stdout if result else "hyprctl is not here") + "\n")
            sys.exit(1)
        sys.exit(0)
    else:
        sys.stderr.write(
            "Usage: compositor.py get | set <option> <value> | apply <json>"
            " | layouts | cursor <#rrggbb|palette> <size> [--seed]"
            " | available plugin:<name>:<option> | rules\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
