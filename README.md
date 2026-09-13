<p align="center">
  <img src=".github/assets/banner.jpg" alt="impasto — the island, become the mark, over a painting of Mount Fuji" width="100%">
</p>

<p align="center">
  <b>A Hyprland shell whose colours come from a painting.</b><br>
  One black island that changes shape, a desk of widgets under the windows,<br>
  and every program around it repainted by whatever wallpaper is up.
</p>

<p align="center">
  <a href="https://github.com/andreumassanet/impasto/actions/workflows/check.yml"><img src="https://github.com/andreumassanet/impasto/actions/workflows/check.yml/badge.svg" alt="check"></a>
  <img src="https://img.shields.io/badge/Arch_Linux-1793d1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch Linux">
  <img src="https://img.shields.io/badge/Hyprland-Lua_config-58e1ff?style=flat-square&logo=hyprland&logoColor=white" alt="Hyprland">
  <img src="https://img.shields.io/badge/Quickshell-0.3-000000?style=flat-square" alt="Quickshell">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-2e509e?style=flat-square" alt="GPL-3.0"></a>
</p>

<p align="center">
  <a href="https://andreumassanet.github.io/impasto-docs/"><b>Documentation</b></a> ·
  <a href="#the-island">The island</a> ·
  <a href="#the-bar">The bar</a> ·
  <a href="#the-launcher-and-the-dock">The launcher</a> ·
  <a href="#the-desktop">The desktop</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#keys">Keys</a>
</p>

<p align="center">
  <img src=".github/assets/hero.jpg" alt="The desk: the island with a track playing, widgets down the right, a note deck on the left edge, a terminal with the lava lamp greeting, and the dock" width="100%">
</p>

The name is the technique the wallpapers are painted in: paint laid on thick
enough to keep the mark of the brush. It is a shell first and a dotfiles
repository second — `home/.config/quickshell` is most of the code, and the rest
of `home/` is the desk around it: the terminal, the prompt, two editors, two
file managers, a browser, a chat client, the login screen. **Change the
wallpaper and all of it follows.**

## The island

<p align="center">
  <img src=".github/assets/island.gif" alt="The island at rest, opening a glance under the pointer, becoming the control centre, then the launcher doing a sum and listing the shell's places, then a notification arriving" width="100%">
</p>

**The island is one object that changes shape.** A black capsule in the middle
of the bar rests on the time and turns into everything else: the glance under
the pointer, the control centre, the launcher, the overview, a notification, a
game — each the size of what is in it, with no title and no close button. What
is running sits either side of the time, and every module on the bar opens into
the island rather than into a popup of its own.

<p align="center">
  <img src=".github/assets/island-details.jpg" alt="Module details in the island: the player, the battery, Claude Code's usage, the processor and memory, the recorder, the Wi-Fi list, the weather, the pet, the volume, the month with task dots, the tasks, a countdown and the GitHub wall" width="100%">
</p>

## The bar

<p align="center">
  <img src=".github/assets/bar-styles.jpg" alt="The same bar in its three styles: grouped round the island, spread to the two edges, and everything inside one capsule" width="100%">
</p>

**Three styles, one layout.** Pieces are dragged out of a catalogue onto a
picture of the bar, then drawn grouped round the island, spread to the edges, or
all inside one capsule. Each shows its symbol or its ring, with its figure
always, never or under the pointer — two settings for the whole bar, and any
piece can have a look of its own.

## The launcher and the dock

<p align="center">
  <img src=".github/assets/launcher-and-dock.jpg" alt="The launcher listing applications ranked by use, the clipboard history with an image drawn in its row, and the dock with the terminal's menu open over its windows" width="100%">
</p>

**The first character says what the field is for.** Plain text searches
applications, `=` calculates, `@` finds an open window, `!` starts a countdown,
`'` is the clipboard history, and `>` is the shell itself — every panel and
setting by name. Applications are ranked by what you actually launch.

