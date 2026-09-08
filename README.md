# Trackpad for Omarchy

Magic Trackpad battery in the bar. Enabling the plugin turns on three
feel switches by default: three-finger drag, four-finger workspace pan,
and the macOS pointer curve.

This plugin does not use the network.

## Install

```bash
omarchy plugin add https://github.com/lxp-git/omarchy-trackpad.git --enable
omarchy bar move xuanping.trackpad --section right --before omarchy.power
```

Enabling the plugin is the consent to write a **marked** overlay:

- `~/.config/hypr/xuanping-trackpad.lua` (generated, plugin-owned)
- a `-- BEGIN xuanping.trackpad` / `-- END xuanping.trackpad` block in
  `~/.config/hypr/hyprland.lua` (the existing file is copied to
  `~/.config/hypr/hyprland.lua.xuanping-trackpad.bak` before the first edit)

`status` is read-only and does not edit Hyprland config.

## Hidraw access (optional)

After a Bluetooth reconnect the kernel often reports **0%**. Reading HID
report `0x90` needs a udev rule so logind can grant the seated user access
to that Magic Trackpad's hidraw node (`uaccess` + `ID_SEAT=seat0`, no
`input` group).

The shell process never calls `sudo` or `pkexec`. Open the bar panel and
use **Grant hidraw access**, or run this in a terminal:

```bash
~/.config/omarchy/plugins/xuanping.trackpad/bin/trackpad-pack install-hidraw
```

That opens one `sudo` prompt and writes only
`/etc/udev/rules.d/70-xuanping-trackpad-hidraw.rules` from a literal in
the helper (root does not copy files from the plugin checkout). Until the
rule is installed, a 0% kernel reading is treated as unknown and the last
good percentage is kept (stale).

## Use

- **Left click** — battery panel and the three feel switches
- **Right click** — show or hide the percentage after the icon
- **Panel switch** — the same "Show percentage" toggle
- **Middle click** — refresh status

The icon hides when the trackpad is disconnected. Feel settings stay applied.

Low-battery notices fire once at **20%** and once at **10%**. A Bluetooth
reset, a kernel 0% reading, or a plugin reload does not count as a new
discharge. Charging, or a live reading above 20%, clears the latch.

## Switches

All three default on. Each rewrites only
`~/.config/hypr/xuanping-trackpad.lua` (never `input.lua`) and reloads
Hyprland. If `hyprctl configerrors` grows after that write, the overlay is
rolled back.

The generated file is **additive**. A switch that is off omits its keys
instead of writing `0`/`false`, so other programs' earlier settings remain.
Overlays are scoped to Magic Trackpad device names; they do not set global
`input { }`. Four-finger swipe is a compositor gesture, so it is global, but
only registered while that switch is on.

| Switch | What it does |
|---|---|
| Three-finger drag | `hl.device({ drag_3fg = 1 })` on the Trackpad |
| Four-finger swipe | four-finger `scroll_move` gesture |
| macOS pointer curve | custom accel on the Trackpad only |

Natural scroll, clickfinger, and scroll speed belong in `~/.config/hypr/input.lua`,
not in this overlay.

```bash
omarchy-shell xuanping.trackpad toggleDrag
omarchy-shell xuanping.trackpad toggleSwipe
omarchy-shell xuanping.trackpad toggleAccel
```

## Files written

| Path | What |
|---|---|
| `~/.config/hypr/xuanping-trackpad.lua` | generated overlay |
| `~/.config/hypr/hyprland.lua` | one marked `require` block |
| `~/.config/hypr/hyprland.lua.xuanping-trackpad.bak` | copy of hyprland.lua from the first edit |
| `~/.local/state/omarchy/xuanping.trackpad/features.json` | switch state |
| `~/.local/state/omarchy/xuanping.trackpad/battery-cache.json` | last good battery reading |
| `~/.local/state/omarchy/xuanping.trackpad/notify.json` | low-battery latch |
| `/etc/udev/rules.d/70-xuanping-trackpad-hidraw.rules` | only after the explicit sudo install |

## Remove

```bash
~/.config/omarchy/plugins/xuanping.trackpad/bin/trackpad-pack uninstall
omarchy plugin remove xuanping.trackpad --yes
```

`uninstall` removes the marked block from `hyprland.lua`, deletes
`xuanping-trackpad.lua` if it still has this plugin's header, and deletes
the named state files above. It does not delete `hyprland.lua` or the
backup. The udev rule is not removed by `omarchy plugin remove`; take it
out with:

```bash
~/.config/omarchy/plugins/xuanping.trackpad/bin/trackpad-pack uninstall-hidraw
```

Run that **before** `omarchy plugin remove` if you want the helper to do it,
or delete `/etc/udev/rules.d/70-xuanping-trackpad-hidraw.rules` yourself
and run `sudo udevadm control --reload-rules`.
