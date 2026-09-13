#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   T H E M E   M A N A G E R                                              │
# │   wallpapers and adaptive palette · quickshell backend                   │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Wallpaper and palette backend for the Quickshell shell.

Sets the wallpaper, extracts a palette from it, and writes that palette into
the other themed programs: kitty, btop, cava, yazi, neovim, imv, GTK, Qt and
KDE, the Papirus folder icons, Vesktop, Spotify, VSCodium and Zen. Generated
files live in the XDG state directory unless a program only reads its theme
from its own config directory.
"""

import colorsys
import configparser
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
from xml.sax.saxutils import escape

# Sibling module with the greeting's pixel-art scenes.
import greeting

XDG_CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
XDG_DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
XDG_STATE_HOME = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")

WALLPAPERS_DIR = os.path.join(XDG_DATA_HOME, "wallpapers")
STATE_DIR = os.path.join(XDG_STATE_HOME, "quickshell")
STATE_FILE = os.path.join(STATE_DIR, "state.json")
TERMINAL_PALETTE_FILE = os.path.join(STATE_DIR, "kitty-palette.conf")
# Separate from the palette fragment, which is rewritten whole on every push.
TERMINAL_FONT_FILE = os.path.join(STATE_DIR, "kitty-font.conf")

# kitty appends `-<pid>` to `listen_on`, so this globs every running
# instance. Reaching none is fine: new terminals read the fragment anyway.
XDG_RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
KITTY_SOCKETS = os.path.join(XDG_RUNTIME_DIR, "kitty.sock*")

# The terminal background: the accent scaled towards black, so it follows the
# wallpaper and always stays dark. The palette's own background is not used
# because some palettes are light (Catppuccin Latte). kitty draws it at 0.90
# opacity over the blurred wallpaper, which lightens it further; 0.22 accounts
# for that.
TERMINAL_TINT = 0.22

# What kitty.conf falls back to when nothing has been pushed yet.
TERMINAL_BACKGROUND_FALLBACK = "#000000"


def terminal_background(colors):
    """The tinted near-black this palette's terminal sits on."""
    return rgb_to_hex(*(channel * TERMINAL_TINT for channel in hex_to_rgb(colors["accent"])))

# ANSI slot -> palette key. Black and magenta have no source in the palette
# and keep kitty.conf's values. Cyan carries the accent: it is the only one of
# the eight with no conventional meaning (red, green and yellow mean error,
# success and warning), and LS_COLORS uses magenta far more than cyan.
TERMINAL_NORMAL = (("color1", "red"), ("color2", "green"), ("color3", "yellow"),
                   ("color4", "blue"), ("color6", "accent"), ("color7", "textMuted"))
TERMINAL_BRIGHT = (("color9", "red"), ("color10", "green"), ("color11", "yellow"),
                   ("color12", "blue"), ("color14", "accent"), ("color15", "text"))
# The cursor stays white (set in kitty.conf) so it is visible in any palette.
TERMINAL_ACCENT = ("selection_background", "active_tab_background")

# WCAG contrast floors: AA for the normal slots, AAA for the bright ones.
MIN_CONTRAST = 4.5
MIN_CONTRAST_BRIGHT = 7.0
DYNAMIC_COLORS_FILE = os.path.join(STATE_DIR, "dynamic-colors.json")

# btop resolves `color_theme` by name inside its own themes directory and
# ignores absolute paths, so the theme is written there. ./setup never touches
# files it did not install, so the two can share the directory.
BTOP_DIR = os.path.join(XDG_CONFIG_HOME, "btop")
BTOP_THEME_FILE = os.path.join(BTOP_DIR, "themes", "impasto.theme")

# GTK reads gtk.css only from its own config directory.
GTK3_DIR = os.path.join(XDG_CONFIG_HOME, "gtk-3.0")
GTK4_DIR = os.path.join(XDG_CONFIG_HOME, "gtk-4.0")
GTK3_CSS_FILE = os.path.join(GTK3_DIR, "gtk.css")
GTK4_CSS_FILE = os.path.join(GTK4_DIR, "gtk.css")

# GTK windows: the palette's background is the window ground and its surface
# is anything raised (header bars, popovers, sidebars). The island's black is
# shell-only and not used here.
GTK_MIN_CONTRAST = 4.5

# Both GTK grounds are tinted towards the accent. The adaptive palette's
# background barely changes between wallpapers, and a GTK toolbar has nothing
# else on it that carries the wallpaper's colour. Light palettes take a
# smaller tint, since a pale ground shifts hue much faster.
GTK_TINT_DARK = 0.18
GTK_TINT_LIGHT = 0.07
GTK_LIGHT_ABOVE = 0.5

# Thunar's inactive split pane (theme_unfocused_bg_color): halfway from the
# ground to the surface, visible without reading as a toolbar.
GTK_DIM = 0.5

# ── FOLDER ICONS ────────────────────────────────────────────────────────────
#
# Folder icons follow the accent by picking the nearest of Papirus's folder
# colours. The push writes a small icon theme that inherits Papirus-Dark and
# symlinks each folder icon to the chosen colour, so nothing under /usr/share
# is touched (papirus-folders needs root for that). A theme of our own, rather
# than overrides in a local Papirus-Dark/, can be deleted cleanly and never
# shadows the package's files.
ICON_THEME_NAME = "impasto"
ICON_THEME_DIR = os.path.join(XDG_DATA_HOME, "icons", ICON_THEME_NAME)
ICON_INDEX_FILE = os.path.join(ICON_THEME_DIR, "index.theme")

# Records the swatch last written, so a push that lands on the same one skips
# rebuilding ~2000 symlinks.
ICON_STAMP_FILE = os.path.join(ICON_THEME_DIR, "impasto.colour")

ICON_SOURCE_THEME = "Papirus-Dark"
ICON_INHERITS = (ICON_SOURCE_THEME, "Adwaita", "hicolor")

# A `folder-<name>.svg` is a colour (rather than a specific folder such as
# folder-documents) when these variants of it exist too. Detecting colours
# this way avoids hard-coding Papirus's list.
ICON_COLOUR_PROOF = ("open", "documents")

# The swatch colour is read from one size; it is the same in all of them.
ICON_SWATCH_SIZE = "48x48"
ICON_SWATCH_PATTERN = re.compile(r"fill:(#[0-9a-fA-F]{6})")

# Most of Papirus's folder names are symlinks into the default (blue) set:
# folder.svg -> folder-blue.svg, user-desktop.svg -> user-blue-desktop.svg,
# folder-publicshare.svg -> folder-image-people.svg ->
# folder-blue-image-people.svg. So the names to re-point are every name in
# places/ that resolves into the default colour's set, except names that
# already specify a colour.
ICON_ALIAS_PATTERN = re.compile(r"^(folder|user)-([a-z0-9]+)(-.*)?\.svg$")

# The default colour is whatever folder.svg points at.
ICON_REFERENCE_NAME = "folder.svg"


# Colour distance weights hue heavily: a folder reads as blue or orange before
# it reads as light or dark. Accents below ICON_GREY_BELOW saturation only
# match the grey swatches.
ICON_HUE_WEIGHT = 6.0
ICON_GREY_BELOW = 0.15


# Vesktop: Discord draws from CSS custom properties and Vencord loads user
# themes after Discord's own stylesheet, so redefining the properties is
# enough. No class names, which Discord hashes per build.
VESKTOP_DIR = os.path.join(XDG_CONFIG_HOME, "vesktop")
VESKTOP_THEMES_DIR = os.path.join(VESKTOP_DIR, "themes")
VESKTOP_THEME_FILE = os.path.join(VESKTOP_THEMES_DIR, "impasto.css")

# Vencord's own settings, where a theme is ticked. Only `./setup vesktop`
# writes it, once, with Vesktop closed; the push never does.
VESKTOP_SETTINGS_FILE = os.path.join(VESKTOP_DIR, "settings", "settings.json")

# Discord uses three background levels and the palette has two. The third
# (server rail, search field) is the ground darkened towards black, as in
# Discord's own themes.
VESKTOP_DEEP = 0.35

# A lower floor for muted text than for normal text, so the two stay distinct
# after lift().
VESKTOP_MUTED_CONTRAST = 3.0

# Discord's accent is a ramp from --brand-100 (light) to --brand-900 (dark),
# and hover/press use the neighbouring rungs. The accent sits at 500 and the
# ends move VESKTOP_RAMP towards white and black.
VESKTOP_RAMP = 0.60

# The rungs Discord defines (irregular, so not a range).
VESKTOP_STEPS = (100, 130, 160, 200, 230, 260, 300, 330, 360, 400, 430, 460,
                 500, 530, 560, 600, 630, 660, 700, 730, 760, 800, 830, 860,
                 900)

# spicetify compiles the colours into the Spotify client. `./setup spotify`
# patches it once; after that the push refreshes the stylesheets inside it,
# which the client reads on its next start.
SPICETIFY_DIR = (os.environ.get("SPICETIFY_CONFIG")
                 or os.path.join(XDG_CONFIG_HOME, "spicetify"))
SPICETIFY_CONFIG_FILE = os.path.join(SPICETIFY_DIR, "config-xpui.ini")
SPICETIFY_THEME_DIR = os.path.join(SPICETIFY_DIR, "Themes", "impasto")
SPICETIFY_COLORS_FILE = os.path.join(SPICETIFY_THEME_DIR, "color.ini")

# Spotify has one ground with cards on it. The sidebar and player bar sit on
# the ground, and the shadow is darker than both.
SPICETIFY_SHADOW = 0.45

# Disabled controls and hairlines: muted text and border mixed towards the
# ground, since the palette has no colour for either.
SPICETIFY_DISABLED = 0.45

# VSCodium colour themes are extensions. The push writes a manifest and the
# theme JSON into ~/.vscode-oss/extensions/ (VSCodium's dataFolderName), which
# the editor loads on its next window without anything being installed.
VSCODIUM_EXTENSION_DIR = os.path.expanduser("~/.vscode-oss/extensions/impasto")
VSCODIUM_MANIFEST_FILE = os.path.join(VSCODIUM_EXTENSION_DIR, "package.json")
VSCODIUM_THEME_FILE = os.path.join(VSCODIUM_EXTENSION_DIR, "themes",
                                   "impasto-color-theme.json")

# The theme's name in the picker and in `workbench.colorTheme`. The push never
# selects it, so a theme picked by hand stays picked.
VSCODIUM_LABEL = "Impasto"

# Merged whole by `./setup vscodium`. The pushes only rewrite, in place, the
# values that follow the palette and the font, and only where they are set.
VSCODIUM_SETTINGS_FILE = os.path.join(XDG_CONFIG_HOME, "VSCodium", "User",
                                      "settings.json")

# Read for the monospace family, so the editor uses the same font as kitty.
SHELL_SETTINGS_FILE = os.path.join(STATE_DIR, "settings.json")
DEFAULT_MONO = "JetBrainsMono Nerd Font Mono, monospace"

# Alpha for the 1px indent-rainbow guides; full-strength colours are too loud
# at that width.
VSCODIUM_GUIDE = "40"

# The editor is the ground; the side bar, tabs, panel and status bar are
# darkened below it, as in VS Code's Dark Modern. Lighter than Vesktop's 0.35,
# since here the chrome frames all four sides of the window.
VSCODIUM_CHROME = 0.18

# Error Lens draws its band over the code, so it is a light wash rather than a
# fill. 0.18 is the largest value that keeps code on the band at 4.5:1 in every
# bundled palette (Catppuccin Latte's red is the tightest).
VSCODIUM_LENS_WASH = 0.18

# kitty's ANSI slots under VS Code's names. Magenta and bright black are absent
# from TERMINAL_NORMAL/BRIGHT, so VS Code's defaults fill them.
VSCODIUM_ANSI = {
    "color1": "ansiRed", "color2": "ansiGreen", "color3": "ansiYellow",
    "color4": "ansiBlue", "color6": "ansiCyan", "color7": "ansiWhite",
    "color9": "ansiBrightRed", "color10": "ansiBrightGreen",
    "color11": "ansiBrightYellow", "color12": "ansiBrightBlue",
    "color14": "ansiBrightCyan", "color15": "ansiBrightWhite",
}

# Qt applications take their QPalette from the platform theme, here qt6ct
# (QT_QPA_PLATFORMTHEME=qt6ct in env.lua). qt6ct refers to its colour scheme
# by absolute path, so both files are generated rather than shipped in the
# repository; changes made in the qt6ct GUI are overwritten on the next push.
QT6CT_DIR = os.path.join(XDG_CONFIG_HOME, "qt6ct")
QT6CT_CONFIG_FILE = os.path.join(QT6CT_DIR, "qt6ct.conf")
QT6CT_COLORS_FILE = os.path.join(QT6CT_DIR, "colors", "impasto.conf")

# Fusion draws every widget from the palette; Kvantum would bring its own SVG
# theme.
QT6CT_STYLE = "Fusion"

# Most of the Qt applications in use are KDE's, which expect Breeze icons.
QT6CT_ICONS = "breeze"

# QPalette roles in Qt's enum order: qt6ct's format is positional. Accent
# (Qt 6.6+) is last, so an older Qt ignores it.
QT_ROLES = (
    "WindowText", "Button", "Light", "Midlight", "Dark", "Mid", "Text",
    "BrightText", "ButtonText", "Base", "Window", "Shadow", "Highlight",
    "HighlightedText", "Link", "LinkVisited", "AlternateBase", "NoRole",
    "ToolTipBase", "ToolTipText", "PlaceholderText", "Accent",
)

# Fusion draws buttons as bevels from five shades. They are derived from the
# raised surface, towards white and black, so the bevel stays one object.
QT_BEVEL_LIGHT = 0.12
QT_BEVEL_MIDLIGHT = 0.05
QT_BEVEL_MID = 0.12
QT_BEVEL_DARK = 0.28
QT_BEVEL_SHADOW = 0.55

# How far disabled text and selection fade towards the ground.
QT_DISABLED = 0.55

# KDE applications ignore the QPalette and read colours through KColorScheme,
# i.e. kdeglobals. Without it they stay in Breeze's light grey.
KDEGLOBALS_FILE = os.path.join(XDG_CONFIG_HOME, "kdeglobals")

# KColorScheme colour sets. Window and View are the ground; Button, Tooltip
# and Header are raised. Complementary (the inverse set) gets the ground too.
KDE_GROUND_SETS = ("Window", "View", "Complementary")
KDE_RAISED_SETS = ("Button", "Tooltip", "Header")

# kdeglobals is merged through a parser that drops comments, so the scheme
# name is the only marker of what wrote it.
KDE_SCHEME_NAME = "Impasto"

# How far ForegroundInactive on a selection fades towards the accent.
KDE_SELECTION_QUIET = 0.35


def gtk_ground(value, accent):
    """Tint a GTK surface towards the accent."""
    lit = luminance(*hex_to_rgb(value)) > GTK_LIGHT_ABOVE
    return mix(value, accent, GTK_TINT_LIGHT if lit else GTK_TINT_DARK)

# btop wants 48 colours; single-hue meters are ramped from a dimmed version of
# the hue up to a brightened one.
BTOP_RAMP_DIM = 0.55

# Shared by the terminal programs. Disabled text and hairlines are derived
# from the muted text and border, mixed towards the background; a fixed grey
# could end up brighter than lifted text on some palettes.
TERMINAL_DIM = 0.55
TERMINAL_LINE = 0.45

# Fills behind text are built from the terminal background, not from the
# palette's surfaces (those assume the palette's own background, which may be
# light).
TERMINAL_RAISE = 0.14
TERMINAL_STATE_FILL = 0.40

# TextMate scopes shared by yazi's tmTheme and VSCodium's tokenColors, so a
# file looks the same in both. The accent goes on keywords. `comment` is not a
# palette key: each caller dims the muted colour by its own amount.
SYNTAX_SCOPES = (
    ("Comment", "comment", "comment", "italic"),
    ("String", "string", "green", None),
    ("Number and constant", "constant.numeric, constant.language, constant.character",
     "yellow", None),
    ("Keyword", "keyword, storage, storage.modifier", "accent", None),
    ("Operator and punctuation", "keyword.operator, punctuation", "textMuted", None),
    ("Function", "entity.name.function, support.function", "blue", None),
    ("Type and class", "entity.name.type, entity.name.class, storage.type, "
                       "support.type, support.class", "accentHover", None),
    ("Tag", "entity.name.tag", "red", None),
    ("Attribute", "entity.other.attribute-name", "yellow", None),
    ("Variable", "variable, variable.parameter", "text", None),
    ("Invalid", "invalid", "red", "bold"),
)

# yazi resolves `[flavor] dark` by name to flavors/<name>.yazi/, which holds
# the interface theme and a tmTheme for the preview pane.
YAZI_DIR = os.path.join(XDG_CONFIG_HOME, "yazi")
YAZI_FLAVOR_DIR = os.path.join(YAZI_DIR, "flavors", "impasto.yazi")
YAZI_FLAVOR_FILE = os.path.join(YAZI_FLAVOR_DIR, "flavor.toml")
YAZI_TMTHEME_FILE = os.path.join(YAZI_FLAVOR_DIR, "tmtheme.xml")

# Marked files use a dimmer accent than selected ones.
YAZI_MARKED_DIM = 0.45

# The hovered row keeps each file's own colour, so it is raised half as much
# as other rows; at 0.14, muted names drop to 3.2:1 in some palettes.
YAZI_ROW_RAISE = 0.07

# Rounded powerline caps (Nerd Font), matching the bar's capsules.
YAZI_CAP_OPEN = "\ue0b6"
YAZI_CAP_CLOSE = "\ue0b4"


# neovim finds colourschemes on its runtimepath, which the config extends, so
# this one stays in the state directory instead of ~/.config/nvim.
NVIM_DIR = os.path.join(STATE_DIR, "nvim")
NVIM_COLORS_FILE = os.path.join(NVIM_DIR, "colors", "impasto.lua")

# neovim's default server socket: $XDG_RUNTIME_DIR/nvim.<pid>.0.
NVIM_SOCKETS = os.path.join(XDG_RUNTIME_DIR, "nvim.*.0")

# Comments are dimmed further than anything else.
NVIM_COMMENT_DIM = 0.35



# imv has no theme or include mechanism, so the push owns its whole config.
IMV_CONFIG_FILE = os.path.join(XDG_CONFIG_HOME, "imv", "config")

# The overlay is a caption over the picture: nearly opaque.
IMV_OVERLAY_ALPHA = "cc"

# imv's default overlay font is too large for the window.
IMV_OVERLAY_FONT = "monospace:11"


# cava resolves `theme` by name inside themes/, and a running cava can be told
# to reload it.
CAVA_DIR = os.path.join(XDG_CONFIG_HOME, "cava")
CAVA_THEME_FILE = os.path.join(CAVA_DIR, "themes", "impasto")

# The bars run from near the terminal ground up to the brightest accent,
# across the accent/accentHover pair. No red: loudness is not a warning.
CAVA_GRADIENT_DIM = 0.60

# Stable path to the current wallpaper, for anything outside the shell that
# wants it (hyprlock run by hand, for example).
CURRENT_WALLPAPER_LINK = os.path.join(STATE_DIR, "current-wallpaper")

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")

DEFAULT_STATE = {"activeTheme": "adaptive", "currentWallpaper": ""}

# Fallback accent when an image yields nothing usable.
NEUTRAL_ACCENT = {"hex": "#89B4FA", "r": 137, "g": 180, "b": 250}


def ensure_state_dir():
    os.makedirs(STATE_DIR, exist_ok=True)


def load_state():
    try:
        with open(STATE_FILE, encoding="utf-8") as handle:
            return {**DEFAULT_STATE, **json.load(handle)}
    except (OSError, ValueError):
        return dict(DEFAULT_STATE)


