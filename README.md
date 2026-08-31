# foxclick

A focus-independent autoclicker for a single game window on Wayland.

Ordinary Linux autoclickers (xclicker, xdotool loops, ydotool) inject input at a
global level: the click lands in *whatever* window is focused. On Wayland you
can't tell them "only click that one background window", so the moment you switch
to another window the clicks follow you there — you can't touch anything else on
the machine while the autoclicker runs.

`foxclick` sends its clicks straight to **one specific X window, addressed by
id** (`xdotool --window`). The events go to that window and nowhere else,
regardless of what has focus, and without *taking* focus. Park the game on one
monitor, work on the other.

It was written for repetitive hold-to-work actions in
[Foxhole](https://store.steampowered.com/app/505460/Foxhole/) (building, digging),
but nothing in it is Foxhole-specific — point `WINDOW_CLASS` at any XWayland game.

> **Earlier versions** ran the game inside [gamescope](https://github.com/ValveSoftware/gamescope)
> and injected into gamescope's private nested X display. That's no longer needed
> — and dropping it removes gamescope's compositing/frame-pacing overhead. If you
> were using the gamescope launch option, remove it (see [Set up the game](#set-up-the-game)).

## How it works

```
        your Wayland session
┌─────────────────────────────────────────┐
│  browser / Discord / terminal  (focused) │  ← your real keyboard + mouse
│                                          │
│  the game  (XWayland window, unfocused)  │  ← foxclick's clicks, by window id
└──────────────▲───────────────────────────┘
               │
   foxclick ── xdotool click --window <game id> ──┘
```

`xdotool click --window <id>` delivers a synthetic `ButtonPress`/`ButtonRelease`
via `XSendEvent` to that exact window. It doesn't move your pointer, doesn't
change focus, and can't reach any other window — a click sent to the game's
window id is simply not visible to Discord, the browser, or Steam.

foxclick finds the game window by X class (and optionally name), picking the
largest matching window so it ignores the game's tiny helper/IME/tooltip windows.

## Requirements

- A Wayland session with XWayland (Hyprland, KWin, Sway, …). The game must run as
  a normal window — **not** through gamescope.
- [`xdotool`](https://archlinux.org/packages/extra/x86_64/xdotool/)
- `bash`, `awk`, coreutils, `setsid` (util-linux) — all standard.
- Optional: `notify-send` (libnotify) for desktop notifications.

```sh
sudo pacman -S xdotool          # Arch / CachyOS / Omarchy
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

On KDE it also registers a global shortcut (Meta+X). Everywhere else you bind the
key yourself — see below.

## Global shortcut

You want `foxclick toggle` on a single key so you can arm/disarm it without
leaving the game.

| environment | where |
|---|---|
| Hyprland | `bind = SUPER, A, exec, foxclick toggle` (Omarchy: `o.bind` in `~/.config/hypr/bindings.lua`) |
| KDE Plasma | `install.sh` registers Meta+X; change it in *System Settings → Shortcuts* |
| GNOME | Settings → Keyboard → *Custom Shortcuts*, command `foxclick toggle` |
| Sway / i3 | `bindsym $mod+a exec foxclick toggle` |
| niri | `Mod+A { spawn "foxclick" "toggle"; }` |

Pick a key the game doesn't use. The toggle needs to reach your compositor while
the game is focused — `Super`/`Meta` combos usually do; if not, run
`foxclick toggle` from a terminal on your other monitor.

## Set up the game

Just run the game normally. In Steam → game → *Properties* → *Launch Options*,
make sure there is **no `gamescope … -- %command%` wrapper** — plain `%command%`
(or whatever else you need, minus gamescope).

Set the game to **borderless / windowed fullscreen**, not exclusive fullscreen,
so it stays a normal compositor window you can tab away from.

## Usage

With the game running:

```sh
foxclick calibrate   # show the detected game window + fire 5 test clicks
foxclick start       # start
foxclick stop        # stop
foxclick toggle      # start if stopped, stop if running  (bind this to a key)
foxclick status      # running state + last-run log
foxclick log         # just the diagnostic log
```

Typical flow: aim at the spot in-game, hit your toggle key, tab away to do
something else, hit it again when the task is done.

foxclick auto-stops if the game window disappears.

## Configuration

`~/.config/foxclick/config` (plain shell, sourced):

| key | default | meaning |
|---|---|---|
| `MODE` | `hold` | `hold` = press and hold the button; `click` = repeated click events |
| `CPS` | `12` | clicks per second (click mode) |
| `JITTER` | `15` | ± percent random variation on the interval; `0` = perfectly steady |
| `BUTTON` | `1` | X button — `1` left, `2` middle, `3` right |
| `REASSERT` | `1` | hold mode: re-send the press every tick so a dropped press recovers |
| `WINDOW_CLASS` | `steam_app_505460` | X class of the game window (Foxhole = its Steam appid) |
| `WINDOW_NAME` | *(empty)* | optional extra filter: the window name must match this regex |
| `X_DISPLAY` | *(empty)* | force the X display (e.g. `:0`); empty = autodetect |
| `CLEARMODS` | `0` | send a modifier-release to the game window before each click — enable only if a key you physically hold (Alt for push-to-talk) is turning clicks into modified clicks in-game |
| `MAX_SECONDS` | `0` | safety auto-stop after N seconds; `0` = no limit |

Changes take effect on the next `start`/`toggle` — there's no daemon.

## Troubleshooting

- **`foxclick log`** prints what the last run did, including raw `xdotool` errors.
- **"game window not found"**: the game isn't running, it's running through
  gamescope (remove the launch option), or its window class isn't
  `steam_app_505460` — run `foxclick calibrate`, or set `WINDOW_CLASS` /
  `WINDOW_NAME` to what `xdotool search --name .` shows.
- **Clicks pause while another *XWayland* window (e.g. Discord) is focused**:
  known limitation — XWayland routes the synthetic pointer event by its emulated
  pointer position, which sits inside the focused X client instead of the game.
  Clicks resume as soon as you focus a native Wayland window (browser, terminal)
  or the game. Native Wayland windows don't cause this. Since Discord
  push-to-talk is global you rarely need Discord focused anyway.
- **Clicks land in the wrong place in-game**: aim in-game *before* you hit the
  toggle — the game keeps acting at its last cursor position while you're tabbed
  away. In `hold` mode this is usually a non-issue for build/dig actions.
- **One click then nothing** in `hold` mode: keep `REASSERT=1` (default), or use
  `MODE=click`.
- **Right-click (or another button) dies in-game after using foxclick**: `stop`
  releases buttons 1/2/3 on the game window and every `start` begins from a clean
  slate, so toggling clears it.
- **The toggle key does nothing over the game**: some compositors don't deliver
  global shortcuts while a fullscreen game is focused. Run `foxclick toggle` from
  a terminal on your other monitor, or rebind.

## Caveats

- Injecting automated input may violate a game's terms of service or code of
  conduct. That's on you.
- Anti-cheat that inspects the X server or input devices may notice. This uses
  the same `XSendEvent` mechanism as many X automation tools — no attempt is made
  to hide anything.

## License

MIT — see [LICENSE](LICENSE).