**The dock holds what you pinned, then whatever else is open**, and the same
pins come first in the launcher. Right-click an icon for its windows by name.

## The desktop

<p align="center">
  <img src=".github/assets/desktop-themes.jpg" alt="The same wall of widgets split down the middle: Modern on the left, figures with captions; Analogue on the right, a thermometer, a wall calendar, a battery cell, a knob, gauges, a parcel, a joystick" width="100%">
</p>

**Any module can live on the wallpaper**, on a grid, in four shapes: a square,
a card, a large square and a band. Right-click the wallpaper to arrange — a tray
of every module slides up, a corner is pulled for another shape, and a click
opens that widget's own look — for a photo widget, the picture of your own it
holds.

**Two themes on the same modules**: *Modern* is a figure with a caption,
*Analogue* draws each one as an object, and either is a choice per widget.

<p align="center">
  <img src=".github/assets/repaint.gif" alt="The wallpaper changing three times, and the bar, the widgets, the terminal and the system monitor repainting with each one" width="100%">
</p>

**The palette comes out of the painting.** Pick a wallpaper and its colours
reach everything at once: the island and the widgets, the terminal and the
prompt, btop, cava, yazi, neovim, VSCodium, the GTK, Qt and KDE windows, Thunar
down to its folders, Vesktop, Zen and Spotify. Or pick one of nine palettes
instead. The desk comes with forty paintings, in the style it is named after.

In the terminal, the prompt is laid out like the bar, and `fa` greets you with
fastfetch beside an animated scene drawn in pixel art out of the palette.

## Notes and tasks

<p align="center">
  <img src=".github/assets/notes-and-tasks.jpg" alt="The deck of pastel notes in handwriting, one note open with the island become yellow paper, the kanban board with three lanes, and a task open with its day and lane" width="100%">
</p>

**A note is paper**: a pastel square with a title and the body in handwriting.
`SUPER + S` opens the deck; on the wallpaper a note sits on a square, or stacks
with others along an edge as tabs that peek out under the pointer.

**A board for what has to be done.** `SUPER + K` is to do, doing, done, with
cards dragged between the lanes, and a task's day shows as a dot under the
month wherever a month is drawn.

## Games and pets

<p align="center">
  <img src=".github/assets/games-and-pets.jpg" alt="Tetris and Flood Colors played in the island, and the pets' page with Pip out and the rest of the family waiting" width="100%">
</p>

**Eleven small games, played in the island** — `SUPER + G` opens a shelf, and
the island becomes the board. **A family of five small creatures lives on the
bar**: one out at a time, earning levels from being fed and played with, each
hatched from an egg. Nothing dies, and a week away costs nothing.

## Lock and login

<p align="center">
  <img src=".github/assets/lock-and-login.jpg" alt="The lock screen over the blurred desk, and the SDDM login screen over a painting of brush strokes — the same clock, the same face, the same field" width="100%">
</p>

**The shell locks the session itself**, over the blurred desk, and the login
screen is the same lock with the desk taken away: an SDDM theme with the same
clock, the same face and the same field.

## Settings

<p align="center">
  <img src=".github/assets/settings.jpg" alt="Two pages of the settings window: the bar arranged on a picture of it, and the appearance with the wallpaper transitions and the greeting scenes" width="100%">
</p>

**Settings is the one panel that is not the island** — an ordinary window where
each option is drawn as the thing it changes, and profiles keep whole desks
under names: *Moon castle*, *Fuji* and *Night bay* come with it.

## Installation

Arch Linux, and Hyprland 0.56 or newer (tested on 0.56.2), configured in Lua.
Run it from a terminal inside the Hyprland session — the plugins are built
against the compositor that is running:

```bash
git clone https://github.com/andreumassanet/impasto.git ~/impasto
cd ~/impasto
./setup install
```