def save_state(state):
    ensure_state_dir()
    try:
        with open(STATE_FILE, "w", encoding="utf-8") as handle:
            json.dump(state, handle, indent=2)
    except OSError as error:
        sys.stderr.write(f"Cannot save state: {error}\n")


def get_current_wallpaper():
    state = load_state()
    stored = state.get("currentWallpaper")
    if stored and os.path.isfile(stored):
        return stored

    # Ask the running daemon before giving up; the state file may predate it.
    if shutil.which("awww"):
        try:
            result = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=5)
            match = re.search(r"image:\s*(/[^\s\n]+)", result.stdout)
            if match and os.path.isfile(match.group(1)):
                return match.group(1)
        except (OSError, subprocess.SubprocessError):
            pass
    return ""


def list_wallpapers():
    if not os.path.isdir(WALLPAPERS_DIR):
        return []
    entries = []
    for name in sorted(os.listdir(WALLPAPERS_DIR)):
        if name.startswith("."):
            continue
        path = os.path.join(WALLPAPERS_DIR, name)
        if os.path.isfile(path) and name.lower().endswith(IMAGE_EXTENSIONS):
            entries.append({"name": pretty_name(name), "path": path})
    return entries


def pretty_name(filename):
    """Turn a file name into something worth showing under a thumbnail."""
    stem = os.path.splitext(filename)[0]
    return stem.replace("-", " ").replace("_", " ").strip().title()


def rgb_to_hex(red, green, blue):
    clamp = lambda value: int(max(0, min(255, value)))
    return f"#{clamp(red):02x}{clamp(green):02x}{clamp(blue):02x}"


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def mix(value, other, amount):
    """`value` taken `amount` of the way towards `other`."""
    return rgb_to_hex(*(one + (two - one) * amount
                        for one, two in zip(hex_to_rgb(value), hex_to_rgb(other))))


def luminance(red, green, blue):
    return 0.2126 * (red / 255) + 0.7152 * (green / 255) + 0.0722 * (blue / 255)


def relative_luminance(red, green, blue):
    """WCAG relative luminance, gamma corrected.

    luminance() above is a cheap approximation for ranking swatches; contrast
    uses the WCAG formula.
    """
    def channel(value):
        value /= 255
        return value / 12.92 if value <= 0.03928 else ((value + 0.055) / 1.055) ** 2.4

    return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)


def contrast_on_terminal(value, background):
    pair = sorted((relative_luminance(*hex_to_rgb(value)),
                   relative_luminance(*hex_to_rgb(background))), reverse=True)
    return (pair[0] + 0.05) / (pair[1] + 0.05)


# The luminance at which black and white text have equal WCAG contrast:
# (L + 0.05)^2 = 1.05 * 0.05. Above it, moving away from the ground means
# getting darker.
CONTRAST_PIVOT = 0.179


def away(background):
    """Which way a colour has to move to get off this ground: +1 up, -1 down."""
    return -1 if relative_luminance(*hex_to_rgb(background)) > CONTRAST_PIVOT else 1


def lift(value, minimum, background):
    """Move a colour away from its background until it meets `minimum` contrast.

    Only lightness changes; hue and saturation are kept. The direction depends
    on the background (see CONTRAST_PIVOT), so light grounds work too.
    """
    if contrast_on_terminal(value, background) >= minimum:
        return value

    step = 0.01 * away(background)
    hue, lightness, sat = colorsys.rgb_to_hls(*(c / 255 for c in hex_to_rgb(value)))
    # Bounded: 100 steps of 0.01 cover the whole lightness range.
    for _ in range(100):
        lightness = min(1.0, max(0.0, lightness + step))
        candidate = rgb_to_hex(*(c * 255 for c in colorsys.hls_to_rgb(hue, lightness, sat)))
        if contrast_on_terminal(candidate, background) >= minimum:
            return candidate
        if lightness in (0.0, 1.0):
            break
    return "#ffffff" if step > 0 else "#000000"


def brighten(value, background):
    """The bright half of an ANSI pair: the same hue, further from the ground.

    Takes a fixed lightness step first and then applies the higher contrast
    floor; lifting alone leaves pale palettes with identical normal and bright
    slots.
    """
    hue, lightness, sat = colorsys.rgb_to_hls(*(c / 255 for c in hex_to_rgb(value)))
    stepped = rgb_to_hex(*(c * 255 for c in colorsys.hls_to_rgb(
        hue, min(1.0, max(0.0, lightness + 0.12 * away(background))), sat)))
    return lift(stepped, MIN_CONTRAST_BRIGHT, background)


def build_terminal_palette(colors):
    """The kitty conf fragment for a palette, slot by slot."""
    lines = [
        "# GENERATED by scripts/theme_manager.py on every palette change.",
        "# Included by kitty.conf; edits here are lost at the next theme switch.",
        "#",
        "# The background is the accent at 22%, so the window is tinted and always",
        "# dark; every colour below is measured against it and lifted if it falls",
        "# short. Magenta and the bright black have no source in a palette of",
        "# eight and are absent; kitty.conf keeps them. Cyan carries the accent",
        "# by decision, not by mapping — see theme_manager.py.",
        "",
    ]
    background = terminal_background(colors)
    lines.append(f"background {background}")

    # ANSI 0 is the background itself. It is only ever used as a fill (text in
    # kitty's default #4c4c4c is unreadable on this ground anyway), and at the
    # background colour kitty renders those cells translucent like the rest of
    # the window.
    lines.append(f"color0 {background}")
    lines.append("")
    for slot, key in TERMINAL_NORMAL:
        lines.append(f"{slot} {lift(colors[key], MIN_CONTRAST, background)}")
    for slot, key in TERMINAL_BRIGHT:
        lines.append(f"{slot} {brighten(colors[key], background)}")

    accent = lift(colors["accent"], MIN_CONTRAST, background)
    lines.append("")
    for slot in TERMINAL_ACCENT:
        lines.append(f"{slot} {accent}")
    lines.append(f"selection_foreground {background}")
    lines.append(f"active_tab_foreground {background}")
    lines.append(f"inactive_tab_background {background}")
    lines.append(f"inactive_tab_foreground {lift(colors['textMuted'], MIN_CONTRAST, background)}")
    return "\n".join(lines) + "\n"


def push_terminal_palette(colors):
    """Write the fragment, then repaint whatever is already open."""
    ensure_state_dir()
    with open(TERMINAL_PALETTE_FILE, "w", encoding="utf-8") as handle:
        handle.write(build_terminal_palette(colors))

    kitten = shutil.which("kitten")
    if not kitten:
        sys.stderr.write("kitten not found; the palette applies to new terminals only\n")
        return

    for socket_path in sorted(glob.glob(KITTY_SOCKETS)):
        # --configured: later windows of the same instance get it too.
        result = subprocess.run(
            [kitten, "@", "--to", f"unix:{socket_path}", "set-colors", "--all",
             "--configured", TERMINAL_PALETTE_FILE],
            capture_output=True, text=True)
        if result.returncode != 0:
            # A stale socket from a closed terminal is normal; keep going.
            sys.stderr.write(f"{os.path.basename(socket_path)}: "
                             f"{result.stderr.strip()}\n")


def write_greetings(colors):
    """Render the greeting's scenes in this palette.

    Uses the terminal's colours, lifted as in build_terminal_palette. greeting.py
    renders in the background, since all four scenes take about five seconds.
    """
    ground = terminal_background(colors)
    paint = {key: lift(colors[key], MIN_CONTRAST, ground)
             for key in ("accent", "green", "yellow", "red", "blue")}
    paint.update(ground=ground, text=colors["text"], muted=colors["textMuted"])
    greeting.push(paint)


def build_btop_theme(colors):
    """btop's 48 theme colours, derived from the palette's 13.

    Text colours are lifted against the terminal background, which btop draws
    on. Gradients that fill towards trouble (temperature, load, used memory)
    run green to red; free and available memory run the other way.
    """
    background = terminal_background(colors)

    def on(key):
        return lift(colors[key], MIN_CONTRAST, background)

    def ramp(key):
        return (mix(colors[key], background, BTOP_RAMP_DIM),
                on(key), brighten(colors[key], background))

    text, muted, accent = on("text"), on("textMuted"), on("accent")
    inactive = mix(muted, background, TERMINAL_DIM)
    line = mix(colors["border"], background, TERMINAL_LINE)
    raised = mix(background, text, TERMINAL_RAISE)
    following = mix(background, colors["accent"], TERMINAL_STATE_FILL)
    paused = mix(background, colors["red"], TERMINAL_STATE_FILL)
    # One banner foreground for all three fills, lifted against each. On these
    # dark fills lift() only raises lightness, so meeting the last floor keeps
    # the earlier ones.
    state_fg = colors["text"]
    for ground in (raised, following, paused):
        state_fg = lift(state_fg, MIN_CONTRAST, ground)
    filling = (on("green"), on("yellow"), on("red"))
    emptying = tuple(reversed(filling))

    groups = [
        ("""The ground and the type on it. `main_bg` is the colour kitty is set
        to, so turning `theme_background` on in btop.conf gets the terminal's
        own black rather than a hole; with it off, which is how this ships,
        btop never draws it at all.""",
         [("main_bg", background), ("main_fg", text),
          ("title", brighten(colors["text"], background)), ("hi_fg", accent),
          ("inactive_fg", inactive), ("graph_text", muted)]),

        ("""The selected process, in the one pair the shell already keeps for
        type on an accent — so the row is the same object the island draws
        when it highlights something.""",
         [("selected_bg", colors["accent"]), ("selected_fg", colors["accentText"]),
          ("proc_misc", accent)]),

        ("""The rest of the process box's states, and they are quieter than
        the selection on purpose: the cursor is where you are and these are
        what the list is doing. A followed process and the banner saying so
        take the accent, a paused list takes the red, and both are the ground
        lifted towards it rather than filled with it.""",
         [("followed_bg", following), ("followed_fg", state_fg),
          ("proc_follow_bg", following), ("proc_pause_bg", paused),
          ("proc_banner_bg", raised), ("proc_banner_fg", state_fg)]),

        ("""One line colour for all four boxes and for the ground behind every
        meter. Stock themes give each box its own hue; this shell draws one
        hairline and the boxes are chrome, so they are all drawn in it.""",
         [("cpu_box", line), ("mem_box", line), ("net_box", line),
          ("proc_box", line), ("div_line", line), ("meter_bg", line)]),

        ("""Temperature and load: filling is the reading getting worse.""",
         [(f"{name}_{stop}", value)
          for name in ("temp", "cpu")
          for stop, value in zip(("start", "mid", "end"), filling)]),

        ("""Memory. Used fills the way load does; free and available are the
        same three hues read backwards, because a full bar there is the
        machine being fine. Cached is neither, so it takes the blue and is
        ramped rather than graded.""",
         [(f"used_{stop}", value) for stop, value in zip(("start", "mid", "end"), filling)] +
         [(f"{name}_{stop}", value)
          for name in ("free", "available")
          for stop, value in zip(("start", "mid", "end"), emptying)] +
         [(f"cached_{stop}", value)
          for stop, value in zip(("start", "mid", "end"), ramp("blue"))]),

        ("""The two directions of the network, in the accent and the colour the
        palette keeps beside it — one hue at two weights, which is what the
        overview does with a workspace you are on and one you are going to.
        Nothing here is a warning: traffic is not good or bad.""",
         [(f"download_{stop}", value)
          for stop, value in zip(("start", "mid", "end"), ramp("accent"))] +
         [(f"upload_{stop}", value)
          for stop, value in zip(("start", "mid", "end"), ramp("accentHover"))]),

        ("""And the process list, which fades down the screen rather than
        colouring anything: the top of it is the text colour and the bottom is
        the inactive grey.""",
         [("process_start", text), ("process_mid", muted), ("process_end", inactive)]),
    ]

    lines = [
        "# GENERATED by scripts/theme_manager.py on every palette change.",
        "# Read by btop as `color_theme = \"impasto\"`; edits here are lost at the",
        "# next theme switch.",
        "#",
        "# btop wants forty-eight colours and a palette here carries thirteen.",
        "# What is missing is ramped or derived rather than invented, and every",
        "# colour that carries type is lifted to a minimum contrast against the",
        "# ground it lands on.",
    ]
    for note, entries in groups:
        lines.append("")
        lines += ["# " + row for row in textwrap.wrap(" ".join(note.split()), 72)]
        for key, value in entries:
            lines.append(f'theme[{key}]="{value}"')
    return "\n".join(lines) + "\n"


def write_program_theme(program, root, path, build, colors):
    """Write a generated theme into a program's config directory.

    Skips programs that are not installed, and refuses to write through a
    symlinked config directory (a leftover link into the repository, which
    `./setup sync` replaces with a real directory). Returns whether it wrote.
    """
    if not shutil.which(program):
        return False
    if os.path.islink(root):
        sys.stderr.write(f"{root} is a symlink, so {program}'s theme is "
                         f"not written: run `./setup sync`, which makes "
                         f"it a real directory\n")
        return False
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(build(colors))
    except OSError as error:
        sys.stderr.write(f"Cannot write {program}'s theme: {error}\n")
        return False
    return True


def write_btop_theme(colors):
    """Write btop's theme; it applies to the next btop started."""
    write_program_theme("btop", BTOP_DIR, BTOP_THEME_FILE, build_btop_theme, colors)


def build_cava_theme(colors):
    """cava's `[color]` section: a four-stop gradient in the accent's family.

    No background, so cava draws on the terminal's own translucent ground.
    `foreground`, used when the gradient is off, is the accent.
    """
    background = terminal_background(colors)
    lines = [
        "# GENERATED by scripts/theme_manager.py on every palette change.",
        "# Read by cava as `theme = 'impasto'`; edits here are lost at the next",
        "# theme switch, and a running cava is signalled to re-read it.",
        "#",
        "# Four stops in one family, bottom to top. The island draws the same",
        "# sound in `Theme.accent` flat, so a screen-tall one is that instrument",
        "# with more room rather than a different one — and nothing in it goes",
        "# red, because a loud passage is not a warning. No background line, so",
        "# the bars stand on the terminal's own ground.",
        "",
        "[color]",
        f"foreground = '{lift(colors['accent'], MIN_CONTRAST, background)}'",
        "",
        "gradient = 1",
    ]
    stops = [mix(colors["accent"], background, CAVA_GRADIENT_DIM),
             lift(colors["accent"], MIN_CONTRAST, background),
             lift(colors["accentHover"], MIN_CONTRAST, background),
             brighten(colors["accentHover"], background)]
    for index, stop in enumerate(stops, start=1):
        lines.append(f"gradient_color_{index} = '{stop}'")
    return "\n".join(lines) + "\n"


def write_cava_theme(colors):
    """Write cava's theme and signal running instances to reload it.

    SIGUSR2 is cava's "reload colors only"; it does not interrupt the shell's
    own raw-output cava.
    """
    if not write_program_theme("cava", CAVA_DIR, CAVA_THEME_FILE,
                               build_cava_theme, colors):
        return
    if shutil.which("pkill"):
        # Exit status 1 just means no cava was running.
        subprocess.run(["pkill", "-USR2", "-x", "cava"], capture_output=True)


def build_yazi_flavor(colors):
    """yazi's flavour, covering every section of its interface.

    Keys follow the defaults compiled into current yazi, which ignores unknown
    keys silently (the cursor row is `[indicator]`, not `[mgr] hovered`).
    Backgrounds are set only where needed, so the terminal ground shows
    through. The cursor row is a tinted fill rather than yazi's default
    `reversed`.
    """
    background = terminal_background(colors)

    def style(**parts):
        written = [f'{key} = "{parts[key]}"' for key in ("fg", "bg") if parts.get(key)]
        written += [f"{key} = true" for key in
                    ("bold", "italic", "underline", "reversed", "crossed") if parts.get(key)]
        return "{ " + ", ".join(written) + " }" if written else "{ }"

    def on(key):
        return lift(colors[key], MIN_CONTRAST, background)

    ground = on("text")
    row = mix(background, ground, YAZI_ROW_RAISE)
    chip = mix(background, ground, TERMINAL_RAISE)
    cursor = mix(background, colors["accent"], TERMINAL_STATE_FILL)
    select_fill = cursor
    unset_fill = mix(background, colors["yellow"], TERMINAL_STATE_FILL)

    # File names appear on three grounds (terminal, parent row, cursor), so
    # their colours are lifted against all three in turn.
    def listed(key):
        value = colors[key]
        for under in (background, row, cursor):
            value = lift(value, MIN_CONTRAST, under)
        return value

    def on_chip(key):
        return lift(colors[key], MIN_CONTRAST, chip)

    def on_row(key):
        return lift(colors[key], MIN_CONTRAST, row)

    text, muted, accent = on("text"), on("textMuted"), on("accent")
    beside, blue = on("accentHover"), on("blue")
    red, green, yellow = on("red"), on("green"), on("yellow")
    # Orphaned and absent files are deliberately left below the contrast floor.
    dim = mix(muted, background, TERMINAL_DIM)
    line = mix(colors["border"], background, TERMINAL_LINE)
    marked = mix(colors["accent"], background, YAZI_MARKED_DIM)

    # Text on a coloured fill: the terminal ground if it contrasts enough,
    # then black, then lifted text.
    def over(fill):
        for candidate in (background, "#000000",
                          lift(colors["text"], MIN_CONTRAST, fill)):
            if contrast_on_terminal(candidate, fill) >= MIN_CONTRAST:
                return candidate
        return lift(colors["text"], MIN_CONTRAST, fill)

    caps = f'{{ open = "{YAZI_CAP_OPEN}", close = "{YAZI_CAP_CLOSE}" }}'
    return "\n".join([
        "# GENERATED by scripts/theme_manager.py on every palette change.",
        "# Read by yazi as `[flavor] dark = \"impasto\"`; edits here are lost at",
        "# the next theme switch, and yazi has to be reopened to see it.",
        "#",
        "# Backgrounds are set only where something has to sit on one, so the",
        "# blurred desktop under the terminal comes through everywhere else.",
        "",
        "[mgr]",
        f"cwd = {style(fg=accent, bold=True)}",
        "",
        f"find_keyword = {style(fg=yellow, bold=True, underline=True)}",
        f"find_position = {style(fg=dim, bold=True, italic=True)}",
        f"symlink_target = {style(fg=listed('textMuted'), italic=True)}",
        "",
        f"marker_copied = {style(fg=green, bg=green)}",
        f"marker_cut = {style(fg=red, bg=red)}",
        f"marker_marked = {style(fg=marked, bg=marked)}",
        f"marker_selected = {style(fg=accent, bg=accent)}",
        "",
        f"count_copied = {style(fg=over(green), bg=green)}",
        f"count_cut = {style(fg=over(red), bg=red)}",
        f"count_selected = {style(fg=colors['accentText'], bg=colors['accent'])}",
        "",
        'border_symbol = "│"',
        f"border_style = {style(fg=line)}",
        "",
        "# The cursor, in both panes: the ground lifted, and towards the accent",
        "# where the cursor actually is.",
        "[indicator]",
        f"current = {style(bg=cursor)}",
        f"parent = {style(bg=row)}",
        f"preview = {style(underline=True)}",
        "",
        "[tabs]",
        f"active = {style(fg=on_chip('text'), bg=chip, bold=True)}",
        f"inactive = {style(fg=on_row('textMuted'), bg=row)}",
        f"sep_inner = {caps}",
        f"sep_outer = {caps}",
        "",
        "[mode]",
        f"normal_main = {style(fg=on_chip('text'), bg=chip, bold=True)}",
        f"normal_alt = {style(fg=on_row('textMuted'), bg=row)}",
        "",
        f"select_main = {style(fg=colors['accentText'], bg=colors['accent'], bold=True)}",
        f"select_alt = {style(fg=accent, bg=select_fill)}",
        "",
        f"unset_main = {style(fg=over(colors['yellow']), bg=colors['yellow'], bold=True)}",
        f"unset_alt = {style(fg=yellow, bg=unset_fill)}",
        "",
        "[status]",
        f"overall = {style(fg=text)}",
        f"sep_left = {caps}",
        f"sep_right = {caps}",
        "",
        f"perm_sep = {style(fg=dim)}",
        f"perm_type = {style(fg=blue)}",
        f"perm_read = {style(fg=yellow)}",
        f"perm_write = {style(fg=red)}",
        f"perm_exec = {style(fg=green)}",
        "",
        f"progress_label = {style(fg=lift(colors['text'], MIN_CONTRAST, select_fill), bold=True)}",
        f"progress_normal = {style(fg=accent, bg=select_fill)}",
        f"progress_error = {style(fg=over(red), bg=red)}",
        "",
        "[which]",
        f"border = {style(fg=line)}",
        "cols = 3",
        f"mask = {style(bg=row)}",
        f"cand = {style(fg=accent, bold=True)}",
        f"rest = {style(fg=muted)}",
        f"desc = {style(fg=dim, italic=True)}",
        f"separator_style = {style(fg=line)}",
        "",
        "[confirm]",
        f"border = {style(fg=line)}",
        f"title = {style(fg=accent, bold=True)}",
        f"body = {style(fg=text)}",
        f"list = {style(fg=muted)}",
        f"btn_yes = {style(fg=colors['accentText'], bg=colors['accent'], bold=True)}",
        f"btn_no = {style(fg=on_row('textMuted'), bg=row)}",
        "",
        "[spot]",
        f"border = {style(fg=line)}",
        f"title = {style(fg=accent, bold=True)}",
        f"tbl_col = {style(fg=muted)}",
        f"tbl_cell = {style(bg=row)}",
        "",
        "[notify]",
        f"title_info = {style(fg=blue)}",
        f"title_warn = {style(fg=yellow)}",
        f"title_error = {style(fg=red)}",
        "",
        "[pick]",
        f"border = {style(fg=line)}",
        f"active = {style(fg=accent, bold=True)}",
        f"inactive = {style(fg=muted)}",
        "",
        "[input]",
        f"border = {style(fg=line)}",
        f"title = {style(fg=accent, bold=True)}",
        f"value = {style(fg=text)}",
        f"selected = {style(bg=row)}",
        "",
        "[cmp]",
        f"border = {style(fg=line)}",
        f"active = {style(fg=on_row('text'), bg=row)}",
        f"inactive = {style(fg=muted)}",
        "",
        "[tasks]",
        f"border = {style(fg=line)}",
        f"title = {style(fg=accent, bold=True)}",
        f"hovered = {style(fg=accent, bold=True)}",
        "",
        "[help]",
        f"border = {style(fg=line)}",
        f"chord = {style(fg=accent)}",
        f"action = {style(fg=text)}",
        f"hovered = {style(bg=row, bold=True)}",
        "",
        "# The mime patterns are yazi's own shape — `**/` and a brace list — and",
        "# not the bare `image/*` an older flavour would use, which matches",
        "# nothing here and says nothing about it.",
        "[filetype]",
        "rules = [",
        f'  {{ mime = "**/image/*", fg = "{listed("accentHover")}" }},',
        f'  {{ mime = "**/{{audio,video}}/*", fg = "{listed("yellow")}" }},',
        f'  {{ mime = "**/application/{{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,'
        f'compress,archive,cpio,arj,xar,ms-cab*}}", fg = "{listed("red")}" }},',
        f'  {{ mime = "**/application/{{pdf,doc,rtf}}", fg = "{listed("blue")}" }},',
        "",
        f'  {{ mime = "vfs/{{absent,stale}}", fg = "{dim}", crossed = true }},',
        f'  {{ url = "*", is = "orphan", fg = "{dim}", crossed = true }},',
        f'  {{ url = "*", is = "dummy", fg = "{dim}", crossed = true }},',
        f'  {{ url = "*/", is = "dummy", fg = "{dim}", crossed = true }},',
        f'  {{ url = "*", is = "exec", fg = "{listed("green")}" }},',
        "",
        f'  {{ url = "*", fg = "{listed("textMuted")}" }},',
        f'  {{ url = "*/", fg = "{listed("text")}" }}',
        "]",
    ]) + "\n"


