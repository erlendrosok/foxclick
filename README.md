# foxclick

A focus-independent autoclicker for games run inside [gamescope](https://github.com/ValveSoftware/gamescope) on Wayland.

Ordinary Linux autoclickers (xclicker, xdotool loops, ydotool) inject input at a
global level: they click into *whatever* window is focused. On Wayland you can't
tell them "only click that background window", so as soon as you switch to any
other window the clicks land there instead — you can't touch anything else on
the machine while the autoclicker runs.

`foxclick` gets around this by aiming at the **private X display that gamescope
creates for the game**. Clicks go into that nested display and keep going no
matter where your real keyboard and mouse focus is. Park the game on one monitor,
work on the other.

It was written for repetitive hold-to-work actions in
[Foxhole](https://store.steampowered.com/app/505460/Foxhole/) (building, digging,
refining), but nothing in it is Foxhole-specific — it works with any game you
launch through gamescope.

## How it works

```
your session (:0)                      gamescope's nested display (:1)
┌───────────────────┐                  ┌───────────────────────────┐
│ browser / Discord │  ← real input →  │  gamescope compositor     │
│ (focused)         │                  │  └─ Xwayland              │
└───────────────────┘                  │     └─ the game (War.exe) │
                                       └───────────▲───────────────┘
        foxclick ── xdotool --display :1 ──────────┘
        (clicks the game regardless of :0 focus)
```

`gamescope` runs the game against its own embedded Xwayland server on a separate
`$DISPLAY`. `foxclick` finds that display, then uses `xdotool` to send button
events into it on a loop. Because the events are delivered inside the nested
server, they reach the game whether or not the gamescope window is focused on
your desktop.

## Requirements

- A Wayland session. Developed and tested on **KDE Plasma 6 / KWin**. The tool
  itself (`foxclick` + gamescope + xdotool) is compositor-agnostic and should
  work anywhere Xwayland is available; only the **automatic global-shortcut
  registration in `install.sh` is KDE-specific** — on other desktops you bind
  the key yourself (see [Global shortcut](#global-shortcut)).
- [`gamescope`](https://archlinux.org/packages/extra/x86_64/gamescope/)
- [`xdotool`](https://archlinux.org/packages/extra/x86_64/xdotool/)
- `bash`, `awk`, coreutils, and `setsid` (util-linux) — all standard.
- Optional: `notify-send` (libnotify) for desktop notifications.

```sh
# Arch / CachyOS
sudo pacman -S gamescope xdotool
```

## Install

```sh
git clone https://github.com/erlendrosok/foxclick
cd foxclick
./install.sh
```

`install.sh` copies:

| file | destination |
|---|---|
| `foxclick` | `~/.local/bin/foxclick` |
| `config.example` | `~/.config/foxclick/config` (only if missing) |
| generated `.desktop` | `~/.local/share/applications/foxclick.desktop` |

On KDE it also registers a global shortcut — see below. Everything except the
`foxclick` script itself is optional convenience; you can also just drop the
script anywhere on your `PATH` and run it directly.

## Global shortcut

You want `foxclick toggle` on a single key so you can arm/disarm it without
leaving the game.

**KDE Plasma** — `install.sh` does this for you: it writes
`~/.config/kglobalshortcutsrc` and registers the binding live over D-Bus.
Default is **Meta+X**; override with `FOXCLICK_KEY="Meta+Shift+C" ./install.sh`,
or `FOXCLICK_KEY=none ./install.sh` to skip it. You can also change it afterwards
in *System Settings → Keyboard → Shortcuts* (search "Foxclick").

**Everything else** — `install.sh` skips this step; bind
`~/.local/bin/foxclick toggle` to a key in your environment's own config:

| environment | where |
|---|---|
| GNOME | Settings → Keyboard → *Custom Shortcuts*, command `foxclick toggle` |
| Hyprland | `bind = SUPER, X, exec, foxclick toggle` |
| Sway / i3 | `bindsym $mod+x exec foxclick toggle` |
| niri | `Mod+X { spawn "foxclick" "toggle"; }` |
| Xfce | Settings → Keyboard → *Application Shortcuts* |

Pick a key your game doesn't use — `Meta`/`Super` combos are usually safe. If the
compositor won't deliver the shortcut while a fullscreen game is focused, run
`foxclick toggle` from a terminal on another monitor instead.

## Set up the game

Add a launch option so Steam runs the game through gamescope. In Steam →
game → *Properties* → *Launch Options*:

```
gamescope -w 2560 -h 1440 -W 2560 -H 1440 -f --force-grab-cursor -- %command%
```

Adjust the numbers to your monitor. Lowercase `-w`/`-h` is the resolution
gamescope asks the game to render at; uppercase `-W`/`-H` is the output size —
keep them equal to each other and to the resolution you set inside the game.

Other useful flags: `-r 240` (refresh rate), `-e` (Steam integration),
`--backend sdl` (fallback if cursor handling misbehaves), `-s 1.0` (mouse
sensitivity multiplier, tune if aiming feels off with `--force-grab-cursor`).

### The `--force-grab-cursor` flag

Without it, some games (Foxhole among them) make the mouse pointer jitter and
snap back and forth when it's near an in-game menu or panel, which makes those
hard to click. `--force-grab-cursor` stops that.

The trade-off: the pointer is then locked inside the gamescope window, even in
menus. Press **Meta** (or your compositor's unfocus shortcut) to release it when
you want another monitor — foxclick keeps clicking the whole time, focused or not.

If you don't see the pointer misbehaving, leave the flag out.

## Usage

With the game running under gamescope:

```sh
foxclick calibrate     # show the detected nested display + fire 5 test clicks
foxclick start         # start clicking
foxclick stop          # stop
foxclick toggle        # start if stopped, stop if running  (bind this to a key)
foxclick status        # running state + last-run log
foxclick log           # just the diagnostic log
```

Typical flow: hover the cursor over the spot in-game, hit your toggle key
(**Meta+X** by default on KDE — see [Global shortcut](#global-shortcut)), tab
away to do something else, hit it again when the task is done.

foxclick auto-stops if the game or its display disappears.

## Configuration

`~/.config/foxclick/config` (plain shell, sourced):

| key | default | meaning |
|---|---|---|
| `MODE` | `click` | `click` = repeated click events; `hold` = press and hold the button |
| `CPS` | `12` | clicks per second (click mode) |
| `JITTER` | `15` | ± percent random variation on the interval; `0` = perfectly steady |
| `BUTTON` | `1` | X button number — `1` left, `2` middle, `3` right |
| `REASSERT` | `1` | hold mode: re-send the press every second so gamescope doesn't drop the held state |
| `CLEARMODS` | `1` | click with `--clearmodifiers` so a held Alt/Ctrl/Shift (e.g. Discord push-to-talk leaking into the game) doesn't turn every click into a modified click |
| `WARP` | *(empty)* | `"X Y"` to move the nested cursor to a fixed pixel every tick; empty = wherever it is |
| `GS_DISPLAY` | *(empty)* | force the nested display, e.g. `":1"`, instead of autodetecting |
| `MAX_SECONDS` | `0` | safety auto-stop after N seconds; `0` = no limit |

Changes take effect on the next `start`/`toggle` — there's no daemon.

If you run more than one game under gamescope at once, foxclick targets the
lowest-numbered nested display; set `GS_DISPLAY` (check the numbers with
`foxclick calibrate`) to point it at the other one.

## Troubleshooting

- **`foxclick log`** prints what the last run did, including raw `xdotool` errors.
- **One click then nothing** in `hold` mode: some games/gamescope versions drop a
  synthetic held button. Use `MODE=click` (this is why it's the default), or keep
  `REASSERT=1`.
- **Clicks land in the wrong place**: the nested cursor is independent of your
  real one. Either hover-then-trigger, or set `WARP="X Y"` (get coordinates from
  `foxclick calibrate`).
- **"no gamescope display found"**: the game isn't running under gamescope, or
  it's a native Wayland client with no Xwayland. Check the Steam launch option.
- **The toggle key does nothing over the game**: some compositors don't deliver
  global shortcuts while a fullscreen game is focused. Run `foxclick toggle` from
  a terminal on your other monitor instead, or rebind to a different key.
- **Cursor snaps back and forth near in-game panels / menus**: add
  `--force-grab-cursor` to the launch options (see
  [The `--force-grab-cursor` flag](#the---force-grab-cursor-flag)).
- **Cursor won't cross to another monitor while in-game**: expected with
  `--force-grab-cursor`, and some games confine it on their own too. Press
  **Meta** to unfocus the gamescope window; the cursor frees and foxclick keeps
  clicking the nested display regardless of focus.
- **Clicks stop working while you hold a key** (Discord push-to-talk on Alt,
  etc.): that modifier is reaching the game and modifying every click. `CLEARMODS=1`
  (the default) neutralises it; make sure it's not set to `0`.

## Caveats

- Injecting automated input may violate a game's terms of service or code of
  conduct. That's on you.
- gamescope adds a compositing layer; expect to tune resolution/refresh, and
  alt-tab behaves a little differently.
- Anti-cheat that inspects input devices or the X server may notice. This uses
  the same XTEST mechanism as xclicker and similar tools — no attempt is made to
  hide anything.

## License

MIT — see [LICENSE](LICENSE).