It installs the packages, oh-my-zsh, everything in `home/` into your home and
everything in `system/` into `/`, the two Hyprland plugins and the vector
cursor, and sets up Thunar, VSCodium and Spotify — asking for your password
through sudo for pacman, for the copy into `/`, and to let spicetify patch
Spotify. A program that is open, or a Spotify you have never started, is
skipped with the reason and set up by the next `update`. After that they
follow the wallpaper on their own; Spotify from its next start.

| Flag | |
|---|---|
| `--skip-packages` | install nothing; copy and build only |
| `--skip-system` | leave `/` alone — no login screen, and no password for it |
| `--skip-plugins` | no shake to find, no glass |
| `--aur-helper yay\|paru` | which helper builds the AUR half — built from the AUR if you have neither |
| `--noconfirm` | take the default at every question |
| `-n`, `--dry-run` | say what would happen, and do none of it |

```bash
./setup update       # git pull, then install again — the same flags
./setup uninstall    # remove what it installed, and put back what it moved aside
./setup help         # every verb and flag
```

`update` follows the branch you cloned: `main` moves only when a version is
released, and work in progress lives on `dev`. The version installed is under
Settings → System.

**Nothing is linked: `setup` copies**, and remembers what it wrote. A file of
yours already in the way is moved to `~/.local/state/impasto/backups/` first; a
file you edit afterwards is left alone, with the new version beside it as
`<name>.new`. Editing the repository itself? `./setup sync` copies it onto the
desk, and `./setup sync --watch` keeps doing it on every save.

Every package is listed in `packages/pacman.txt` and `packages/aur.txt`, grouped
by what it is for; an optional one that is missing takes its own control away
rather than failing.

<details>
<summary><b>Components</b></summary>
<br>