def build_yazi_tmtheme(colors):
    """The preview pane's syntax colours, as a tmTheme.

    yazi highlights previews only with the active flavour's tmTheme.
    """
    background = terminal_background(colors)

    def on(key):
        return lift(colors[key], MIN_CONTRAST, background)

    text, muted, accent = on("text"), on("textMuted"), on("accent")

    # Comments are dimmed more in a preview than in an editor.
    dim = mix(muted, background, TERMINAL_DIM)
    scopes = [(name, scope, dim if key == "comment" else on(key), style)
              for name, scope, key, style in SYNTAX_SCOPES]

    def setting(key, value):
        return f"      <key>{key}</key><string>{value}</string>"

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
        "<!-- GENERATED by scripts/theme_manager.py on every palette change. -->",
        "<!-- Read by yazi as the active flavour's tmTheme; edits here are lost. -->",
        '<plist version="1.0">',
        "<dict>",
        "  <key>name</key><string>impasto</string>",
        "  <key>settings</key>",
        "  <array>",
        "    <dict>",
        "      <key>settings</key>",
        "      <dict>",
        setting("background", background),
        setting("foreground", text),
        setting("caret", accent),
        setting("selection", mix(background, colors["accent"], TERMINAL_STATE_FILL)),
        setting("lineHighlight", mix(background, text, TERMINAL_RAISE)),
        setting("invisibles", dim),
        "      </dict>",
        "    </dict>",
    ]
    for name, scope, colour, font_style in scopes:
        lines += [
            "    <dict>",
            f"      <key>name</key><string>{name}</string>",
            f"      <key>scope</key><string>{scope}</string>",
            "      <key>settings</key>",
            "      <dict>",
            setting("foreground", colour),
        ]
        if font_style:
            lines.append(setting("fontStyle", font_style))
        lines += ["      </dict>", "    </dict>"]
    lines += ["  </array>", "</dict>", "</plist>"]
    return "\n".join(lines) + "\n"


def write_yazi_flavor(colors):
    """Write yazi's flavour directory: flavor.toml and tmtheme.xml."""
    write_program_theme("yazi", YAZI_DIR, YAZI_FLAVOR_FILE, build_yazi_flavor, colors)
    write_program_theme("yazi", YAZI_DIR, YAZI_TMTHEME_FILE, build_yazi_tmtheme, colors)


def build_gtk4_css(colors):
    """libadwaita's named colours.

    GTK4 applications look up `window_bg_color`, `accent_bg_color` and so on,
    and a user gtk.css can redefine all of them, so no theme is needed. The
    names are written out explicitly: unknown names are ignored silently.
    """
    accent = colors.get("accent", "#0a84ff")
    ground = gtk_ground(colors.get("background", "#1e1e1e"), accent)
    raised = gtk_ground(colors.get("surface", colors.get("background", "#1e1e1e")),
                        accent)
    text = colors.get("text", "#ffffff")
    muted = colors.get("textMuted", text)
    on_accent = colors.get("accentText", "#ffffff")
    border = gtk_ground(colors.get("border", raised), accent)

    # `accent_color` is the accent used as text, so it is lifted against the
    # ground; `accent_bg_color` is a fill and stays as-is, paired with
    # `accent_fg_color`.
    accent_text = lift(accent, GTK_MIN_CONTRAST, ground)

    pairs = [
        ("window_bg_color", ground), ("window_fg_color", text),
        ("view_bg_color", ground), ("view_fg_color", text),
        ("headerbar_bg_color", raised), ("headerbar_fg_color", text),
        ("headerbar_border_color", border),
        ("headerbar_backdrop_color", ground),
        ("headerbar_shade_color", border),
        ("popover_bg_color", raised), ("popover_fg_color", text),
        ("card_bg_color", raised), ("card_fg_color", text),
        ("dialog_bg_color", raised), ("dialog_fg_color", text),
        ("sidebar_bg_color", raised), ("sidebar_fg_color", text),
        ("sidebar_border_color", border), ("sidebar_backdrop_color", ground),
        ("secondary_sidebar_bg_color", raised),
        ("secondary_sidebar_fg_color", text),
        ("accent_color", accent_text), ("accent_bg_color", accent),
        ("accent_fg_color", on_accent),
        ("destructive_color", lift(colors.get("red", "#ff453a"),
                                   GTK_MIN_CONTRAST, ground)),
        ("destructive_bg_color", colors.get("red", "#ff453a")),
        ("destructive_fg_color", on_accent),
        ("success_color", lift(colors.get("green", "#32d74b"),
                               GTK_MIN_CONTRAST, ground)),
        ("success_bg_color", colors.get("green", "#32d74b")),
        ("success_fg_color", on_accent),
        ("warning_color", lift(colors.get("yellow", "#ffd60a"),
                               GTK_MIN_CONTRAST, ground)),
        ("warning_bg_color", colors.get("yellow", "#ffd60a")),
        ("warning_fg_color", on_accent),
        ("error_color", lift(colors.get("red", "#ff453a"),
                             GTK_MIN_CONTRAST, ground)),
        ("error_bg_color", colors.get("red", "#ff453a")),
        ("error_fg_color", on_accent),
        ("borders", border),
    ]

    lines = ["/* Written by theme_manager.py on every palette push. */",
             "/* Anything put here by hand is lost on the next one. */", ""]
    lines += [f"@define-color {name} {value};" for name, value in pairs]
    lines.append("")
    # A muted foreground, which libadwaita derives rather than names.
    lines.append(f"@define-color window_fg_color_muted {muted};")
    lines.append("")
    return "\n".join(lines)


def build_gtk3_css(colors):
    """The palette for GTK3: named colours plus a small set of rules.

    The `@define-color theme_*` names still reach applications that ask for
    them, but Adwaita compiles its own colours in and does not read them
    back. Plain rules in the user sheet, loaded at
    GTK_STYLE_PROVIDER_PRIORITY_USER, do override it. The rules only set
    surfaces (ground, raised bars, views, side panes) and the accent; widget
    shapes stay Adwaita's.
    """
    accent = colors.get("accent", "#0a84ff")
    ground = gtk_ground(colors.get("background", "#1e1e1e"), accent)
    raised = gtk_ground(colors.get("surface", colors.get("background", "#1e1e1e")),
                        accent)
    hover = gtk_ground(colors.get("surfaceHover", colors.get("surface", "#1e1e1e")),
                       accent)
    border = gtk_ground(colors.get("border", raised), accent)
    text = colors.get("text", "#ffffff")
    muted = colors.get("textMuted", text)
    on_accent = colors.get("accentText", "#ffffff")

    # The accent as text, lifted against the ground as in GTK4.
    accent_text = lift(accent, GTK_MIN_CONTRAST, ground)

    # Thunar's inactive split pane (see GTK_DIM).
    dim = mix(ground, raised, GTK_DIM)

    pairs = [
        ("theme_bg_color", ground), ("theme_fg_color", text),
        ("theme_base_color", ground), ("theme_text_color", text),
        ("theme_selected_bg_color", accent),
        ("theme_selected_fg_color", on_accent),
        ("insensitive_bg_color", ground), ("insensitive_fg_color", muted),
        ("insensitive_base_color", ground),
        ("theme_unfocused_bg_color", dim),
        ("theme_unfocused_fg_color", muted),
        ("theme_unfocused_base_color", dim),
        ("theme_unfocused_text_color", text),
        ("theme_unfocused_selected_bg_color", accent),
        ("theme_unfocused_selected_fg_color", on_accent),
        ("borders", border),
        ("unfocused_borders", border),
        ("warning_color", lift(colors.get("yellow", "#ffd60a"),
                               GTK_MIN_CONTRAST, ground)),
        ("error_color", lift(colors.get("red", "#ff453a"),
                             GTK_MIN_CONTRAST, ground)),
        ("success_color", lift(colors.get("green", "#32d74b"),
                               GTK_MIN_CONTRAST, ground)),
    ]

    lines = ["/* Written by theme_manager.py on every palette push. */",
             "/* Anything put here by hand is lost on the next one. */", ""]
    lines += [f"@define-color {name} {value};" for name, value in pairs]
    lines.append("")
    lines.append(f"""
/* ── THE GROUND ──────────────────────────────────────────────────────── */

window, dialog, messagedialog, assistant, .background {{
  background-color: @theme_bg_color;
  color: @theme_fg_color;
}}


/* ── WHAT IS RAISED OFF IT ───────────────────────────────────────────── */

headerbar, .titlebar, menubar, toolbar, .toolbar, .primary-toolbar,
searchbar, actionbar, infobar, statusbar, notebook > header,
popover, popover.background, menu, .menu, .context-menu,
tooltip, tooltip.background {{
  background-color: {raised};
  background-image: none;
  color: @theme_fg_color;
  border-color: @borders;
}}


/* ── THE VIEWS ───────────────────────────────────────────────────────── */

.view, iconview, treeview.view, textview text, list, flowbox,
.standard-view, .preview-pane {{
  background-color: @theme_base_color;
  color: @theme_text_color;
}}


/* ── AND THE SIDE PANE, WHICH IS A VIEW THAT IS RAISED ───────────────── */
/* · after the views on purpose: a side pane holds one, and the later rule */
/*   of equal weight is the one that wins */

.sidebar, placessidebar, .shortcuts-pane, .tree-pane,
.sidebar .view, .sidebar list, placessidebar list, placessidebar .view,
.shortcuts-pane .view, .tree-pane .view {{
  background-color: {raised};
  color: @theme_fg_color;
}}

.sidebar, .shortcuts-pane, .tree-pane {{
  border-right: 1px solid @borders;
}}


/* ── THE ACCENT, WHICH IS WHAT CARRIES MEANING ───────────────────────── */

*:selected, *:selected:focus, .view:selected, treeview.view:selected,
iconview:selected, list row:selected, menuitem:hover, selection {{
  background-color: @theme_selected_bg_color;
  color: @theme_selected_fg_color;
}}

check:checked, radio:checked, switch:checked {{
  background-color: @theme_selected_bg_color;
  background-image: none;
  border-color: @theme_selected_bg_color;
  color: @theme_selected_fg_color;
}}

progressbar progress, levelbar block.filled, scale highlight, scale fill {{
  background-color: @theme_selected_bg_color;
}}

link, *:link {{ color: {accent_text}; }}


/* ── FIELDS AND BUTTONS ──────────────────────────────────────────────── */

entry, spinbutton, entry.search {{
  background-color: @theme_base_color;
  background-image: none;
  color: @theme_text_color;
  border-color: @borders;
}}

entry:focus {{ border-color: @theme_selected_bg_color; }}

button, combobox button {{
  background-color: {hover};
  background-image: none;
  color: @theme_fg_color;
  border-color: @borders;
  text-shadow: none;
}}

button:hover {{ background-color: {raised}; }}
button:disabled {{ color: @insensitive_fg_color; }}

button:checked, button:active {{
  background-color: @theme_selected_bg_color;
  color: @theme_selected_fg_color;
}}

/* · flat buttons get an explicit foreground as well as a background, or
     symbolic icons on toolbars (satty's, for one) render invisible */
button.flat, button.titlebutton, toolbar button, headerbar button,
.toolbar button, .path-bar-button, .location-button, statusbar button {{
  background-color: transparent;
  background-image: none;
  border-color: transparent;
  color: @theme_fg_color;
}}

toolbar button:hover, headerbar button:hover, .toolbar button:hover,
.path-bar-button:hover, .location-button:hover,
.path-bar-button:checked, .location-button:checked {{
  background-color: {hover};
  color: @theme_fg_color;
}}


/* ── SEPARATORS AND SCROLLBARS ───────────────────────────────────────── */

separator, paned > separator {{ background-color: @borders; }}

scrollbar {{ background-color: transparent; border-color: transparent; }}
scrollbar slider {{ background-color: @insensitive_fg_color; }}
scrollbar slider:hover {{ background-color: @theme_fg_color; }}

statusbar {{ border-top: 1px solid @borders; }}

/* ── THUNAR ──────────────────────────────────────────────────────────── */
/* · Thunar's location bar is not a GtkToolbar and has no class to style, so
     the view and the side pane draw the dividing line under it instead */
.standard-view, .shortcuts-pane, .tree-pane {{
  border-top: 1px solid @borders;
}}

/* · this one Thunar paints itself, from a named colour, so all it needs is
     for the name to mean something */
.split-view-inactive-pane .view {{ background-color: {dim}; }}
""")
    lines.append("")
    return "\n".join(lines)


def write_gtk_theme(colors):
    """Write both sheets into the GTK config directories.

    Not guarded on a binary (there is no `gtk` command); the symlink check
    still applies. GTK reads gtk.css once, so only newly started applications
    pick it up.
    """
    for root, path, build in ((GTK4_DIR, GTK4_CSS_FILE, build_gtk4_css),
                              (GTK3_DIR, GTK3_CSS_FILE, build_gtk3_css)):
        if os.path.islink(root):
            sys.stderr.write(f"{root} is a symlink, so GTK's colours are "
                             f"not written: run `./setup sync`, which "
                             f"makes it a real directory\n")
            continue
        try:
            os.makedirs(root, exist_ok=True)
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(build(colors))
        except OSError as error:
            sys.stderr.write(f"Cannot write {path}: {error}\n")


def icon_source_root():
    """The Papirus-Dark directory, searched in XDG data order, or None."""
    for base in (XDG_DATA_HOME, "/usr/local/share", "/usr/share"):
        root = os.path.join(base, "icons", ICON_SOURCE_THEME)
        if os.path.isdir(os.path.join(root, ICON_SWATCH_SIZE, "places")):
            return root
    return None


def folder_swatches(root):
    """Map each Papirus folder colour name to its fill colour.

    Both the names (see ICON_COLOUR_PROOF) and the colours (the SVG's `fill:`)
    are read from the installed theme, so added or redrawn colours are picked
    up.
    """
    places = os.path.join(root, ICON_SWATCH_SIZE, "places")
    try:
        names = os.listdir(places)
    except OSError as error:
        sys.stderr.write(f"Cannot read {places}: {error}\n")
        return {}

    swatches = {}
    for name in names:
        found = re.fullmatch(r"folder-([a-z0-9]+)\.svg", name)
        if not found:
            continue
        colour = found.group(1)
        if not all(os.path.exists(os.path.join(places, f"folder-{colour}-{proof}.svg"))
                   for proof in ICON_COLOUR_PROOF):
            continue
        try:
            with open(os.path.join(places, name), encoding="utf-8") as handle:
                fill = ICON_SWATCH_PATTERN.search(handle.read())
        except OSError:
            continue
        if fill:
            swatches[colour] = fill.group(1).lower()
    return swatches


def nearest_swatch(accent, swatches):
    """The Papirus folder colour closest to the accent.

    Compared in HSV with hue weighted most (ICON_HUE_WEIGHT); saturation and
    value break ties, e.g. blue against nordic. Grey accents only match grey
    swatches, and the other way round.
    """
    if not swatches:
        return None

    hue, sat, val = colorsys.rgb_to_hsv(*(c / 255 for c in hex_to_rgb(accent)))
    grey = sat < ICON_GREY_BELOW

    def distance(value):
        other_hue, other_sat, other_val = colorsys.rgb_to_hsv(
            *(c / 255 for c in hex_to_rgb(value)))
        other_grey = other_sat < ICON_GREY_BELOW
        if grey != other_grey:
            away = ICON_HUE_WEIGHT
        elif grey:
            away = 0.0
        else:
            turn = abs(hue - other_hue)
            turn = min(turn, 1.0 - turn) * 2.0
            away = ICON_HUE_WEIGHT * turn * turn
        return away + (sat - other_sat) ** 2 + (val - other_val) ** 2

    # Sorted first, so ties break by name rather than by directory order.
    return min(sorted(swatches), key=lambda name: distance(swatches[name]))


