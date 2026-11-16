"""Tests for the tmux theme `theme_manager.py` writes.

Run from the repository root:  python3 -m unittest discover -s tests -v

Everything runs against a scratch XDG tree set before the module is imported
(its paths are fixed at import), and tmux is a stub script on a private PATH.
Nothing under the real home is read or written.
"""

import atexit
import json
import os
import re
import shutil
import stat
import sys
import tempfile
import unittest
from unittest import mock

SCRATCH = tempfile.mkdtemp(prefix="impasto-tmux-test-")
atexit.register(shutil.rmtree, SCRATCH, ignore_errors=True)
for variable, folder in (("XDG_STATE_HOME", "state"), ("XDG_CONFIG_HOME", "config"),
                         ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache")):
    os.environ[variable] = os.path.join(SCRATCH, folder)
os.environ["HOME"] = SCRATCH

SCRIPTS = os.path.join(os.path.dirname(__file__), "..", "home", ".config",
                       "quickshell", "scripts")
sys.path.insert(0, os.path.abspath(SCRIPTS))
import theme_manager  # noqa: E402

# Catppuccin Mocha (dark) and Latte (light), as theme/Palettes.qml has them.
MOCHA = {
    "background": "#1e1e2e", "surface": "#181825", "surfaceHover": "#313244",
    "border": "#45475a", "text": "#cdd6f4", "textMuted": "#a6adc8",
    "accent": "#89b4fa", "accentHover": "#b4befe", "accentText": "#11111b",
    "red": "#f38ba8", "green": "#a6e3a1", "yellow": "#f9e2af", "blue": "#89b4fa",
}
LATTE = {
    "background": "#eff1f5", "surface": "#e6e9ef", "surfaceHover": "#ccd0da",
    "border": "#bcc0cc", "text": "#4c4f69", "textMuted": "#6c6f85",
    "accent": "#1e66f5", "accentHover": "#04a5e5", "accentText": "#eff1f5",
    "red": "#d20f39", "green": "#40a02b", "yellow": "#df8e1d", "blue": "#1e66f5",
}

EXPECTED_OPTIONS = (
    "status-style", "status-right-style", "window-status-style",
    "window-status-current-style", "window-status-bell-style",
    "pane-border-style", "pane-active-border-style", "message-style",
    "mode-style",
)
HEX = re.compile(r"#[0-9a-f]{6}")


def parse_options(text):
    """{option: value} for every set/setw line of a generated file."""
    options = {}
    for line in text.splitlines():
        match = re.fullmatch(r'(?:set|setw) -g (\S+) "([^"]*)"', line)
        if match:
            options[match.group(1)] = match.group(2)
    return options


def style_colour(value, part):
    """The colour of `fg=` or `bg=` in a tmux style string."""
    return re.search(rf"{part}=(#[0-9a-f]{{6}})", value).group(1)


class BuildTmuxTheme(unittest.TestCase):
    def test_every_option_is_set_once_with_hex_colours(self):
        for palette in (MOCHA, LATTE):
            text = theme_manager.build_tmux_theme(palette)
            options = parse_options(text)
            self.assertEqual(set(options), set(EXPECTED_OPTIONS) | {"clock-mode-colour"})
            for name, value in options.items():
                for colour in re.findall(r"#\w+", value):
                    self.assertRegex(colour, HEX, f"{name} in {palette['background']}")
            # Each option appears on exactly one line.
            for name in options:
                self.assertEqual(len(re.findall(rf" {re.escape(name)} ", text)), 1)

    def test_clock_mode_colour_is_a_window_option(self):
        text = theme_manager.build_tmux_theme(MOCHA)
        self.assertRegex(text, r'(?m)^setw -g clock-mode-colour "#[0-9a-f]{6}"$')
        self.assertNotRegex(text, r'(?m)^set -g clock-mode-colour')

    def test_header_says_generated_and_edits_are_lost(self):
        text = theme_manager.build_tmux_theme(MOCHA)
        header = text.split("\n\n")[0]
        self.assertTrue(all(line.startswith("#") for line in header.splitlines()))
        self.assertIn("GENERATED", header)
        self.assertIn("edits here", header)
        self.assertIn("lost", header)

    def test_the_accent_marks_the_active_window_and_pane(self):
        options = parse_options(theme_manager.build_tmux_theme(MOCHA))
        current = options["window-status-current-style"]
        self.assertEqual(style_colour(current, "bg"), MOCHA["accent"])
        self.assertEqual(style_colour(current, "fg"), MOCHA["accentText"])
        self.assertTrue(current.endswith(",bold"))
        self.assertEqual(style_colour(options["mode-style"], "bg"), MOCHA["accent"])
        self.assertEqual(style_colour(options["message-style"], "bg"), MOCHA["accentHover"])

    def test_type_meets_the_contrast_floor_on_its_ground(self):
        for palette in (MOCHA, LATTE):
            options = parse_options(theme_manager.build_tmux_theme(palette))
            for name in ("status-style", "status-right-style", "window-status-style",
                         "window-status-bell-style", "message-style"):
                value = options[name]
                ground = style_colour(value, "bg")
                contrast = theme_manager.contrast_on_terminal(
                    style_colour(value, "fg"), ground)
                self.assertGreaterEqual(contrast, theme_manager.MIN_CONTRAST - 0.01,
                                        f"{name} in {palette['background']}")

    def test_the_bell_is_red_family(self):
        options = parse_options(theme_manager.build_tmux_theme(MOCHA))
        red, green, blue = theme_manager.hex_to_rgb(
            style_colour(options["window-status-bell-style"], "fg"))
        self.assertGreater(red, green)
        self.assertGreater(red, blue)


class TmuxStub:
    """A `tmux` script on its own PATH that logs its arguments.

    `info_status` and `source_status` are the exit codes of those commands.
    """

    def __init__(self, directory, info_status=0, source_status=0):
        self.log = os.path.join(directory, "calls.log")
        script = os.path.join(directory, "tmux")
        with open(script, "w", encoding="utf-8") as handle:
            handle.write(
                "#!/bin/sh\n"
                f'echo "$*" >> "{self.log}"\n'
                'case "$1" in\n'
                f"  info) exit {info_status} ;;\n"
                f"  source-file) echo 'boom' >&2; exit {source_status} ;;\n"
                "esac\n")
        os.chmod(script, os.stat(script).st_mode | stat.S_IXUSR)

    def calls(self):
        if not os.path.exists(self.log):
            return []
        with open(self.log, encoding="utf-8") as handle:
            return handle.read().splitlines()


class WriteTmuxTheme(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.mkdtemp(prefix="stub-", dir=SCRATCH)
        if os.path.exists(theme_manager.TMUX_THEME_FILE):
            os.remove(theme_manager.TMUX_THEME_FILE)

    def run_writer(self, **stub_options):
        stub = TmuxStub(self.directory, **stub_options)
        with mock.patch.dict(os.environ, {"PATH": self.directory}):
            theme_manager.write_tmux_theme(MOCHA)
        return stub

    def test_file_lands_in_the_state_directory_next_to_the_kitty_ones(self):
        self.run_writer()
        self.assertEqual(os.path.dirname(theme_manager.TMUX_THEME_FILE),
                         os.path.dirname(theme_manager.TERMINAL_PALETTE_FILE))
        self.assertTrue(theme_manager.TMUX_THEME_FILE.startswith(SCRATCH))
        with open(theme_manager.TMUX_THEME_FILE, encoding="utf-8") as handle:
            self.assertEqual(handle.read(), theme_manager.build_tmux_theme(MOCHA))
        # The temporary the rename came from is gone.
        self.assertFalse(os.path.exists(theme_manager.TMUX_THEME_FILE + ".impasto"))

    def test_a_running_server_is_told_to_read_the_file(self):
        stub = self.run_writer()
        self.assertEqual(stub.calls(),
                         ["info", f"source-file {theme_manager.TMUX_THEME_FILE}"])

    def test_no_server_means_no_source_file(self):
        stub = self.run_writer(info_status=1)
        self.assertEqual(stub.calls(), ["info"])
        self.assertTrue(os.path.exists(theme_manager.TMUX_THEME_FILE))

    def test_a_failing_source_file_does_not_raise(self):
        stub = self.run_writer(source_status=1)
        self.assertEqual(len(stub.calls()), 2)
        self.assertTrue(os.path.exists(theme_manager.TMUX_THEME_FILE))

    def test_without_tmux_the_file_is_still_written(self):
        with mock.patch.dict(os.environ, {"PATH": self.directory}):
            theme_manager.write_tmux_theme(MOCHA)
        self.assertTrue(os.path.exists(theme_manager.TMUX_THEME_FILE))

    def test_an_unwritable_state_directory_does_not_raise(self):
        with mock.patch.object(theme_manager, "ensure_state_dir",
                               side_effect=PermissionError("nope")):
            theme_manager.write_tmux_theme(MOCHA)
        self.assertFalse(os.path.exists(theme_manager.TMUX_THEME_FILE))


class TmuxTargetGating(unittest.TestCase):
    def setUp(self):
        theme_manager.ensure_state_dir()
        self.stub_directory = tempfile.mkdtemp(prefix="stub-", dir=SCRATCH)
        TmuxStub(self.stub_directory, info_status=1)
        for path in (theme_manager.TMUX_THEME_FILE, theme_manager.SHELL_SETTINGS_FILE):
            if os.path.exists(path):
                os.remove(path)

    def push(self, settings):
        if settings is not None:
            with open(theme_manager.SHELL_SETTINGS_FILE, "w", encoding="utf-8") as handle:
                json.dump(settings, handle)
        with mock.patch.dict(os.environ, {"PATH": self.stub_directory}), \
                mock.patch.object(theme_manager, "PALETTE_WRITERS",
                                  (("tmux", theme_manager.write_tmux_theme),)):
            theme_manager.push_palette(MOCHA)
        return os.path.exists(theme_manager.TMUX_THEME_FILE)

    def test_tmux_is_a_registered_target_after_the_terminal(self):
        names = [target for target, _ in theme_manager.PALETTE_WRITERS]
        self.assertIn("tmux", names)
        self.assertEqual(names.index("tmux"), names.index("terminal") + 1)
        self.assertIs(dict(theme_manager.PALETTE_WRITERS)["tmux"],
                      theme_manager.write_tmux_theme)

    def test_on_without_settings(self):
        self.assertTrue(self.push(None))

    def test_on_when_the_list_is_null(self):
        self.assertTrue(self.push({"themeTargets": None}))

    def test_on_when_the_list_names_it(self):
        self.assertTrue(self.push({"themeTargets": ["terminal", "tmux"]}))

    def test_off_when_the_list_leaves_it_out(self):
        self.assertFalse(self.push({"themeTargets": ["terminal", "btop"]}))

    def test_off_for_an_empty_list(self):
        self.assertFalse(self.push({"themeTargets": []}))


if __name__ == "__main__":
    unittest.main()
