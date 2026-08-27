# foxclick

A focus-independent autoclicker for games run inside [gamescope](https://github.com/ValveSoftware/gamescope) on Wayland.

Ordinary Linux autoclickers (xclicker, xdotool loops, ydotool) inject input at a
global level: they click into *whatever* window is focused. On Wayland you can't
tell them "only click that background window", so the moment you tab away to a
browser or Discord, the clicks follow you and wreck whatever you're doing.

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

- A Wayland session (developed on **KDE Plasma 6 / KWin**; the core should work
  on any compositor, the global-shortcut helper is KDE-only).
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

and, on KDE, registers a global shortcut (**Meta+X** by default — override with
`FOXCLICK_KEY="Meta+Shift+C" ./install.sh`).

Or just drop the `foxclick` script anywhere on your `PATH` and run it directly;
everything else is optional convenience.

## Set up the game

Add a launch option so Steam runs the game through gamescope. In Steam →
game → *Properties* → *Launch Options*:

```
gamescope -w 2560 -h 1440 -W 2560 -H 1440 -f --force-windows-fullscreen -- %command%
```

Adjust the numbers to your monitor. Lowercase `-w`/`-h` is the resolution
gamescope asks the game to render at; uppercase `-W`/`-H` is the output size.
**Keep them equal to each other and to the resolution you set inside the game** —
a mismatch is the usual cause of the cursor snapping back near the screen edges
or over in-game panels. `--force-windows-fullscreen` makes the game window fill
the nested display so the cursor bounds line up with what you see.

Other useful flags: `-r 240` (refresh rate), `-e` (Steam integration),
`--backend sdl` (fallback if cursor handling still misbehaves).

Then, **in the game's own video settings**, pick Fullscreen (or Borderless) at
that same resolution.

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

Typical flow: hover the cursor over the spot in-game, hit **Meta+X**, tab away to
do something else, hit **Meta+X** again when the task is done.

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
- **Meta+X does nothing over the game**: run `foxclick toggle` from a terminal on
  your other monitor instead, or rebind (`FOXCLICK_KEY=... ./install.sh`).
- **Cursor snaps back near screen edges / in-game menus, or won't cross to another
  monitor**: gamescope's cursor bounds don't match the visible image. Make the
  in-game resolution equal to `-w`/`-h`/`-W`/`-H`, add `--force-windows-fullscreen`,
  and set the game to Fullscreen/Borderless. To move the real cursor out of a
  focused gamescope window, unfocus it (Meta, or your compositor's shortcut) —
  foxclick keeps clicking the nested display regardless of focus.
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