def icon_reference_colour(places):
    """The colour Papirus's uncoloured names point at (blue, so far)."""
    target = os.path.realpath(os.path.join(places, ICON_REFERENCE_NAME))
    found = ICON_ALIAS_PATTERN.match(os.path.basename(target))
    return found.group(2) if found else None


def icon_directory_size(name):
    """`48x48` and `48x48@2x` in the two numbers an index.theme wants."""
    found = re.fullmatch(r"(\d+)x\1(?:@(\d+)x)?", name)
    if not found:
        return None
    return int(found.group(1)), int(found.group(2) or 1)


def build_icon_index(plain, scaled):
    """The index.theme.

    Declares only the directories written into; everything else is inherited.
    """
    lines = ["# Written by theme_manager.py on every palette push.",
             "# Anything put here by hand is lost on the next one.",
             "",
             "[Icon Theme]",
             f"Name={ICON_THEME_NAME}",
             "Comment=Papirus, with the folders in the wallpaper's colour",
             f"Inherits={','.join(ICON_INHERITS)}",
             "Example=folder",
             "",
             "Directories=" + ",".join(name for name, _, _ in plain)]
    if scaled:
        lines.append("ScaledDirectories=" + ",".join(name for name, _, _ in scaled))
    lines.append("")

    for name, size, scale in plain + scaled:
        lines += [f"[{name}]", "Context=Places", f"Size={size}"]
        if scale > 1:
            lines.append(f"Scale={scale}")
        lines += ["Type=Fixed", ""]
    return "\n".join(lines)


def write_icon_theme(colors):
    """Write the folder-colour icon theme. Returns False if it cannot.

    Symlinks every name Papirus aliases into its default colour, not just the
    files that look like folders (user-desktop and folder-publicshare are
    aliases too). The theme is built in a sibling directory and swapped in, so
    an application starting mid-build never sees it half written. Skipped when
    the accent maps to the same swatch as last time. GTK reads icon themes
    once, so only newly started applications pick it up.
    """
    root = icon_source_root()
    if root is None:
        return False

    swatches = folder_swatches(root)
    colour = nearest_swatch(colors.get("accent", "#0a84ff"), swatches)
    if colour is None:
        return False

    if os.path.islink(ICON_THEME_DIR):
        sys.stderr.write(f"{ICON_THEME_DIR} is a symlink, so the folder "
                         f"colour is not written\n")
        return False

    stamp = f"{colour} {swatches[colour]} {root}\n"
    try:
        with open(ICON_STAMP_FILE, encoding="utf-8") as handle:
            if handle.read() == stamp:
                return True
    except OSError:
        pass

    plain, scaled, links = [], [], []
    for entry in sorted(os.listdir(root)):
        measured = icon_directory_size(entry)
        if measured is None:
            continue
        places = os.path.join(root, entry, "places")
        if not os.path.isdir(places):
            continue
        reference = icon_reference_colour(places)
        if reference is None:
            continue

        drawings = []
        for name in sorted(os.listdir(places)):
            # A name that already specifies a colour keeps it.
            said = ICON_ALIAS_PATTERN.match(name)
            if said and said.group(2) in swatches:
                continue
            # Follow the whole symlink chain; some names take two hops.
            source = os.path.realpath(os.path.join(places, name))
            if os.path.dirname(source) != os.path.realpath(places):
                continue
            lands = ICON_ALIAS_PATTERN.match(os.path.basename(source))
            if not lands or lands.group(2) != reference:
                continue
            family, _, rest = lands.groups()
            # Link to the name inside the inherited theme, unresolved:
            # resolving would point half the links into Papirus/, since
            # Papirus-Dark shares drawings with it. os.path.exists still
            # follows the chain, so dangling aliases are skipped.
            wanted = os.path.join(places, f"{family}-{colour}{rest or ''}.svg")
            if not os.path.exists(wanted):
                continue
            drawings.append((name, wanted))

        if not drawings:
            continue

        size, scale = measured
        (scaled if scale > 1 else plain).append((f"{entry}/places", size, scale))
        for name, wanted in drawings:
            links.append((os.path.join(entry, "places", name), wanted))

    if not links:
        return False

    building = ICON_THEME_DIR + ".building"
    try:
        if os.path.isdir(building):
            shutil.rmtree(building)
        for target, source in links:
            path = os.path.join(building, target)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            os.symlink(source, path)
        with open(os.path.join(building, os.path.basename(ICON_INDEX_FILE)),
                  "w", encoding="utf-8") as handle:
            handle.write(build_icon_index(plain, scaled))
        with open(os.path.join(building, os.path.basename(ICON_STAMP_FILE)),
                  "w", encoding="utf-8") as handle:
            handle.write(stamp)

        # Only replace a directory carrying our stamp; anything else is
        # someone else's theme.
        if os.path.isdir(ICON_THEME_DIR):
            if not os.path.exists(ICON_STAMP_FILE):
                shutil.rmtree(building)
                sys.stderr.write(f"{ICON_THEME_DIR} was not written by this "
                                 f"script, so the folder colour is not "
                                 f"changed\n")
                return False
            shutil.rmtree(ICON_THEME_DIR)
        os.replace(building, ICON_THEME_DIR)
    except OSError as error:
        sys.stderr.write(f"Cannot write the icon theme: {error}\n")
        return False
    return True


def build_qt_colors(colors):
    """A QPalette in qt6ct's format: three colour groups of 22 roles.

    Uses the same grounds as GTK (gtk_ground), so Qt and GTK windows match,
    plus Fusion's bevel shades and a disabled group.
    """
    accent = colors.get("accent", "#0a84ff")
    ground = gtk_ground(colors.get("background", "#1e1e1e"), accent)
    raised = gtk_ground(colors.get("surface", colors.get("background", "#1e1e1e")),
                        accent)
    text = colors.get("text", "#ffffff")
    muted = colors.get("textMuted", text)
    on_accent = colors.get("accentText", "#ffffff")

    active = {
        # · ground and raised surfaces
        "Window": ground, "WindowText": text,
        "Base": ground, "Text": text,
        "AlternateBase": raised,
        "Button": raised, "ButtonText": text,
        "ToolTipBase": raised, "ToolTipText": text,
        "PlaceholderText": muted,
        # BrightText is text on filled controls: the palette's accentText.
        "BrightText": on_accent,

        # · bevel
        "Light": mix(raised, "#ffffff", QT_BEVEL_LIGHT),
        "Midlight": mix(raised, "#ffffff", QT_BEVEL_MIDLIGHT),
        "Mid": mix(raised, "#000000", QT_BEVEL_MID),
        "Dark": mix(raised, "#000000", QT_BEVEL_DARK),
        "Shadow": mix(raised, "#000000", QT_BEVEL_SHADOW),

        # The accent as a fill, paired with accentText.
        "Highlight": accent, "HighlightedText": on_accent, "Accent": accent,
        # The accent as text, lifted to the contrast floor. Visited links use
        # accentHover rather than a purple the palette does not have.
        "Link": lift(accent, GTK_MIN_CONTRAST, ground),
        "LinkVisited": lift(colors.get("accentHover", accent),
                            GTK_MIN_CONTRAST, ground),

        # Unused by styles; present because the list is positional.
        "NoRole": ground,
    }

    # Qt repaints a whole unfocused window from the inactive group, so it is
    # the same as active; otherwise every label would grey out on focus loss.
    inactive = dict(active)

    faded = mix(text, ground, QT_DISABLED)
    disabled = dict(active)
    disabled.update({
        "WindowText": faded, "Text": faded, "ButtonText": faded,
        "BrightText": faded, "HighlightedText": faded,
        "PlaceholderText": mix(muted, ground, QT_DISABLED),
        "Highlight": mix(accent, ground, QT_DISABLED),
    })

    def group(mapping):
        # #AARRGGBB, the form qt6ct's own schemes use.
        return ", ".join("#ff" + mapping[role].lstrip("#") for role in QT_ROLES)

    return "\n".join([
        "# GENERATED by scripts/theme_manager.py on every palette change.",
        "# Edits here are lost at the next switch.",
        "",
        "[ColorScheme]",
        f"active_colors={group(active)}",
        f"disabled_colors={group(disabled)}",
        f"inactive_colors={group(inactive)}",
    ]) + "\n"


def build_qt6ct_config():
    """qt6ct's settings: style, icon theme and colour scheme path.

    No [Fonts] section: qt6ct stores fonts as serialized QVariants, and a font
    set here would apply to Quickshell as well.
    """
    return "\n".join([
        "# GENERATED by scripts/theme_manager.py on every palette change.",
        "# qt6ct's own window writes this file as well; what it saves there is",
        "# lost at the next switch.",
        "",
        "[Appearance]",
        f"style={QT6CT_STYLE}",
        f"icon_theme={QT6CT_ICONS}",
        "custom_palette=true",
        f"color_scheme_path={QT6CT_COLORS_FILE}",
        "# Qt's own file dialog rather than the GTK one: a themed dialog on a",
        "# themed window, instead of the one window in the room that is not.",
        "standard_dialogs=default",
    ]) + "\n"


def build_kde_colors(colors):
    """KColorScheme colour sets for kdeglobals.

    Same grounds as GTK and Qt. Each set's text colours are lifted against
    that set's own background. Returned as sections because kdeglobals is
    merged, not overwritten.
    """
    accent = colors.get("accent", "#0a84ff")
    ground = gtk_ground(colors.get("background", "#1e1e1e"), accent)
    raised = gtk_ground(colors.get("surface", colors.get("background", "#1e1e1e")),
                        accent)
    text = colors.get("text", "#ffffff")
    muted = colors.get("textMuted", text)
    on_accent = colors.get("accentText", "#ffffff")
    hover = colors.get("accentHover", accent)
    red = colors.get("red", "#ff453a")
    yellow = colors.get("yellow", "#ffd60a")
    green = colors.get("green", "#32d74b")

    def rgb(value):
        # KDE only reads decimal `r,g,b`; `#rrggbb` is silently ignored.
        return ",".join(str(channel) for channel in hex_to_rgb(value))

    def surface(background):
        """One colour set, with text lifted against `background`."""
        def on(value):
            return rgb(lift(value, GTK_MIN_CONTRAST, background))

        link = on(accent)
        return [
            ("BackgroundNormal", rgb(background)),
            # alternating rows use the other ground
            ("BackgroundAlternate", rgb(raised if background == ground else ground)),
            ("ForegroundNormal", rgb(text)),
            ("ForegroundInactive", rgb(muted)),
            ("ForegroundActive", link), ("ForegroundLink", link),
            ("ForegroundVisited", on(hover)),
            ("ForegroundNegative", on(red)), ("ForegroundNeutral", on(yellow)),
            ("ForegroundPositive", on(green)),
            # Focus and hover are decoration, not text: the unlifted accent.
            ("DecorationFocus", rgb(accent)),
            ("DecorationHover", rgb(hover)),
        ]

    sections = [("General", [("ColorScheme", KDE_SCHEME_NAME),
                             ("AccentColor", rgb(accent))])]
    sections += [("Colors:" + name, surface(ground)) for name in KDE_GROUND_SETS]
    sections += [("Colors:" + name, surface(raised)) for name in KDE_RAISED_SETS]

    # The selection's background is the accent: text uses accentText, and the
    # status colours are lifted against the accent.
    sections.append(("Colors:Selection", [
        ("BackgroundNormal", rgb(accent)),
        ("BackgroundAlternate", rgb(hover)),
        ("ForegroundNormal", rgb(on_accent)),
        ("ForegroundInactive", rgb(mix(on_accent, accent, KDE_SELECTION_QUIET))),
        ("ForegroundActive", rgb(on_accent)),
        ("ForegroundLink", rgb(on_accent)),
        ("ForegroundVisited", rgb(on_accent)),
        ("ForegroundNegative", rgb(lift(red, GTK_MIN_CONTRAST, accent))),
        ("ForegroundNeutral", rgb(lift(yellow, GTK_MIN_CONTRAST, accent))),
        ("ForegroundPositive", rgb(lift(green, GTK_MIN_CONTRAST, accent))),
        ("DecorationFocus", rgb(on_accent)),
        ("DecorationHover", rgb(on_accent)),
    ]))
    return sections


def write_kde_colors(colors):
    """Merge the colour sets into kdeglobals, keeping every other key.

    Comments in the file are lost in the merge. Parsed with RawConfigParser:
    keys are case sensitive, `%` is literal and duplicate sections are
    tolerated. A file that cannot be parsed is left untouched. Skipped without
    kreadconfig6 (kconfig), since nothing would read the file.
    """
    if not shutil.which("kreadconfig6"):
        return

    parser = configparser.RawConfigParser(strict=False)
    parser.optionxform = str
    if os.path.exists(KDEGLOBALS_FILE):
        try:
            parser.read(KDEGLOBALS_FILE, encoding="utf-8")
        except (OSError, UnicodeDecodeError, configparser.Error) as error:
            sys.stderr.write(f"Cannot read kdeglobals, so it is left alone: "
                             f"{error}\n")
            return

    for section, entries in build_kde_colors(colors):
        if not parser.has_section(section):
            parser.add_section(section)
        for key, value in entries:
            parser.set(section, key, value)

    # Written to a temporary file and renamed, so it is never left truncated.
    temporary = KDEGLOBALS_FILE + ".impasto"
    try:
        with open(temporary, "w", encoding="utf-8") as handle:
            parser.write(handle, space_around_delimiters=False)
        os.replace(temporary, KDEGLOBALS_FILE)
    except OSError as error:
        sys.stderr.write(f"Cannot write kdeglobals: {error}\n")


def write_qt6ct_theme(colors):
    """Write qt6ct's colour scheme and config.

    Only newly started Qt applications pick up the change: qt6ct's directory
    watcher does not repaint windows that are already open. Skipped when qt6ct
    is not installed.
    """
    if not shutil.which("qt6ct"):
        return
    for path, contents in ((QT6CT_COLORS_FILE, build_qt_colors(colors)),
                           (QT6CT_CONFIG_FILE, build_qt6ct_config())):
        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(contents)
        except OSError as error:
            sys.stderr.write(f"Cannot write {os.path.basename(path)}: {error}\n")


def write_qt_theme(colors):
    """Write the qt6ct palette (all Qt apps) and kdeglobals (KDE apps)."""
    write_qt6ct_theme(colors)
    write_kde_colors(colors)


def build_vesktop_css(colors):
    """Discord's CSS custom properties, set from the palette.

    Vencord loads this after Discord's stylesheet. Only custom properties are
    set, never classes, since Discord's class names are hashed per build.

    Two generations of names are written: the classic ones
    (`--background-secondary`...) and the visual refresh's
    (`--background-base-lower`...); a build reads one set or the other.
    `!important` is required because Discord declares its tokens on compound
    selectors. The grounds match GTK's.
    """
    accent = colors.get("accent", "#0a84ff")
    ground = gtk_ground(colors.get("background", "#1e1e1e"), accent)
    surface = colors.get("surface", colors.get("background", "#1e1e1e"))
    raised = gtk_ground(surface, accent)
    hover = gtk_ground(colors.get("surfaceHover", surface), accent)
    deep = mix(ground, "#000000", VESKTOP_DEEP)
    border = gtk_ground(colors.get("border", raised), accent)

    text = lift(colors.get("text", "#ffffff"), GTK_MIN_CONTRAST, ground)
    muted = lift(colors.get("textMuted", text), VESKTOP_MUTED_CONTRAST, ground)
    on_accent = colors.get("accentText", "#ffffff")
    hovered = colors.get("accentHover", accent)

    red = colors.get("red", "#ff453a")
    green = colors.get("green", "#32d74b")
    yellow = colors.get("yellow", "#ffd60a")
    blue = colors.get("blue", accent)

    # Status colours stay as-is where Discord fills with them and are lifted
    # where it writes text in them.
    def typed(value):
        return lift(value, GTK_MIN_CONTRAST, ground)

    # One rung of the brand ramp: lighter below 500, darker above.
    def rung(value):
        distance = (value - 500) / 400
        if distance < 0:
            return mix(accent, "#ffffff", -distance * VESKTOP_RAMP)
        return mix(accent, "#000000", distance * VESKTOP_RAMP)

    # The same rung as an "H S% L%" triplet. Most of Discord's translucent
    # accents are `hsl(var(--brand-500-hsl) / a)` and never read --brand-500.
    def parts(value):
        hue, lightness, sat = colorsys.rgb_to_hls(*(c / 255 for c in hex_to_rgb(value)))
        return f"{hue * 360:.1f} {sat * 100:.1f}% {lightness * 100:.1f}%"

    grounds = [
        # Darkest at the window edge, lightest in the chat, as in Discord.
        ("background-tertiary", deep),
        ("background-secondary", ground),
        ("background-secondary-alt", ground),
        ("background-primary", raised),
        ("background-accent", accent),
        ("background-floating", deep),
        ("background-nested-floating", raised),
        ("background-mobile-primary", raised),
        ("background-mobile-secondary", ground),
        ("background-modifier-hover", hover),
        ("background-modifier-active", hover),
        ("background-modifier-selected", hover),
        ("background-modifier-accent", border),
        ("channeltextarea-background", ground),
        ("activity-card-background", raised),
        ("deprecated-card-bg", raised),
        ("deprecated-card-editable-bg", raised),
        ("modal-background", raised),
        ("modal-footer-background", ground),
        ("input-background", ground),
        ("popover-background", raised),
        ("chat-background", raised),
        ("home-background", raised),
    ]

    type_ = [
        ("text-normal", text),
        ("text-muted", muted),
        ("text-link", typed(blue)),
        ("text-link-low-saturation", typed(blue)),
        ("text-positive", typed(green)),
        ("text-danger", typed(red)),
        ("text-warning", typed(yellow)),
        ("header-primary", text),
        ("header-secondary", muted),
        ("interactive-normal", muted),
        ("interactive-hover", text),
        ("interactive-active", text),
        ("interactive-muted", border),
        ("channels-default", muted),
        ("channel-icon", muted),
    ]

    brand = [("brand-experiment", accent),
             ("brand-new", accent),
             ("button-outline-brand-text", typed(accent)),
             ("button-outline-brand-border", accent),
             ("button-filled-brand-background", accent),
             ("button-filled-brand-background-hover", hovered),
             ("button-filled-brand-text", on_accent),
             ("control-brand-foreground", accent),
             ("control-brand-foreground-new", accent),
             ("mention-foreground", on_accent),
             ("mention-background", accent)]
    for value in VESKTOP_STEPS:
        brand.append((f"brand-{value}", rung(value)))
        brand.append((f"brand-experiment-{value}", rung(value)))
        brand.append((f"brand-{value}-hsl", parts(rung(value))))
    # The two aliases outside the ramp.
    brand.append(("blurple-50-hsl", parts(accent)))
    brand.append(("illo-blue-40-hsl", parts(accent)))

    # --opacity-blurple-N is separate from the ramp: each carries its own
    # triplet. N is 1, then every 4 up to 96.
    for value in (1,) + tuple(range(4, 100, 4)):
        brand.append((f"opacity-blurple-{value}",
                      f"hsl({parts(accent)} / {value / 100:.2f})"))
        brand.append((f"opacity-blurple-{value}-hsl", parts(accent)))

    # The remaining named purples. --premium-tier-* (Nitro branding) is left
    # alone.
    veil = lambda amount: f"hsl({parts(accent)} / {amount:.2f})"
    brand += [
        ("message-highlight-background-default", veil(0.10)),
        ("message-highlight-background-hover", veil(0.16)),
        ("reaction-background-reacted-default", veil(0.12)),
        ("reaction-background-reacted-hover", veil(0.20)),
        ("datepicker-range-background-default", veil(0.16)),
        ("datepicker-range-background-hover", veil(0.24)),
        ("togglebutton-background-selected", accent),
        ("togglebutton-background-selected-hover", hovered),
        ("togglebutton-background-selected-active", hovered),
        ("togglebutton-border-active", accent),
        # Code blocks are recessed towards the border colour, which also works
        # on light palettes.
        ("background-code", mix(ground, border, 0.35)),
    ]

    status = [
        ("status-positive-background", green),
        ("status-positive-text", on_accent),
        ("status-danger-background", red),
        ("status-danger-text", on_accent),
        ("status-warning-background", yellow),
        ("status-warning-text", on_accent),
        ("info-positive-foreground", typed(green)),
        ("info-positive-background", mix(ground, green, 0.14)),
        ("info-danger-foreground", typed(red)),
        ("info-danger-background", mix(ground, red, 0.14)),
        ("info-warning-foreground", typed(yellow)),
        ("info-warning-background", mix(ground, yellow, 0.14)),
        ("info-help-foreground", typed(blue)),
        ("info-help-background", mix(ground, blue, 0.14)),
        ("green-360", green),
        ("red-400", red),
        ("yellow-300", yellow),
    ]

    # Transparent track, border-coloured thumb.
    scrollbars = [
        ("scrollbar-thin-thumb", border),
        ("scrollbar-thin-track", "transparent"),
        ("scrollbar-auto-thumb", border),
        ("scrollbar-auto-track", ground),
        ("scrollbar-auto-scrollbar-color-thumb", border),
        ("scrollbar-auto-scrollbar-color-track", ground),
    ]

    # The visual refresh's names. A build reads only one of the two sets, so
    # both are written.
    refreshed = [
        # Darkest at the frame. theme-midnight sets all three to black unless
        # they are overridden.
        ("background-base-lowest", deep),
        ("background-base-lower", ground),
        ("background-base-low", ground),
        ("background-surface-high", raised),
        ("background-surface-higher", raised),
        ("background-surface-highest", hover),

        # The accent where the refresh names it rather than the ramp.
        ("background-brand", accent),
        ("badge-background-brand", accent),
        ("control-primary-background-default", accent),
        ("checkbox-background-selected-default", accent),
        ("interactive-accent-background-hover", accent),
        ("interactive-accent-background-selected", accent),
        ("interactive-accent-background-active", hovered),
        ("border-focus", accent),
        ("input-border-active", accent),

        # Channel names and icons in the refresh.
        ("interactive-text-default", muted),
        ("interactive-text-hover", text),
        ("interactive-text-active", text),
        ("interactive-icon-default", muted),
        ("interactive-icon-hover", text),
        ("interactive-icon-active", text),

        ("text-default", text),
        ("text-secondary", muted),
        ("text-tertiary", muted),
        ("text-brand", typed(accent)),
        ("text-feedback-critical", typed(red)),
        ("text-feedback-positive", typed(green)),
        ("text-feedback-warning", typed(yellow)),
        ("text-feedback-info", typed(blue)),

        ("border-subtle", border),
        ("border-faint", mix(ground, border, 0.5)),
        ("border-strong", border),
        ("border-feedback-critical", red),
        ("border-feedback-positive", green),
        ("border-feedback-warning", yellow),
        ("border-feedback-info", blue),
    ]

    # Vencord reads this header to list the theme.
    lines = [
        "/**",
        " * @name impasto",
        " * @description The desk's palette, written by theme_manager.py on",
        " *   every palette push. Edits here are lost at the next switch.",
        " * @author impasto",
        " */",
        "",
        # Also on the theme classes: Discord sets .theme-dark on a wrapper div,
        # which overrides values defined only on :root.
        ":root,",
        ".theme-dark,",
        ".theme-light,",
        ".theme-darker,",
        ".theme-midnight,",
        ".visual-refresh {",
    ]
    for group in (grounds, type_, brand, status, scrollbars, refreshed):
        lines.append("")
        lines += [f"  --{name}: {value} !important;" for name, value in group]
    lines += ["}", ""]
    return "\n".join(lines)