| | | |
|---|---|---|
| 🪟 | Compositor | [Hyprland](https://hypr.land) |
| 🖱️ | Shake to find | [hypr-dynamic-cursors](https://github.com/VirtCode/hypr-dynamic-cursors) |
| 🫧 | Glass on the windows | [hyprglass](https://github.com/hyprnux/hyprglass) |
| 🐚 | Desktop shell | [Quickshell](https://quickshell.org) |
| 🖼️ | Wallpaper daemon | [awww](https://github.com/LGFae/swww) |
| 🖥️ | Terminal | [kitty](https://sw.kovidgoyal.net/kitty/) |
| ⌨️ | Interactive shell | [zsh](https://www.zsh.org) · [oh-my-zsh](https://ohmyz.sh) |
| ❯ | Prompt | [starship](https://starship.rs) |
| 🎨 | Greeting | [fastfetch](https://github.com/fastfetch-cli/fastfetch) |
| 📊 | System monitor | [btop](https://github.com/aristocratos/btop) |
| 🎵 | Audio visualiser | [cava](https://github.com/karlstav/cava) |
| 📁 | File manager | [yazi](https://yazi-rs.github.io) |
| 🗂️ | File manager in a window | [Thunar](https://docs.xfce.org/xfce/thunar/start) |
| ✏️ | Editor | [neovim](https://neovim.io) |
| 📝 | Editor in a window | [VSCodium](https://vscodium.com) |
| 🖼️ | Image viewer | [imv](https://sr.ht/~exec64/imv/) |
| 🪄 | Annotator | [satty](https://github.com/gabm/Satty) |
| 💬 | Chat | [Vesktop](https://github.com/Vencord/Vesktop) |
| 🎧 | Player | [Spotify](https://www.spotify.com) · [spicetify](https://spicetify.app) |
| 🌐 | Browser | [Zen](https://zen-browser.app) |
| 🔑 | Login screen | [SDDM](https://github.com/sddm/sddm) |

</details>

<details>
<summary><b>Making the rest of the machine agree</b></summary>
<br>

What opens a file and how GTK applications look are the machine's settings, so
they are commands, run once:

```bash
xdg-mime default imv.desktop image/jpeg image/png image/gif image/webp image/svg+xml
xdg-mime default nvim.desktop text/plain application/json
xdg-mime default thunar.desktop inode/directory
xdg-mime default zen.desktop application/pdf text/html     # or whichever browser you use
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface icon-theme impasto
```

Zen needs nothing, Vesktop takes the palette once it is ticked under Vencord's
themes, and Qt and KDE windows need `qt6ct`.

</details>

<details>
<summary><b>The login screen</b></summary>
<br>

`install` copies the SDDM theme into `/usr/share`. Try it before switching to
it, then set `Current=impasto` under `[Theme]` in `/etc/sddm.conf.d/`:

```bash
sddm-greeter-qt6 --test-mode --theme system/usr/share/sddm/themes/impasto
```

The face on the lock and login screens is
`/var/lib/impasto/faces/<username>.face.icon`, yours to put there.

</details>

## Keys

Every key belongs to a profile: Settings → Keys changes any of them, the
compositor's included, and switching profile switches them all. A few worth
knowing first:

- <kbd>SUPER</kbd> <kbd>Return</kbd> a terminal, <kbd>SUPER</kbd> <kbd>Space</kbd>
  the launcher, <kbd>SUPER</kbd> <kbd>Q</kbd> closes the window
- <kbd>SUPER</kbd> <kbd>1</kbd>…<kbd>0</kbd> a workspace, <kbd>SUPER</kbd>
  <kbd>TAB</kbd> all of them at once
- <kbd>SUPER</kbd> <kbd>X</kbd> the session menu, <kbd>SUPER</kbd> <kbd>L</kbd>
  locks
- <kbd>SUPER</kbd> <kbd>H</kbd> every other key, on the island

## Credits

These are worth your time whether or not you use this repository. No code was
copied from any of them; what carried over from the shells are ideas — one file
per island state, one transient signal for every ephemeral event, input
debounced to one frame, and a capture that photographs the screen and draws the
selection on the photograph.

- [saneAspect](https://www.youtube.com/@saneAspect) — the Hyprland setups on
  YouTube that started all this
- [Tide-island](https://github.com/enhaoswen/Tide-island) — the closest thing to
  a complete dynamic island for Hyprland
- [ChillPill-Shell](https://github.com/LUCKYS1NGHH/ChillPill-Shell) — a dynamic
  pill bar built to stay light without a dedicated GPU
- [k4](https://github.com/k4ditano/k4) — a dynamic island bar with a documented
  plugin API
- [HyprQuickshot](https://github.com/JamDon2/hyprquickshot) and its fork
  [HyprQuickFrame](https://github.com/Ronin-CK/HyprQuickFrame) — a capture
  surface in Quickshell
- [diegoMalagrida/dotfiles](https://github.com/diegoMalagrida/dotfiles) — an
  Arch Linux desk ready to install on a fresh system

Built on [Quickshell](https://quickshell.org) and [Hyprland](https://hypr.land).
The pointer is [Bibata](https://github.com/ful1e5/Bibata_Cursor), repainted;
the folders are [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme),
re-pointed; the type is [Inter](https://rsms.me/inter/) and
[JetBrains Mono](https://www.jetbrains.com/lp/mono/). Six of the nine palettes
are other people's work, carried as they are:
[Catppuccin](https://catppuccin.com) Mocha and Latte,
[Tokyo Night](https://github.com/folke/tokyonight.nvim),
[Gruvbox](https://github.com/morhetz/gruvbox), [Nord](https://www.nordtheme.com)
and [Rosé Pine](https://rosepinetheme.com).

## License

Copyright © 2026 Andreu Massanet — released under the [GNU GPL-3.0](LICENSE).

You may use, study, change and share any of it. If you build on it and pass the
result on, it stays under the GPL and its source stays available. Keep the
header at the top of each file, which carries this repository's address, and a
line of credit back here is the kind thing to do.