def tick_vesktop_theme():
    """Add the theme to Vencord's enabled themes, keeping everything else.

    Returns success. A settings file that cannot be read is left alone.
    Written with four-space indentation, as Vencord writes it.
    """
    if not shutil.which("vesktop"):
        sys.stderr.write("vesktop is not installed\n")
        return False
    settings = {}
    if os.path.exists(VESKTOP_SETTINGS_FILE):
        try:
            with open(VESKTOP_SETTINGS_FILE, encoding="utf-8") as handle:
                raw = handle.read()
            settings = json.loads(raw) if raw.strip() else {}
        except (OSError, ValueError) as error:
            sys.stderr.write(f"Cannot read Vencord's settings, so they are "
                             f"left alone: {error}\n")
            return False
        if not isinstance(settings, dict):
            sys.stderr.write("Vencord's settings are not an object, so they "
                             "are left alone\n")
            return False

    themes = settings.get("enabledThemes")
    if not isinstance(themes, list):
        themes = []
    name = os.path.basename(VESKTOP_THEME_FILE)
    if name in themes:
        return True
    settings["enabledThemes"] = themes + [name]
    temporary = VESKTOP_SETTINGS_FILE + ".impasto"
    try:
        os.makedirs(os.path.dirname(VESKTOP_SETTINGS_FILE), exist_ok=True)
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump(settings, handle, indent=4, ensure_ascii=False)
        os.replace(temporary, VESKTOP_SETTINGS_FILE)
    except OSError as error:
        sys.stderr.write(f"Cannot write Vencord's settings: {error}\n")
        return False
    return True


def write_vesktop_css(colors):
    """Write the theme into Vesktop's themes directory.

    Not quickCss.css, which is for the user's own rules. The theme has to be
    enabled once in Vesktop's settings; after that Vencord watches the file
    and repaints live. The push never edits Vencord's settings.json, which
    Vencord rewrites itself.
    """
    if not shutil.which("vesktop"):
        return
    try:
        os.makedirs(VESKTOP_THEMES_DIR, exist_ok=True)
        with open(VESKTOP_THEME_FILE, "w", encoding="utf-8") as handle:
            handle.write(build_vesktop_css(colors))
    except OSError as error:
        sys.stderr.write(f"Cannot write Vesktop's theme: {error}\n")


def build_spicetify_colors(colors):
    """spicetify's color.ini.

    spicetify names every colour Spotify uses, so this is a direct mapping.
    The values only take effect after `spicetify apply`. Hex values are
    written without `#`, which spicetify would read as a comment.
    """
    accent = colors.get("accent", "#0a84ff")
    ground = gtk_ground(colors.get("background", "#1e1e1e"), accent)
    surface = colors.get("surface", colors.get("background", "#1e1e1e"))
    raised = gtk_ground(surface, accent)
    hover = gtk_ground(colors.get("surfaceHover", surface), accent)
    border = gtk_ground(colors.get("border", raised), accent)

    text = lift(colors.get("text", "#ffffff"), GTK_MIN_CONTRAST, ground)
    muted = lift(colors.get("textMuted", text), VESKTOP_MUTED_CONTRAST, ground)
    hovered = colors.get("accentHover", accent)
    red = colors.get("red", "#ff453a")

    def bare(value):
        return value.lstrip("#")

    # The sidebar and player bar sit on the ground, not above it, so the
    # scrolling main area is not framed by lighter bands.
    slots = [
        ("text", text),
        ("subtext", muted),
        ("main", ground),
        ("main-elevated", raised),
        ("highlight", hover),
        ("highlight-elevated", hover),
        ("sidebar", ground),
        ("player", ground),
        ("card", raised),
        ("shadow", mix(ground, "#000000", SPICETIFY_SHADOW)),
        ("selected-row", accent),
        ("button", accent),
        ("button-active", hovered),
        ("button-disabled", mix(muted, ground, SPICETIFY_DISABLED)),
        ("tab-active", hover),
        ("notification", raised),
        ("notification-error", red),
        ("misc", border),
    ]

    lines = ["; GENERATED by scripts/theme_manager.py on every palette change.",
             "; Edits here are lost at the next switch. Spotify wears it from",
             "; its next start, once `./setup spotify` has patched it.",
             "",
             "[base]"]
    lines += [f"{name:<19}= {bare(value)}" for name, value in slots]
    return "\n".join(lines) + "\n"


def write_spicetify_colors(colors):
    """Write color.ini into spicetify's theme directory.

    Guarded on spicetify rather than spotify. It never runs `spicetify
    apply`, which re-patches the client and restarts it; `refresh_spotify`
    carries the scheme into a client already patched.
    """
    if not shutil.which("spicetify"):
        return
    try:
        os.makedirs(SPICETIFY_THEME_DIR, exist_ok=True)
        with open(SPICETIFY_COLORS_FILE, "w", encoding="utf-8") as handle:
            handle.write(build_spicetify_colors(colors))
    except OSError as error:
        sys.stderr.write(f"Cannot write Spotify's colour scheme: {error}\n")


def refresh_spotify():
    """Rewrite the palette inside an already patched Spotify.

    `spicetify refresh` rewrites the stylesheets in Apps/xpui and nothing
    else: no re-patch and no restart, so a running client keeps its colours
    until it next starts. Only when the impasto theme is the selected one and
    the client is patched and writable; the first patch is `./setup spotify`.
    Last in the push, since spicetify may ask the network for a new version.
    """
    if not shutil.which("spicetify"):
        return
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        parser.read(SPICETIFY_CONFIG_FILE, encoding="utf-8")
    except (configparser.Error, OSError, UnicodeDecodeError):
        return
    if not parser.has_section("Setting"):
        return
    setting = parser["Setting"]
    if setting.get("current_theme", "").strip() != "impasto":
        return
    spotify = os.path.expandvars(setting.get("spotify_path", "").strip())
    xpui = os.path.join(spotify, "Apps", "xpui")
    if not spotify or not os.path.isdir(xpui) or not os.access(xpui, os.W_OK):
        return
    try:
        result = subprocess.run(["spicetify", "-n", "refresh"],
                                capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as error:
        sys.stderr.write(f"spicetify refresh failed: {error}\n")
        return
    if result.returncode != 0:
        sys.stderr.write("spicetify refresh failed: "
                         f"{(result.stdout + result.stderr).strip()[-300:]}\n")


def build_imv_config(colors):
    """imv's whole configuration; imv has no theme or include mechanism.

    The background is the terminal's tinted ground, so a picture opened from
    yazi sits on the same colour.
    """
    ground = terminal_background(colors)
    text = lift(colors["text"], MIN_CONTRAST, ground)

    # imv takes bare hex, with the alpha as a separate field.
    def bare(value):
        return value.lstrip("#")

    return "\n".join([
        "# GENERATED by scripts/theme_manager.py on every palette change.",
        "# imv reads only this file; edits here are lost at the next switch.",
        "",
        "[options]",
        f"background = {bare(ground)}",
        f"overlay_text_color = {bare(text)}",
        f"overlay_background_color = {bare(ground)}",
        f"overlay_background_alpha = {IMV_OVERLAY_ALPHA}",
        # imv's default overlay font is too large for the window. The family
        # stays generic; the mono font is a separate setting.
        f"overlay_font = {IMV_OVERLAY_FONT}",
    ]) + "\n"


def write_imv_config(colors):
    """Write imv's config, which the push owns entirely."""
    if not shutil.which("imv"):
        return
    try:
        os.makedirs(os.path.dirname(IMV_CONFIG_FILE), exist_ok=True)
        with open(IMV_CONFIG_FILE, "w", encoding="utf-8") as handle:
            handle.write(build_imv_config(colors))
    except OSError as error:
        sys.stderr.write(f"Cannot write imv's configuration: {error}\n")


def build_nvim_colorscheme(colors):
    """A Lua colourscheme for neovim.

    Syntax colours follow SYNTAX_SCOPES, as in yazi and VSCodium; treesitter
    captures and LSP semantic tokens are linked to those groups rather than
    given colours of their own. `Normal` has no background, so kitty's
    translucent ground shows through; only shapes (cursor line, selection,
    menus) get fills.
    """
    ground = terminal_background(colors)

    def on(key):
        return lift(colors[key], MIN_CONTRAST, ground)

    text, muted, accent = on("text"), on("textMuted"), on("accent")
    red, green, yellow, blue = on("red"), on("green"), on("yellow"), on("blue")
    types = on("accentHover")

    # Comments are dimmed. Lines carry no text, so they are not
    # contrast-checked.
    comment = mix(muted, ground, NVIM_COMMENT_DIM)
    line = mix(colors["border"], ground, TERMINAL_LINE)

    # Line numbers start from the comment colour and are lifted back to the
    # contrast floor.
    gutter = lift(comment, MIN_CONTRAST, ground)

    # The two fills text is drawn on; text on them is lifted against the fill,
    # not against the terminal ground.
    raised = mix(ground, text, TERMINAL_RAISE)
    filled = mix(ground, colors["accent"], TERMINAL_STATE_FILL)

    def over(fill, key):
        return lift(colors[key], MIN_CONTRAST, fill)

    groups = [
        # ── the surface ──
        ("Normal", {"fg": text, "bg": "NONE"}),
        ("NormalNC", {"fg": text, "bg": "NONE"}),
        ("NormalFloat", {"fg": text, "bg": "NONE"}),
        ("FloatBorder", {"fg": line, "bg": "NONE"}),
        ("FloatTitle", {"fg": accent, "bold": True}),
        ("WinSeparator", {"fg": line}),
        ("EndOfBuffer", {"fg": ground}),
        ("Folded", {"fg": lift(comment, MIN_CONTRAST, raised), "bg": raised}),
        ("ColorColumn", {"bg": raised}),
        ("Conceal", {"fg": comment}),
        ("Directory", {"fg": accent}),
        ("Title", {"fg": accent, "bold": True}),

        # ── where you are ──
        ("Cursor", {"fg": ground, "bg": accent}),
        ("lCursor", {"fg": ground, "bg": accent}),
        ("CursorLine", {"bg": raised}),
        ("CursorColumn", {"bg": raised}),
        ("CursorLineNr", {"fg": accent, "bold": True}),
        ("LineNr", {"fg": gutter}),
        ("SignColumn", {"bg": "NONE"}),
        ("MatchParen", {"fg": accent, "bold": True, "underline": True}),

        # ── selection and search ──
        # text on the fill is lifted against the fill
        ("Visual", {"bg": filled}),
        ("VisualNOS", {"bg": filled}),
        ("Search", {"fg": over(filled, "text"), "bg": filled}),
        ("IncSearch", {"fg": ground, "bg": yellow}),
        ("CurSearch", {"fg": ground, "bg": accent}),
        ("Substitute", {"fg": ground, "bg": red}),

        # ── the menus ──
        ("Pmenu", {"fg": text, "bg": raised}),
        ("PmenuSel", {"fg": over(filled, "text"), "bg": filled, "bold": True}),
        ("PmenuSbar", {"bg": raised}),
        ("PmenuThumb", {"bg": line}),
        ("PmenuKind", {"fg": types, "bg": raised}),
        ("PmenuExtra", {"fg": comment, "bg": raised}),
        ("WildMenu", {"fg": over(filled, "text"), "bg": filled}),
        ("QuickFixLine", {"bg": raised}),

        # ── statusline and tabline ──
        # lualine's `theme = "auto"` builds from these.
        ("StatusLine", {"fg": text, "bg": "NONE"}),
        ("StatusLineNC", {"fg": comment, "bg": "NONE"}),
        ("TabLine", {"fg": muted, "bg": "NONE"}),
        ("TabLineSel", {"fg": accent, "bg": "NONE", "bold": True}),
        ("TabLineFill", {"bg": "NONE"}),
        ("WinBar", {"fg": muted, "bold": True}),
        ("WinBarNC", {"fg": comment}),

        # ── messages ──
        ("ModeMsg", {"fg": accent, "bold": True}),
        ("MoreMsg", {"fg": green}),
        ("Question", {"fg": green}),
        ("ErrorMsg", {"fg": red, "bold": True}),
        ("WarningMsg", {"fg": yellow}),
        ("NonText", {"fg": comment}),
        ("Whitespace", {"fg": mix(comment, ground, TERMINAL_DIM)}),
        ("SpecialKey", {"fg": comment}),

        # ── syntax scopes ──
        ("Comment", {"fg": comment, "italic": True}),
        ("String", {"fg": green}),
        ("Character", {"fg": green}),
        ("Number", {"fg": yellow}),
        ("Float", {"fg": yellow}),
        ("Boolean", {"fg": yellow}),
        ("Constant", {"fg": yellow}),
        ("Identifier", {"fg": text}),
        ("Function", {"fg": blue}),
        ("Statement", {"fg": accent}),
        ("Keyword", {"fg": accent}),
        ("Conditional", {"fg": accent}),
        ("Repeat", {"fg": accent}),
        ("Exception", {"fg": accent}),
        ("Label", {"fg": accent}),
        ("Operator", {"fg": muted}),
        ("Delimiter", {"fg": muted}),
        ("PreProc", {"fg": red}),
        # Imports take the keyword colour, as `import` does in yazi's tmTheme;
        # `#define` and macros stay red.
        ("Include", {"fg": accent}),
        ("Define", {"fg": red}),
        ("Macro", {"fg": red}),
        ("Type", {"fg": types}),
        ("StorageClass", {"fg": types}),
        ("Structure", {"fg": types}),
        ("Typedef", {"fg": types}),
        ("Special", {"fg": red}),
        ("SpecialChar", {"fg": red}),
        ("Tag", {"fg": red}),
        ("Underlined", {"fg": accent, "underline": True}),
        ("Error", {"fg": red, "bold": True}),
        ("Todo", {"fg": ground, "bg": yellow, "bold": True}),

        # ── the diagnostics ──
        # The palette's own status colours, not the bar's fixed indicator hues.
        ("DiagnosticError", {"fg": red}),
        ("DiagnosticWarn", {"fg": yellow}),
        ("DiagnosticInfo", {"fg": blue}),
        ("DiagnosticHint", {"fg": accent}),
        ("DiagnosticOk", {"fg": green}),
        ("DiagnosticUnderlineError", {"sp": red, "undercurl": True}),
        ("DiagnosticUnderlineWarn", {"sp": yellow, "undercurl": True}),
        ("DiagnosticUnderlineInfo", {"sp": blue, "undercurl": True}),
        ("DiagnosticUnderlineHint", {"sp": accent, "undercurl": True}),

        # ── diff ──
        ("DiffAdd", {"bg": mix(ground, colors["green"], TERMINAL_STATE_FILL)}),
        ("DiffChange", {"bg": mix(ground, colors["blue"], TERMINAL_STATE_FILL)}),
        ("DiffDelete", {"fg": red, "bg": mix(ground, colors["red"], TERMINAL_DIM * 0.5)}),
        ("DiffText", {"bg": mix(ground, colors["blue"], TERMINAL_STATE_FILL * 1.6)}),
        ("Added", {"fg": green}),
        ("Changed", {"fg": blue}),
        ("Removed", {"fg": red}),

        # ── the gutter ──
        ("GitSignsAdd", {"fg": green}),
        ("GitSignsChange", {"fg": blue}),
        ("GitSignsDelete", {"fg": red}),

        # ── lazy.nvim and blink.cmp ──
        ("LazyNormal", {"fg": text, "bg": "NONE"}),
        ("LazyButtonActive", {"fg": ground, "bg": accent}),
        ("BlinkCmpMenu", {"fg": text, "bg": raised}),
        ("BlinkCmpMenuSelection", {"fg": over(filled, "text"), "bg": filled}),
        ("BlinkCmpLabelMatch", {"fg": accent, "bold": True}),
        ("BlinkCmpDoc", {"fg": text, "bg": raised}),
        ("BlinkCmpDocBorder", {"fg": line}),

        # ── the tree ──
        # nvim-tree links almost all of its groups to the ones above
        # (NvimTreeNormal -> Normal), so only these need colours. Six more
        # groups (arrows, bookmark, folder icons, indent marker) link to the
        # folder icon.
        ("NvimTreeFolderIcon", {"fg": accent}),
        # The indent marker is chrome, so it takes the hairline.
        ("NvimTreeIndentMarker", {"fg": line}),
        ("NvimTreeWindowPicker", {"fg": ground, "bg": accent, "bold": True}),
    ]

    # Treesitter captures link to the base groups, so groups added by newer
    # neovim versions inherit instead of falling back to Normal.
    links = {
        "@comment": "Comment",
        "@string": "String",
        "@string.escape": "SpecialChar",
        "@string.special": "SpecialChar",
        "@character": "Character",
        "@number": "Number",
        "@number.float": "Float",
        "@boolean": "Boolean",
        "@constant": "Constant",
        "@constant.builtin": "Constant",
        "@constant.macro": "Macro",
        "@function": "Function",
        "@function.call": "Function",
        "@function.builtin": "Function",
        "@function.method": "Function",
        "@function.method.call": "Function",
        "@constructor": "Type",
        "@keyword": "Keyword",
        "@keyword.function": "Keyword",
        "@keyword.operator": "Operator",
        "@keyword.return": "Keyword",
        "@keyword.conditional": "Conditional",
        "@keyword.repeat": "Repeat",
        "@keyword.exception": "Exception",
        "@keyword.import": "Include",
        "@keyword.directive": "PreProc",
        "@operator": "Operator",
        "@punctuation.delimiter": "Delimiter",
        "@punctuation.bracket": "Delimiter",
        "@punctuation.special": "SpecialChar",
        "@variable": "Identifier",
        "@variable.builtin": "Special",
        "@variable.parameter": "Identifier",
        "@variable.member": "Identifier",
        "@property": "Identifier",
        "@field": "Identifier",
        "@type": "Type",
        "@type.builtin": "Type",
        "@type.definition": "Typedef",
        "@module": "Type",
        "@label": "Label",
        "@attribute": "Number",
        "@tag": "Tag",
        "@tag.attribute": "Number",
        "@tag.delimiter": "Delimiter",
        "@markup.heading": "Title",
        "@markup.strong": "Special",
        "@markup.italic": "Comment",
        "@markup.link": "Underlined",
        "@markup.link.url": "Underlined",
        "@markup.raw": "String",
        "@markup.list": "Operator",
        "@markup.quote": "Comment",
        # nvim-tree's git icons use the same groups as the gutter and the diff
        # (by default `new` links to PreProc and `dirty` to Statement).
        "NvimTreeGitNewIcon": "Added",
        "NvimTreeGitStagedIcon": "Added",
        "NvimTreeGitDirtyIcon": "Changed",
        "NvimTreeGitRenamedIcon": "Changed",
        "NvimTreeGitDeletedIcon": "Removed",
        "NvimTreeGitMergeIcon": "WarningMsg",
        "@diff.plus": "Added",
        "@diff.minus": "Removed",
        "@diff.delta": "Changed",
        # LSP semantic tokens; unlinked, they override treesitter with
        # neovim's defaults.
        "@lsp.type.class": "Type",
        "@lsp.type.comment": "Comment",
        "@lsp.type.enum": "Type",
        "@lsp.type.enumMember": "Constant",
        "@lsp.type.function": "Function",
        "@lsp.type.interface": "Type",
        "@lsp.type.keyword": "Keyword",
        "@lsp.type.method": "Function",
        "@lsp.type.namespace": "Type",
        "@lsp.type.number": "Number",
        "@lsp.type.operator": "Operator",
        "@lsp.type.parameter": "Identifier",
        "@lsp.type.property": "Identifier",
        "@lsp.type.string": "String",
        "@lsp.type.struct": "Type",
        "@lsp.type.type": "Type",
        "@lsp.type.variable": "Identifier",
    }

    # :terminal colours, the same slots as the kitty fragment.
    terminal = [ground, colors["red"], colors["green"], colors["yellow"],
                colors["blue"], colors["red"], colors["accent"], muted,
                comment, brighten(colors["red"], ground),
                brighten(colors["green"], ground),
                brighten(colors["yellow"], ground),
                brighten(colors["blue"], ground),
                brighten(colors["red"], ground),
                brighten(colors["accent"], ground), text]

    def spec(attributes):
        parts = []
        for key, value in attributes.items():
            if isinstance(value, bool):
                parts.append(f"{key} = {'true' if value else 'false'}")
            else:
                parts.append(f'{key} = "{value}"')
        return "{ " + ", ".join(parts) + " }"

    lines = [
        "-- GENERATED by scripts/theme_manager.py on every palette change.",
        "-- Loaded by name off the runtimepath `lua/modules/theme.lua` adds;",
        "-- edits here are lost at the next theme switch.",
        "",
        'vim.cmd("highlight clear")',
        'if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end',
        "",
        "vim.o.termguicolors = true",
        'vim.g.colors_name = "impasto"',
        "",
        "local hl = vim.api.nvim_set_hl",
        "",
    ]
    for name, attributes in groups:
        lines.append(f'hl(0, "{name}", {spec(attributes)})')
    lines += ["", "for group, target in pairs({"]
    for name, target in links.items():
        lines.append(f'    ["{name}"] = "{target}",')
    lines += ["}) do", "    hl(0, group, { link = target })", "end", ""]
    for index, value in enumerate(terminal):
        lines.append(f'vim.g.terminal_color_{index} = "{value}"')
    return "\n".join(lines) + "\n"


def push_nvim_colorscheme(colors):
    """Write the colourscheme and apply it in every running neovim.

    Uses --remote-expr rather than --remote-send: sending keys would need
    <C-\\><C-N> first and would leave insert mode; the expression does not
    change the mode.
    """
    try:
        os.makedirs(os.path.dirname(NVIM_COLORS_FILE), exist_ok=True)
        with open(NVIM_COLORS_FILE, "w", encoding="utf-8") as handle:
            handle.write(build_nvim_colorscheme(colors))
    except OSError as error:
        sys.stderr.write(f"Cannot write neovim's colourscheme: {error}\n")
        return

    nvim = shutil.which("nvim")
    if not nvim:
        return

    for socket_path in sorted(glob.glob(NVIM_SOCKETS)):
        result = subprocess.run(
            [nvim, "--server", socket_path, "--remote-expr",
             'luaeval("tostring(pcall(vim.cmd.colorscheme, \'impasto\'))")'],
            capture_output=True, text=True, timeout=5)
        if result.returncode != 0:
            # A stale socket from a closed neovim; keep going.
            sys.stderr.write(f"{os.path.basename(socket_path)}: "
                             f"{result.stderr.strip()}\n")


def build_vscodium_manifest(colors):
    """The extension's package.json.

    `uiTheme` picks which built-in defaults fill the colours the theme leaves
    unset, so it is recomputed on every push (one palette is light). The theme
    leaves translucent colours (minimap slider, scrims) to those defaults.
    """
    ground = gtk_ground(colors.get("background", "#1e1e1e"),
                        colors.get("accent", "#0a84ff"))
    lit = luminance(*hex_to_rgb(ground)) > GTK_LIGHT_ABOVE
    manifest = {
        "name": "impasto",
        "displayName": VSCODIUM_LABEL,
        "description": "The wallpaper's palette. Generated; edits are lost.",
        "version": "1.0.0",
        "publisher": "impasto",
        "engines": {"vscode": "^1.0.0"},
        "categories": ["Themes"],
        "contributes": {
            "themes": [{
                "label": VSCODIUM_LABEL,
                "uiTheme": "vs" if lit else "vs-dark",
                "path": "./themes/" + os.path.basename(VSCODIUM_THEME_FILE),
            }],
        },
    }
    # No "generated" comment: VSCodium rejects a package.json with comments.
    # The theme file is parsed as JSONC and does carry one.
    return json.dumps(manifest, indent=2) + "\n"


def build_vscodium_theme(colors):
    """VSCodium's workbench and token colours.

    The ground is GTK's (gtk_ground), not the terminal's: VSCodium draws its
    own window, so it matches the other GTK windows and Vesktop. Syntax colours
    are SYNTAX_SCOPES, as in yazi, with finer scopes mapped onto the same
    colours.
    """
    accent = colors.get("accent", "#0a84ff")
    ground = gtk_ground(colors.get("background", "#1e1e1e"), accent)
    panel = gtk_ground(colors.get("surface", colors.get("background", "#1e1e1e")),
                       accent)
    chrome = mix(ground, "#000000", VSCODIUM_CHROME)
    on_accent = colors.get("accentText", "#ffffff")

    def on(key, fill=None):
        return lift(colors[key], MIN_CONTRAST, fill or ground)

    text, muted = on("text"), on("textMuted")
    accent_text = on("accent")
    red, green, yellow, blue = on("red"), on("green"), on("yellow"), on("blue")
    types = on("accentHover")

    # Comments use the editor dimming, as in neovim, not the preview pane's.
    comment = mix(muted, ground, NVIM_COMMENT_DIM)
    # Line numbers: the comment colour lifted back to the contrast floor.
    gutter = lift(comment, MIN_CONTRAST, ground)

    hairline = mix(colors.get("border", panel), ground, TERMINAL_LINE)
    # Two fills, built from the ground rather than the palette's surfaces: a
    # wash for hover and the current line, the accent tint for selection.
    wash = mix(ground, text, TERMINAL_RAISE)
    fill = mix(ground, accent, TERMINAL_STATE_FILL)
    on_fill = lift(colors["text"], MIN_CONTRAST, fill)

    colours = {
        # ── the window ──
        "foreground": text,
        "disabledForeground": comment,
        "descriptionForeground": muted,
        "errorForeground": red,
        "focusBorder": accent,
        "selection.background": fill,
        "icon.foreground": muted,
        "widget.border": hairline,
        "sash.hoverBorder": accent,
        "textLink.foreground": accent_text,
        "textLink.activeForeground": types,
        "textSeparator.foreground": hairline,
        "textBlockQuote.background": panel,
        "textCodeBlock.background": panel,
        "textPreformat.foreground": types,

        # ── window chrome ──
        "titleBar.activeBackground": chrome,
        "titleBar.activeForeground": text,
        "titleBar.inactiveBackground": chrome,
        "titleBar.inactiveForeground": muted,
        "titleBar.border": hairline,
        "activityBar.background": chrome,
        "activityBar.foreground": accent_text,
        "activityBar.inactiveForeground": muted,
        "activityBar.activeBorder": accent,
        "activityBar.border": hairline,
        "activityBarBadge.background": accent,
        "activityBarBadge.foreground": on_accent,
        "sideBar.background": chrome,
        "sideBar.foreground": text,
        "sideBar.border": hairline,
        "sideBarTitle.foreground": muted,
        "sideBarSectionHeader.background": chrome,
        "sideBarSectionHeader.foreground": text,
        "sideBarSectionHeader.border": hairline,
        "statusBar.background": chrome,
        "statusBar.foreground": muted,
        "statusBar.border": hairline,
        "statusBar.noFolderBackground": chrome,
        "statusBar.debuggingBackground": accent,
        "statusBar.debuggingForeground": on_accent,
        "statusBarItem.hoverBackground": wash,
        "statusBarItem.prominentBackground": fill,
        "statusBarItem.prominentForeground": on_fill,
        "statusBarItem.remoteBackground": accent,
        "statusBarItem.remoteForeground": on_accent,
        "statusBarItem.errorBackground": colors.get("red", red),
        "statusBarItem.errorForeground": on_accent,
        "statusBarItem.warningBackground": colors.get("yellow", yellow),
        "statusBarItem.warningForeground": on_accent,

        # ── tabs ──
        "editorGroupHeader.tabsBackground": chrome,
        "editorGroupHeader.noTabsBackground": chrome,
        "editorGroupHeader.border": hairline,
        "editorGroup.border": hairline,
        "editorGroup.dropBackground": fill,
        "tab.activeBackground": ground,
        "tab.activeForeground": text,
        "tab.activeBorderTop": accent,
        "tab.activeBorder": ground,
        "tab.inactiveBackground": chrome,
        "tab.inactiveForeground": muted,
        "tab.hoverBackground": ground,
        "tab.unfocusedActiveBackground": chrome,
        "tab.unfocusedActiveForeground": muted,
        "tab.border": hairline,
        "breadcrumb.background": ground,
        "breadcrumb.foreground": muted,
        "breadcrumb.focusForeground": text,
        "breadcrumb.activeSelectionForeground": accent_text,
        "breadcrumbPicker.background": panel,
        "editorStickyScroll.background": ground,
        "editorStickyScrollHover.background": wash,

        # The notification banner (workspace trust, updates); otherwise it
        # stays VS Code's blue.
        "banner.background": panel,
        "banner.foreground": text,
        "banner.iconForeground": accent_text,
        "commandCenter.background": panel,
        "commandCenter.foreground": muted,
        "commandCenter.border": hairline,
        "commandCenter.activeBackground": wash,
        "commandCenter.activeForeground": text,
        "commandCenter.activeBorder": accent,
        "commandCenter.inactiveForeground": muted,
        "commandCenter.inactiveBorder": hairline,
        "debugToolBar.background": panel,
        "debugToolBar.border": hairline,

        # ── the editor ──
        "editor.background": ground,
        "editor.foreground": text,
        "editorLineNumber.foreground": gutter,
        "editorLineNumber.activeForeground": accent_text,
        "editorCursor.foreground": accent,
        "editor.lineHighlightBackground": wash,
        "editor.selectionBackground": fill,
        "editor.inactiveSelectionBackground": wash,
        "editor.selectionHighlightBackground": wash,
        "editor.wordHighlightBackground": wash,
        "editor.wordHighlightStrongBackground": fill,
        "editor.findMatchBackground": mix(ground, accent, TERMINAL_STATE_FILL * 1.6),
        "editor.findMatchHighlightBackground": fill,
        "editor.findRangeHighlightBackground": wash,
        "editor.hoverHighlightBackground": wash,
        "editor.rangeHighlightBackground": wash,
        "editorWhitespace.foreground": mix(comment, ground, TERMINAL_DIM),
        "editorIndentGuide.background1": hairline,
        "editorIndentGuide.activeBackground1": muted,
        "editorRuler.foreground": hairline,
        "editorCodeLens.foreground": comment,
        "editorInlayHint.background": wash,
        "editorInlayHint.foreground": comment,
        "editorBracketMatch.background": fill,
        "editorBracketMatch.border": accent,
        "editorLink.activeForeground": accent_text,
        "editorGutter.background": ground,
        "editorGutter.addedBackground": green,
        "editorGutter.modifiedBackground": blue,
        "editorGutter.deletedBackground": red,
        "editorError.foreground": red,
        "editorWarning.foreground": yellow,
        "editorInfo.foreground": blue,
        "editorHint.foreground": accent_text,
        "minimap.background": ground,
        "minimap.findMatchHighlight": accent,
        "minimap.selectionHighlight": accent,
        "editorOverviewRuler.border": hairline,
        "editorOverviewRuler.findMatchForeground": accent,
        "editorOverviewRuler.errorForeground": red,
        "editorOverviewRuler.warningForeground": yellow,
        "editorOverviewRuler.infoForeground": blue,
        "editorOverviewRuler.addedForeground": green,
        "editorOverviewRuler.modifiedForeground": blue,
        "editorOverviewRuler.deletedForeground": red,

        # Bracket-pair colours: six rungs from five hues, accentHover and muted.
        "editorBracketHighlight.foreground1": accent_text,
        "editorBracketHighlight.foreground2": yellow,
        "editorBracketHighlight.foreground3": blue,
        "editorBracketHighlight.foreground4": green,
        "editorBracketHighlight.foreground5": types,
        "editorBracketHighlight.foreground6": muted,
        "editorBracketHighlight.unexpectedBracket.foreground": red,

        # ── floating widgets ──
        "editorWidget.background": panel,
        "editorWidget.foreground": text,
        "editorWidget.border": hairline,
        "editorHoverWidget.background": panel,
        "editorHoverWidget.foreground": text,
        "editorHoverWidget.border": hairline,
        "editorSuggestWidget.background": panel,
        "editorSuggestWidget.foreground": text,
        "editorSuggestWidget.border": hairline,
        "editorSuggestWidget.selectedBackground": fill,
        "editorSuggestWidget.selectedForeground": on_fill,
        "editorSuggestWidget.highlightForeground": accent_text,
        "quickInput.background": panel,
        "quickInput.foreground": text,
        "quickInputTitle.background": panel,
        "quickInputList.focusBackground": fill,
        "quickInputList.focusForeground": on_fill,
        "pickerGroup.foreground": muted,
        "pickerGroup.border": hairline,
        "menu.background": panel,
        "menu.foreground": text,
        "menu.border": hairline,
        "menu.separatorBackground": hairline,
        "menu.selectionBackground": fill,
        "menu.selectionForeground": on_fill,
        "menubar.selectionBackground": wash,
        "menubar.selectionForeground": text,
        "notifications.background": panel,
        "notifications.foreground": text,
        "notifications.border": hairline,
        "notificationCenterHeader.background": panel,
        "notificationCenterHeader.foreground": muted,
        "notificationLink.foreground": accent_text,
        "notificationsErrorIcon.foreground": red,
        "notificationsWarningIcon.foreground": yellow,
        "notificationsInfoIcon.foreground": blue,
        "peekView.border": accent,
        "peekViewEditor.background": panel,
        "peekViewEditor.matchHighlightBackground": fill,
        "peekViewResult.background": panel,
        "peekViewResult.selectionBackground": fill,
        "peekViewResult.lineForeground": text,
        "peekViewResult.fileForeground": muted,
        "peekViewResult.matchHighlightBackground": fill,
        "peekViewTitle.background": panel,
        "peekViewTitleLabel.foreground": text,
        "peekViewTitleDescription.foreground": muted,

        # ── inputs, buttons ──
        "input.background": panel,
        "input.foreground": text,
        "input.border": hairline,
        "input.placeholderForeground": comment,
        "inputOption.activeBackground": fill,
        "inputOption.activeBorder": accent,
        "inputOption.activeForeground": on_fill,
        "inputValidation.errorBackground": panel,
        "inputValidation.errorBorder": colors.get("red", red),
        "inputValidation.warningBackground": panel,
        "inputValidation.warningBorder": colors.get("yellow", yellow),
        "inputValidation.infoBackground": panel,
        "inputValidation.infoBorder": colors.get("blue", blue),
        "dropdown.background": panel,
        "dropdown.listBackground": panel,
        "dropdown.foreground": text,
        "dropdown.border": hairline,
        "button.background": accent,
        "button.foreground": on_accent,
        "button.hoverBackground": colors.get("accentHover", accent),
        "button.secondaryBackground": panel,
        "button.secondaryForeground": text,
        "button.secondaryHoverBackground": wash,
        "checkbox.background": panel,
        "checkbox.foreground": text,
        "checkbox.border": hairline,
        "badge.background": accent,
        "badge.foreground": on_accent,
        "progressBar.background": accent,
        "keybindingLabel.background": panel,
        "keybindingLabel.foreground": text,
        "keybindingLabel.border": hairline,
        "keybindingLabel.bottomBorder": hairline,
        "settings.headerForeground": text,
        "settings.modifiedItemIndicator": accent,

        # ── lists and trees ──
        "list.activeSelectionBackground": fill,
        "list.activeSelectionForeground": on_fill,
        "list.inactiveSelectionBackground": wash,
        "list.inactiveSelectionForeground": text,
        "list.focusBackground": fill,
        "list.focusForeground": on_fill,
        "list.hoverBackground": wash,
        "list.hoverForeground": text,
        "list.highlightForeground": accent_text,
        "list.dropBackground": fill,
        "list.errorForeground": red,
        "list.warningForeground": yellow,
        "tree.indentGuidesStroke": hairline,
        "gitDecoration.addedResourceForeground": green,
        "gitDecoration.untrackedResourceForeground": green,
        "gitDecoration.modifiedResourceForeground": blue,
        "gitDecoration.stageModifiedResourceForeground": blue,
        "gitDecoration.deletedResourceForeground": red,
        "gitDecoration.stageDeletedResourceForeground": red,
        "gitDecoration.conflictingResourceForeground": yellow,
        "gitDecoration.ignoredResourceForeground": comment,

        # ── diff ──
        "diffEditor.border": hairline,
        "diffEditor.insertedTextBackground": mix(ground, colors.get("green", green),
                                                 TERMINAL_STATE_FILL * 0.5),
        "diffEditor.removedTextBackground": mix(ground, colors.get("red", red),
                                                TERMINAL_STATE_FILL * 0.5),
        "merge.currentHeaderBackground": mix(ground, colors.get("green", green),
                                             TERMINAL_STATE_FILL),
        "merge.incomingHeaderBackground": mix(ground, colors.get("blue", blue),
                                              TERMINAL_STATE_FILL),

        # ── terminal ──
        # On the chrome: the panel is one of the window's sides.
        "panel.background": chrome,
        "panel.border": hairline,
        "panelTitle.activeForeground": text,
        "panelTitle.activeBorder": accent,
        "panelTitle.inactiveForeground": muted,
        "panelSection.border": hairline,
        "terminal.background": chrome,
        "terminal.foreground": lift(colors["text"], MIN_CONTRAST, chrome),
        "terminal.ansiBlack": chrome,
        "terminalCursor.foreground": accent,
        "terminal.selectionBackground": mix(chrome, accent, TERMINAL_STATE_FILL),
    }


    # Error Lens is themed here rather than in settings.json so it follows the
    # palette. The band is a light wash (VSCODIUM_LENS_WASH) because Error Lens
    # draws over the code, and the message is lifted against the band. The
    # *Light variants get the same values, computed against this palette's
    # ground.
    for state, key in (("error", "red"), ("warning", "yellow"),
                       ("info", "blue"), ("hint", "accent")):
        band = mix(ground, colors.get(key, accent), VSCODIUM_LENS_WASH)
        message = lift(colors.get(key, accent), MIN_CONTRAST, band)
        colours[f"errorLens.{state}Background"] = band
        colours[f"errorLens.{state}BackgroundLight"] = band
        colours[f"errorLens.{state}MessageBackground"] = band
        colours[f"errorLens.{state}RangeBackground"] = band
        colours[f"errorLens.{state}Foreground"] = message
        colours[f"errorLens.{state}ForegroundLight"] = message
        colours[f"errorLens.statusBar{state.capitalize()}Foreground"] = on(key)
    for state, key in (("Error", "red"), ("Warning", "yellow")):
        colours[f"errorLens.statusBarIcon{state}Foreground"] = on(key)

    for slot, key in TERMINAL_NORMAL:
        colours[f"terminal.{VSCODIUM_ANSI[slot]}"] = lift(colors[key], MIN_CONTRAST,
                                                          chrome)
    for slot, key in TERMINAL_BRIGHT:
        colours[f"terminal.{VSCODIUM_ANSI[slot]}"] = brighten(colors[key], chrome)

    # Base scopes, then finer scopes mapped onto the same colours.
    token_colors = [
        {"name": name, "scope": scope,
         "settings": {"foreground": comment if key == "comment" else on(key),
                      **({"fontStyle": style} if style else {})}}
        for name, scope, key, style in SYNTAX_SCOPES
    ]
    extra = [
        ("Escape and placeholder", "constant.character.escape, "
                                   "constant.other.placeholder", red, None),
        ("Preprocessor", "meta.preprocessor, keyword.control.directive", red, None),
        ("Other constant", "constant.other, support.constant", yellow, None),
        ("Namespace", "entity.name.namespace, entity.name.scope-resolution",
         types, None),
        ("Heading", "markup.heading", accent_text, "bold"),
        ("Bold", "markup.bold", text, "bold"),
        ("Italic", "markup.italic", text, "italic"),
        ("Link", "markup.underline.link", accent_text, "underline"),
        ("Literal", "markup.inline.raw, markup.raw", green, None),
        ("Inserted", "markup.inserted", green, None),
        ("Deleted", "markup.deleted", red, None),
    ]
    token_colors += [
        {"name": name, "scope": scope,
         "settings": {"foreground": colour,
                      **({"fontStyle": style} if style else {})}}
        for name, scope, colour, style in extra
    ]

    # Semantic tokens from language servers, mapped to the same colours.
    semantic = {
        "namespace": types, "class": types, "struct": types, "enum": types,
        "interface": types, "type": types, "typeParameter": types,
        "decorator": types,
        "function": blue, "method": blue,
        "macro": red,
        "variable": text, "parameter": text, "property": text,
        "enumMember": yellow, "number": yellow,
        "string": green,
        "keyword": accent_text,
        "operator": muted,
        "comment": {"foreground": comment, "italic": True},
    }

    theme = {
        "name": VSCODIUM_LABEL,
        "type": "light" if luminance(*hex_to_rgb(ground)) > GTK_LIGHT_ABOVE
                else "dark",
        "semanticHighlighting": True,
        "colors": colours,
        "tokenColors": token_colors,
        "semanticTokenColors": semantic,
    }
    # The theme file is parsed as JSONC, so it can carry the header comment.
    return ("// GENERATED by scripts/theme_manager.py on every palette change.\n"
            "// Edits here are lost at the next theme switch.\n"
            + json.dumps(theme, indent=2) + "\n")


def write_vscodium_theme(colors):
    """Write the extension into VSCodium's extensions folder.

    Guarded on `codium`, not `code`: the proprietary build uses a different
    folder. VSCodium does not watch the theme file, so a palette change needs
    `Developer: Reload Window` or a new window.
    """
    if not shutil.which("codium"):
        return
    for path, build in ((VSCODIUM_MANIFEST_FILE, build_vscodium_manifest),
                        (VSCODIUM_THEME_FILE, build_vscodium_theme)):
        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(build(colors))
        except OSError as error:
            sys.stderr.write(f"Cannot write VSCodium's theme: {error}\n")
            return


def strip_jsonc(text):
    """Strip comments and trailing commas from JSONC.

    A scanner rather than a regex, so `//` inside strings (URLs, paths) is
    kept.
    """
    out = []
    index, end = 0, len(text)
    while index < end:
        char = text[index]
        if char == '"':
            close = index + 1
            while close < end:
                if text[close] == "\\":
                    close += 2
                    continue
                if text[close] == '"':
                    break
                close += 1
            out.append(text[index:close + 1])
            index = close + 1
        elif text.startswith("//", index):
            newline = text.find("\n", index)
            # Keep the newline so line numbers in later errors still match.
            index = end if newline < 0 else newline
        elif text.startswith("/*", index):
            close = text.find("*/", index + 2)
            index = end if close < 0 else close + 2
        else:
            out.append(char)
            index += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def quoted_families(families):
    """A CSS-ish font list as VS Code wants it: a name with a space is quoted."""
    named = [family.strip() for family in families.split(",") if family.strip()]
    return ", ".join(f"'{name}'" if " " in name else name for name in named)


def shell_font():
    """The shell's monospace family from its settings (what kitty uses)."""
    try:
        with open(SHELL_SETTINGS_FILE, encoding="utf-8") as handle:
            font = json.load(handle).get("fontMono")
    except (OSError, ValueError):
        font = None
    return font or DEFAULT_MONO


def jsonc_skip(text, index):
    """The index past any whitespace and comments at `index`."""
    while index < len(text):
        if text[index].isspace():
            index += 1
        elif text.startswith("//", index):
            newline = text.find("\n", index)
            index = len(text) if newline < 0 else newline
        elif text.startswith("/*", index):
            close = text.find("*/", index + 2)
            index = len(text) if close < 0 else close + 2
        else:
            break
    return index


def jsonc_string_end(text, index):
    """The index past the string whose opening quote is at `index`."""
    index += 1
    while index < len(text):
        if text[index] == "\\":
            index += 2
            continue
        if text[index] == '"':
            return index + 1
        index += 1
    return len(text)


def jsonc_value_end(text, index):
    """The index past the value that starts at `index`."""
    if text[index] == '"':
        return jsonc_string_end(text, index)
    if text[index] in "[{":
        depth = 0
        while index < len(text):
            char = text[index]
            if char == '"':
                index = jsonc_string_end(text, index)
                continue
            if text.startswith(("//", "/*"), index):
                index = jsonc_skip(text, index)
                continue
            if char in "[{":
                depth += 1
            elif char in "]}":
                depth -= 1
                if depth == 0:
                    return index + 1
            index += 1
        return len(text)
    end = index
    while (end < len(text) and text[end] not in ",}\n"
           and not text.startswith(("//", "/*"), end)):
        end += 1
    while end > index and text[end - 1].isspace():
        end -= 1
    return end


def jsonc_members(text):
    """{key: (start, end)} for the values of a JSONC object's top-level keys.

    Comments are skipped rather than removed, so a value can be replaced in
    place and everything around it kept. None when the text is not an
    object this can read.
    """
    index = jsonc_skip(text, 0)
    if index >= len(text) or text[index] != "{":
        return None
    members = {}
    index += 1
    while True:
        index = jsonc_skip(text, index)
        if index >= len(text):
            return None
        if text[index] == "}":
            return members
        if text[index] == ",":
            index += 1
            continue
        if text[index] != '"':
            return None
        end = jsonc_string_end(text, index)
        try:
            key = json.loads(text[index:end])
        except ValueError:
            return None
        index = jsonc_skip(text, end)
        if index >= len(text) or text[index] != ":":
            return None
        index = jsonc_skip(text, index + 1)
        if index >= len(text):
            return None
        end = jsonc_value_end(text, index)
        members[key] = (index, end)
        index = end


def update_vscodium_settings(values):
    """Rewrite, in place, the values of those keys already in settings.json.

    Nothing is added and nothing else changes, comments included, so a key
    removed by hand stays removed. VSCodium does not write the file back as
    it exits, so the editor may be open.
    """
    try:
        with open(VSCODIUM_SETTINGS_FILE, encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return
    members = jsonc_members(text)
    if not members:
        return

    edits = []
    for key, value in values.items():
        if key not in members:
            continue
        start, end = members[key]
        try:
            if json.loads(strip_jsonc(text[start:end])) == value:
                continue
        except ValueError:
            pass
        edits.append((start, end, json.dumps(value, ensure_ascii=False)))
    if not edits:
        return

    for start, end, value in sorted(edits, reverse=True):
        text = text[:start] + value + text[end:]
    temporary = VSCODIUM_SETTINGS_FILE + ".impasto"
    try:
        with open(temporary, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.replace(temporary, VSCODIUM_SETTINGS_FILE)
    except OSError as error:
        sys.stderr.write(f"Cannot update VSCodium's settings: {error}\n")


def vscodium_font_settings(families):
    """The settings.json keys that follow the shell's monospace family."""
    font = quoted_families(families)
    return {
        "editor.fontFamily": font,
        "terminal.integrated.fontFamily": font,
        "debug.console.fontFamily": font,
    }


def vscodium_palette_settings(colors):
    """The settings.json keys that follow the palette: extension options
    with no theme colour to carry them."""
    accent = colors.get("accent", "#0a84ff")
    ground = gtk_ground(colors.get("background", "#1e1e1e"), accent)

    def on(key):
        return lift(colors.get(key, accent), MIN_CONTRAST, ground)

    # Indent guides use the bracket-pair colour order, at VSCODIUM_GUIDE alpha.
    guides = [on(key) + VSCODIUM_GUIDE
              for key in ("accent", "yellow", "blue", "green", "accentHover")]
    return {
        # Folder icons follow the accent.
        "material-icon-theme.folders.color": accent,
        "indentRainbow.colors": guides,
        "indentRainbow.errorColor": on("red") + VSCODIUM_GUIDE,
    }


def build_vscodium_settings(colors):
    """The settings.json keys this repository manages.

    Only what cannot go in the theme: fonts, layout and extension options.
    Merged by `./setup vscodium`; the pushes keep its font and palette keys
    current after that.
    """
    return {
        # ── theme and icons ──
        "workbench.colorTheme": VSCODIUM_LABEL,
        "workbench.iconTheme": "material-icon-theme",
        "workbench.productIconTheme": "fluent-icons",

        # ── type ──
        **vscodium_font_settings(shell_font()),
        "editor.fontLigatures": True,
        "editor.fontSize": 14,
        "editor.lineHeight": 1.6,
        "terminal.integrated.fontSize": 13,
        "scm.inputFontFamily": "editor",

        # ── window layout ──
        # Activity bar along the top instead of down the left, which frees a
        # 48px column.
        "workbench.activityBar.location": "top",
        "window.menuBarVisibility": "compact",
        "window.commandCenter": False,
        "workbench.layoutControl.enabled": False,
        "chat.commandCenter.enabled": False,
        "breadcrumbs.enabled": False,
        "editor.minimap.enabled": False,
        "workbench.startupEditor": "none",
        "explorer.compactFolders": False,
        "workbench.tree.indent": 14,
        "editor.padding.top": 16,
        "editor.padding.bottom": 16,

        # ── rendering ──
        "editor.cursorBlinking": "smooth",
        "editor.cursorSmoothCaretAnimation": "on",
        "editor.smoothScrolling": True,
        "workbench.list.smoothScrolling": True,
        "terminal.integrated.smoothScrolling": True,
        "editor.stickyScroll.enabled": True,
        "editor.bracketPairColorization.enabled": True,
        "editor.guides.bracketPairs": "active",
        # "trailing" rather than "boundary": with 4-space indents, boundary
        # draws dots before every line, on top of the indent guides.
        "editor.renderWhitespace": "trailing",
        "editor.renderLineHighlight": "all",
        "editor.linkedEditing": True,
        "editor.overviewRulerBorder": False,

        # ── extensions ──
        # Error Lens: band behind the message only, not the whole line.
        "errorLens.messageBackgroundMode": "message",
        "errorLens.fontStyleItalic": True,
        "errorLens.gutterIconsEnabled": False,
        "indentRainbow.indicatorStyle": "light",
        "indentRainbow.lightIndicatorStyleLineWidth": 1,
        **vscodium_palette_settings(colors),
    }


def write_vscodium_settings(colors):
    """Merge those keys into VSCodium's settings.json, keeping the rest.

    Comments in the file are lost, which is why this runs on demand rather
    than on every push. Written via a temporary file and a rename. A file that
    cannot be parsed is left untouched.
    """
    if not shutil.which("codium"):
        sys.stderr.write("codium is not installed; its settings are not written\n")
        return False

    settings = {}
    if os.path.exists(VSCODIUM_SETTINGS_FILE):
        try:
            with open(VSCODIUM_SETTINGS_FILE, encoding="utf-8") as handle:
                raw = handle.read()
            settings = json.loads(strip_jsonc(raw)) if raw.strip() else {}
        except (OSError, ValueError) as error:
            sys.stderr.write(f"Cannot read VSCodium's settings, so they are "
                             f"left alone: {error}\n")
            return False
        if not isinstance(settings, dict):
            sys.stderr.write("VSCodium's settings are not an object, so they "
                             "are left alone\n")
            return False

    settings.update(build_vscodium_settings(colors))
    temporary = VSCODIUM_SETTINGS_FILE + ".impasto"
    try:
        os.makedirs(os.path.dirname(VSCODIUM_SETTINGS_FILE), exist_ok=True)
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump(settings, handle, indent=4, ensure_ascii=False)
            handle.write("\n")
        os.replace(temporary, VSCODIUM_SETTINGS_FILE)
    except OSError as error:
        sys.stderr.write(f"Cannot write VSCodium's settings: {error}\n")
        return False
    return True


# ── THUNAR ──────────────────────────────────────────────────────────────────
#
# Thunar's colours come from gtk.css; this is everything else, applied by
# `./setup thunar` with Thunar closed. Thunar keeps its settings in xfconf
# (the XML under ~/.config/xfce4/ is xfconfd's cache and gets rewritten), and
# it rewrites uca.xml when its custom-actions dialog is used, so neither can
# be a file in home/.
THUNAR_CHANNEL = "thunar"
THUNAR_CONFIG_DIR = os.path.join(XDG_CONFIG_HOME, "Thunar")
THUNAR_ACTIONS_FILE = os.path.join(THUNAR_CONFIG_DIR, "uca.xml")

# Toolbar items in order. The menu bar is hidden, so the menu button is shown.
# Every item must be listed, shown or not: Thunar appends missing ones at the
# end.
THUNAR_TOOLBAR = (
    "back:1", "forward:1", "open-parent:1", "open-home:1",
    "location-bar:1", "reload:1", "search:1",
    "view-switcher:1", "toggle-split-view:1", "menu:1",
    "new-tab:0", "new-window:0", "undo:0", "redo:0",
    "zoom-out:0", "zoom-in:0", "zoom-reset:0",
    "view-as-icons:0", "view-as-detailed-list:0", "view-as-compact-list:0",
)

# (property, type, value) for `xfconf-query --create`. Only preferences: state
# Thunar remembers (window size, sort column, pane position) is left alone.
THUNAR_SETTINGS = (
    # · toolbar: one bar, with the menu behind its menu button
    ("/last-menubar-visible", "bool", "false"),
    ("/last-statusbar-visible", "bool", "true"),
    ("/last-toolbar-visible-buttons", "string", ",".join(THUNAR_TOOLBAR)),
    ("/misc-small-toolbar-icons", "bool", "false"),
    # No client-side decorations: Hyprland has no title bar to replace, and
    # the CSD shadow margin would count towards the window's size.
    ("/misc-use-csd", "bool", "false"),

    # · display
    ("/misc-thumbnail-mode", "string", "THUNAR_THUMBNAIL_MODE_ONLY_LOCAL"),
    ("/misc-thumbnail-draw-frames", "bool", "false"),
    ("/misc-folders-first", "bool", "true"),
    ("/misc-case-sensitive", "bool", "false"),
    ("/misc-expandable-folders", "bool", "true"),
    ("/misc-folder-item-count", "string", "THUNAR_FOLDER_ITEM_COUNT_ONLY_LOCAL"),
    ("/misc-file_size_binary", "bool", "true"),
    ("/misc-date-style", "string", "THUNAR_DATE_STYLE_CUSTOM"),
    ("/misc-date-custom-style", "string", "%Y-%m-%d %H:%M"),
    ("/misc-highlighting-enabled", "bool", "true"),
    ("/misc-image-preview-mode", "string", "THUNAR_IMAGE_PREVIEW_MODE_EMBEDDED"),
    ("/misc-image-size-in-statusbar", "bool", "true"),
    ("/shortcuts-icon-emblems", "bool", "true"),

    # · behaviour
    ("/misc-single-click", "bool", "false"),
    ("/misc-middle-click-in-tab", "bool", "true"),
    ("/misc-switch-to-new-tab", "bool", "true"),
    ("/misc-tab-close-middle-click", "bool", "true"),
    ("/misc-always-show-tabs", "bool", "false"),
    ("/misc-vertical-split-pane", "bool", "false"),
    ("/misc-open-new-windows-in-split-view", "bool", "false"),
    ("/misc-recursive-search", "string", "THUNAR_RECURSIVE_SEARCH_LOCAL"),
    ("/misc-ctrl-scroll-wheel-to-zoom", "bool", "true"),
    ("/misc-horizontal-wheel-navigates", "bool", "true"),
    ("/misc-window-title-style", "string",
     "THUNAR_WINDOW_TITLE_STYLE_FOLDER_NAME_WITHOUT_THUNAR_SUFFIX"),
    ("/misc-full-path-in-tab-title", "bool", "false"),
    ("/misc-remember-geometry", "bool", "true"),
    ("/misc-volume-management", "bool", "true"),
    ("/misc-undo-redo-history-size", "int", "25"),

    # · deleting: offer Shift+Delete, keep the trash confirmation, and open
    #   shell scripts in an editor instead of running them on double-click
    ("/misc-show-delete-action", "bool", "true"),
    ("/misc-confirm-move-to-trash", "bool", "true"),
    ("/misc-exec-shell-scripts-by-default", "bool", "false"),

    # · copying: partial files and verification only for remote transfers
    ("/misc-parallel-copy-mode", "string",
     "THUNAR_PARALLEL_COPY_MODE_ONLY_LOCAL_SAME_DEVICES"),
    ("/misc-transfer-use-partial", "string", "THUNAR_USE_PARTIAL_MODE_REMOTE"),
    ("/misc-transfer-verify-file", "string", "THUNAR_VERIFY_FILE_MODE_REMOTE"),
)

# Right-click actions, each using a program from this repository. %f is one
# path and %F all the selected ones; Thunar quotes them, so they are not
# quoted here, and shell commands take the path as an argument.
THUNAR_ACTIONS = (
    ("impasto-terminal", "utilities-terminal", "Open Terminal Here",
     "Open kitty in this folder",
     "kitty --working-directory %f", ("directories",)),
    ("impasto-yazi", "folder-open", "Open yazi Here",
     "Open this folder in yazi",
     "kitty --working-directory %f yazi", ("directories",)),
    ("impasto-editor", "accessories-text-editor", "Open in the Editor",
     "Open in VSCodium",
     "codium %F", ("directories", "text-files", "other-files")),
    ("impasto-wallpaper", "preferences-desktop-wallpaper", "Set as Wallpaper",
     "Use this picture as the wallpaper and theme the desktop from it",
     "qs ipc call wallpaper set %f", ("image-files",)),
    ("impasto-copy-path", "edit-copy", "Copy Path",
     "Copy the full path of the selection to the clipboard",
     "sh -c 'printf %s \"$1\" | wl-copy' impasto %f",
     ("directories", "audio-files", "image-files", "other-files",
      "text-files", "video-files")),
)


def build_thunar_actions():
    """Thunar's uca.xml, written whole, replacing whatever is there."""
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             "<!-- Written by theme_manager.py, from `./setup thunar`. -->",
             "<!-- Anything added here by hand is lost on the next one. -->",
             "<actions>"]
    for unique, icon, name, description, command, kinds in THUNAR_ACTIONS:
        lines += ["<action>",
                  f"\t<icon>{icon}</icon>",
                  f"\t<name>{escape(name)}</name>",
                  "\t<submenu></submenu>",
                  f"\t<unique-id>{unique}</unique-id>",
                  f"\t<command>{escape(command)}</command>",
                  f"\t<description>{escape(description)}</description>",
                  "\t<range></range>",
                  "\t<patterns>*</patterns>",
                  "\t<startup-notify/>"]
        lines += [f"\t<{kind}/>" for kind in kinds]
        lines.append("</action>")
    lines += ["</actions>", ""]
    return "\n".join(lines)


def apply_thunar():
    """Apply Thunar's settings and custom actions. Returns success.

    A property xfconf refuses is reported and skipped, so older Thunar
    versions still get the ones they know.
    """
    if not shutil.which("thunar"):
        sys.stderr.write("thunar is not installed\n")
        return False
    if not shutil.which("xfconf-query"):
        sys.stderr.write("xfconf-query is not installed: Thunar keeps its "
                         "settings in xfconf and there is no file to write\n")
        return False

    try:
        os.makedirs(THUNAR_CONFIG_DIR, exist_ok=True)
        with open(THUNAR_ACTIONS_FILE, "w", encoding="utf-8") as handle:
            handle.write(build_thunar_actions())
    except OSError as error:
        sys.stderr.write(f"Cannot write {THUNAR_ACTIONS_FILE}: {error}\n")
        return False

    refused = 0
    for prop, kind, value in THUNAR_SETTINGS:
        command = ["xfconf-query", "--channel", THUNAR_CHANNEL,
                   "--property", prop, "--create", "--type", kind,
                   "--set", value]
        try:
            result = subprocess.run(command, capture_output=True, text=True,
                                    timeout=10)
        except (OSError, subprocess.SubprocessError) as error:
            sys.stderr.write(f"{prop}: {error}\n")
            refused += 1
            continue
        if result.returncode != 0:
            sys.stderr.write(f"{prop}: {result.stderr.strip()}\n")
            refused += 1

    if refused:
        sys.stderr.write(f"{refused} of {len(THUNAR_SETTINGS)} settings were "
                         f"refused\n")
    return refused == 0


# ── BROWSER ─────────────────────────────────────────────────────────────────

# Zen is Firefox-based and reads a user stylesheet over its chrome. The
# profile lives under $XDG_CONFIG_HOME/zen and its directory name has a random
# prefix, so the push locates it and writes the files there.
ZEN_PROFILE_ROOT = os.path.join(XDG_CONFIG_HOME, "zen")
ZEN_PROFILES_FILE = os.path.join(ZEN_PROFILE_ROOT, "profiles.ini")
ZEN_INSTALLS_FILE = os.path.join(ZEN_PROFILE_ROOT, "installs.ini")

# Firefox's user stylesheet. Zen's own zen-themes.css in the same directory is
# left alone.
ZEN_CHROME_DIR = "chrome"
ZEN_CHROME_FILE = "userChrome.css"

# Firefox ignores userChrome.css unless this preference is true. It goes in
# user.js, which is read at startup and never rewritten; the browser
# overwrites prefs.js on exit.
ZEN_PREFS_FILE = "user.js"
ZEN_PREFS = (
    ("toolkit.legacyUserProfileCustomizations.stylesheets", "true"),
)


def zen_profile():
    """The profile directory the browser actually opens.

    The install-specific default in installs.ini takes precedence over
    `Default=1` in profiles.ini, as in Firefox. Zen ships an unused "Default
    Profile" next to the real "Default (release)" one, so reading
    profiles.ini alone picks the wrong directory.
    """
    if not os.path.isfile(ZEN_PROFILES_FILE):
        return None

    def read(path):
        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str
        try:
            parser.read(path, encoding="utf-8")
        except (configparser.Error, OSError, UnicodeDecodeError):
            return None
        return parser

    installs = read(ZEN_INSTALLS_FILE)
    if installs:
        for section in installs.sections():
            path = installs.get(section, "Default", fallback="")
            candidate = os.path.join(ZEN_PROFILE_ROOT, path)
            if path and os.path.isdir(candidate):
                return candidate

    profiles = read(ZEN_PROFILES_FILE)
    if not profiles:
        return None

    fallback = None
    for section in profiles.sections():
        path = profiles.get(section, "Path", fallback="")
        if not path:
            continue
        if profiles.get(section, "IsRelative", fallback="1") == "1":
            path = os.path.join(ZEN_PROFILE_ROOT, path)
        if not os.path.isdir(path):
            continue
        if profiles.get(section, "Default", fallback="0") == "1":
            return path
        if fallback is None:
            fallback = path
    return fallback


def build_zen_css(colors):
    """userChrome.css for Zen.

    Zen derives most of its chrome colours with color-mix() from
    --zen-primary-color and the branding background, so only those are set,
    plus the few near-black values Zen hardcodes. Every line is `!important`
    because Zen's built-in themes redeclare these with `!important`. The
    ground matches GTK's.
    """
    accent = colors.get("accent", "#0a84ff")
    ground = gtk_ground(colors.get("background", "#1e1e1e"), accent)
    surface = colors.get("surface", colors.get("background", "#1e1e1e"))
    raised = gtk_ground(surface, accent)
    text = colors.get("text", "#eef2f7")
    border = gtk_ground(colors.get("border", raised), accent)

    return "\n".join([
        "/* GENERATED by scripts/theme_manager.py on every palette change.",
        "   Zen reads this file when a window is built; edits here are lost",
        "   at the next switch. */",
        "",
        ":root {",
        # Force the dark branch of light-dark(); in light mode Zen would mix
        # this ground into white.
        "  color-scheme: dark !important;",
        "",
        "  /* the two the browser derives the rest from */",
        f"  --zen-primary-color: {accent} !important;",
        f"  --zen-branding-dark: {ground} !important;",
        f"  --zen-branding-paper: {ground} !important;",
        f"  --zen-branding-bg: {ground} !important;",
        f"  --zen-branding-bg-reverse: {text} !important;",
        "",
        "  /* and the near-blacks it hardcodes past its own formula */",
        f"  --zen-themed-toolbar-bg-transparent: {raised} !important;",
        f"  --zen-dialog-background: {raised} !important;",
        f"  --zen-in-content-dialog-background: {raised} !important;",
        f"  --zen-urlbar-background: {raised} !important;",
        f"  --zen-colors-border: {border} !important;",
        f"  --zen-input-border-color: {border} !important;",
        "}",
        "",
        # The sidebar and toolbar backgrounds are set by
        # ZenGradientGenerator.mjs as inline styles on these elements, so :root
        # cannot reach them; an author !important rule on the element wins over
        # the inline value.
        "#zen-browser-background {",
        f"  --zen-main-browser-background: {ground} !important;",
        "}",
        "",
        "#zen-toolbar-background {",
        f"  --zen-main-browser-background-toolbar: {raised} !important;",
        "}",
    ]) + "\n"


def build_zen_prefs():
    """user.js, written whole: Firefox never writes to it."""
    lines = [
        "// Written by impasto. github.com/andreumassanet/impasto",
        "// Read at startup and never written back, which is why it is here",
        "// and not in prefs.js.",
        "",
    ]
    lines += [f'user_pref("{name}", {value});' for name, value in ZEN_PREFS]
    return "\n".join(lines) + "\n"


def write_zen_css(colors):
    """Write userChrome.css and user.js into the active Zen profile.

    Zen reads them when a window is created and at startup, so changes apply
    on the next launch.
    """
    if not shutil.which("zen-browser"):
        return
    profile = zen_profile()
    if not profile:
        return
    try:
        chrome = os.path.join(profile, ZEN_CHROME_DIR)
        os.makedirs(chrome, exist_ok=True)
        with open(os.path.join(chrome, ZEN_CHROME_FILE), "w",
                  encoding="utf-8") as handle:
            handle.write(build_zen_css(colors))
        with open(os.path.join(profile, ZEN_PREFS_FILE), "w",
                  encoding="utf-8") as handle:
            handle.write(build_zen_prefs())
    except OSError as error:
        sys.stderr.write(f"Cannot write Zen's chrome: {error}\n")


def push_terminal_font(family):
    """Write the font fragment and make running kitty instances reload config.

    kitty has no remote command for the font, so the whole config is reloaded;
    that re-reads the palette fragment too, which holds the same palette.
    """
    # The setting is a CSS-style font stack for Qt; kitty takes one family.
    first = family.split(",")[0].strip()
    if not first:
        return

    ensure_state_dir()
    with open(TERMINAL_FONT_FILE, "w", encoding="utf-8") as handle:
        handle.write("# Written by theme_manager.py; edits here are lost.\n")
        handle.write("# The shell's monospace family, so the terminal and the\n")
        handle.write("# bar are set in the same face.\n")
        handle.write(f"font_family {first}\n")

    update_vscodium_settings(vscodium_font_settings(family))

    kitten = shutil.which("kitten")
    if not kitten:
        sys.stderr.write("kitten not found; the font applies to new terminals only\n")
        return

    for socket_path in sorted(glob.glob(KITTY_SOCKETS)):
        result = subprocess.run(
            [kitten, "@", "--to", f"unix:{socket_path}", "load-config"],
            capture_output=True, text=True)
        if result.returncode != 0:
            # A stale socket from a closed terminal is normal; keep going.
            sys.stderr.write(f"{os.path.basename(socket_path)}: "
                             f"{result.stderr.strip()}\n")


def saturation(red, green, blue):
    highest = max(red, green, blue)
    return 0 if highest == 0 else (highest - min(red, green, blue)) / highest


def sample_colors(image_path):
    """Quantize the image down to a handful of representative colors."""
    magick = shutil.which("magick") or shutil.which("convert")
    if not magick:
        return []
    command = [magick, image_path, "-resize", "120x120", "-colors", "24", "-unique-colors", "txt:-"]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError) as error:
        sys.stderr.write(f"Color extraction failed: {error}\n")
        return []
    return re.findall(r"#[0-9A-Fa-f]{6}", result.stdout)


def pick_accent(swatches):
    """Prefer a saturated mid-tone; those read as an accent at small sizes."""
    if not swatches:
        return NEUTRAL_ACCENT

    candidates = []
    for value in swatches:
        red, green, blue = hex_to_rgb(value)
        candidates.append({
            "hex": value.upper(),
            "r": red, "g": green, "b": blue,
            "lum": luminance(red, green, blue),
            "sat": saturation(red, green, blue),
        })

    vibrant = [c for c in candidates if c["sat"] > 0.2 and 0.2 < c["lum"] < 0.85]
    if vibrant:
        return max(vibrant, key=lambda c: c["sat"] * 2.0 + (1.0 - abs(c["lum"] - 0.55)))

    colorful = [c for c in candidates if c["sat"] > 0.1]
    return max(colorful, key=lambda c: c["sat"]) if colorful else NEUTRAL_ACCENT


def build_palette(image_path):
    """Derive a full UI palette from the wallpaper's dominant accent."""
    accent = pick_accent(sample_colors(image_path))
    red, green, blue = accent["r"], accent["g"], accent["b"]

    # Surfaces are near-black, tinted just enough to feel related to the accent.
    background = (17 + red * 0.04, 19 + green * 0.04, 24 + blue * 0.05)
    surface = tuple(channel + 14 for channel in background)
    surface_hover = (surface[0] + 16, surface[1] + 16, surface[2] + 18)
    border = (surface_hover[0] + 16, surface_hover[1] + 16, surface_hover[2] + 20)

    return {
        "background": rgb_to_hex(*background),
        "surface": rgb_to_hex(*surface),
        "surfaceHover": rgb_to_hex(*surface_hover),
        "border": rgb_to_hex(*border),
        "text": "#eef2f7",
        "textMuted": "#94a1b2",
        "accent": accent["hex"],
        "accentHover": rgb_to_hex(red * 1.15 + 15, green * 1.15 + 15, blue * 1.15 + 15),
        "accentText": "#11111b" if luminance(red, green, blue) > 0.45 else "#ffffff",
        "red": "#f38ba8",
        "green": "#a6e3a1",
        "yellow": "#f9e2af",
        "blue": "#89b4fa",
    }


def extract_colors(image_path):
    if not image_path or not os.path.isfile(image_path):
        return None
    palette = build_palette(image_path)
    ensure_state_dir()
    try:
        with open(DYNAMIC_COLORS_FILE, "w", encoding="utf-8") as handle:
            json.dump(palette, handle, indent=2)
    except OSError as error:
        sys.stderr.write(f"Cannot save dynamic colors: {error}\n")
    return palette


def link_current_wallpaper(image_path):
    ensure_state_dir()
    try:
        if os.path.islink(CURRENT_WALLPAPER_LINK) or os.path.exists(CURRENT_WALLPAPER_LINK):
            os.remove(CURRENT_WALLPAPER_LINK)
        os.symlink(image_path, CURRENT_WALLPAPER_LINK)
    except OSError as error:
        sys.stderr.write(f"Cannot update the current-wallpaper link: {error}\n")


# awww transition types accepted from the shell; anything else becomes a wipe.
WALLPAPER_TRANSITIONS = ("none", "simple", "fade", "left", "right", "top", "bottom",
                         "wipe", "wave", "grow", "center", "any", "outer")


def set_wallpaper(image_path, transition="wipe"):
    if not os.path.isfile(image_path):
        sys.stderr.write(f"Wallpaper not found: {image_path}\n")
        return False

    if shutil.which("awww"):
        if transition not in WALLPAPER_TRANSITIONS:
            transition = "wipe"
        command = ["awww", "img", image_path, "--transition-type", transition,
                   "--transition-duration", "1"]
        try:
            subprocess.run(command, capture_output=True, timeout=15)
        except (OSError, subprocess.SubprocessError) as error:
            sys.stderr.write(f"awww failed: {error}\n")

    state = load_state()
    state["currentWallpaper"] = image_path
    save_state(state)
    link_current_wallpaper(image_path)
    extract_colors(image_path)
    return True


def restore_wallpaper():
    """Re-apply the saved wallpaper to any output that is showing nothing.

    awww's cache stores the resolved image path, which breaks if the file
    moves; the shell's state points at the copy in the data directory. Only
    blank outputs are painted (a monitor connected later, for example), so a
    shell restart does not repaint screens that are already right.

    Exit codes: 0 done or nothing to do, 3 the daemon is not answering yet
    (the caller retries; at login this races awww-daemon's startup).
    """
    if not shutil.which("awww"):
        return 0
    try:
        result = subprocess.run(["awww", "query"],
                                capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return 3
    if result.returncode != 0:
        return 3

    # ": eDP-1: 1920x1200, scale: 1, currently displaying: image: /path"
    blank = []
    for line in result.stdout.splitlines():
        found = re.match(r"\s*:\s*([^:]+):", line)
        if found and not re.search(r"image:\s*/", line):
            blank.append(found.group(1).strip())
    if not blank:
        return 0

    current = get_current_wallpaper()
    if not current:
        return 0
    try:
        subprocess.run(["awww", "img", current, "--transition-type", "none",
                        "--outputs", ",".join(blank)],
                       capture_output=True, timeout=15)
    except (OSError, subprocess.SubprocessError) as error:
        sys.stderr.write(f"awww failed: {error}\n")
        return 1
    return 0


def set_theme(theme_id):
    state = load_state()
    state["activeTheme"] = theme_id
    save_state(state)


def main():
    actions = ("list-wallpapers | get-current | get-state | set-wallpaper <path> [transition] | "
               "restore | extract-colors [path] | set-theme <id> | "
               "push-terminal-palette <json> | push-terminal-font <family> | "
               "apply-vscodium [json] | apply-thunar | apply-vesktop")
    if len(sys.argv) < 2:
        sys.stderr.write(f"Usage: theme_manager.py {actions}\n")
        sys.exit(1)

    action = sys.argv[1]
    argument = sys.argv[2] if len(sys.argv) >= 3 else None

    if action == "list-wallpapers":
        print(json.dumps(list_wallpapers()))
    elif action == "get-current":
        print(get_current_wallpaper())
    elif action == "get-state":
        state = load_state()
        state["currentWallpaper"] = get_current_wallpaper()
        print(json.dumps(state))
    elif action == "extract-colors":
        print(json.dumps(extract_colors(argument or get_current_wallpaper())))
    elif action == "set-wallpaper" and argument:
        transition = sys.argv[3] if len(sys.argv) >= 4 else "wipe"
        sys.exit(0 if set_wallpaper(argument, transition) else 1)
    elif action == "restore":
        sys.exit(restore_wallpaper())
    elif action == "set-theme" and argument:
        set_theme(argument)
    elif action == "push-terminal-palette" and argument:
        colors = json.loads(argument)
        push_terminal_palette(colors)
        write_greetings(colors)
        write_btop_theme(colors)
        write_cava_theme(colors)
        write_yazi_flavor(colors)
        push_nvim_colorscheme(colors)
        write_imv_config(colors)
        write_gtk_theme(colors)
        write_icon_theme(colors)
        write_qt_theme(colors)
        write_vesktop_css(colors)
        write_spicetify_colors(colors)
        write_vscodium_theme(colors)
        update_vscodium_settings(vscodium_palette_settings(colors))
        write_zen_css(colors)
        refresh_spotify()
    elif action == "push-terminal-font" and argument:
        push_terminal_font(argument)
    elif action == "apply-vscodium":
        colors = json.loads(argument) if argument else (
            extract_colors(get_current_wallpaper()) or {})
        sys.exit(0 if write_vscodium_settings(colors) else 1)
    elif action == "apply-thunar":
        sys.exit(0 if apply_thunar() else 1)
    elif action == "apply-vesktop":
        sys.exit(0 if tick_vesktop_theme() else 1)
    else:
        sys.stderr.write(f"Unknown action: {action}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
