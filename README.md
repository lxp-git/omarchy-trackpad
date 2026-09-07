# Trackpad for Omarchy

Magic Trackpad battery in the bar. Enabling the plugin turns on three
feel switches by default: three-finger drag, four-finger workspace pan,
and the macOS pointer curve.

## Install

```bash
omarchy plugin add https://github.com/lxp-git/omarchy-trackpad.git --enable
omarchy bar move xuanping.trackpad --section right --before omarchy.power
```

This repository is the source. Omarchy clones it to
`~/.config/omarchy/plugins/xuanping.trackpad/`. Edit here, commit, then
`omarchy plugin update xuanping.trackpad`.

The service applies the Hyprland features as soon as the plugin is enabled.

## Use

- **Left click** — battery panel and the three feel switches
- **Middle click** — refresh status

The icon hides when the trackpad is disconnected. Feel settings stay applied.

Low-battery notices fire once at **20%** and once at **10%**. A Bluetooth
reset, a kernel 0% reading, or a plugin reload does not count as a new
discharge — the latch lives in
`~/.local/state/omarchy/xuanping.trackpad/notify.json`. Charging, or a
live reading above 20%, clears it.

After a Bluetooth reconnect the kernel often reports **0%**. The plugin then
reads HID report `0x90` from hidraw. That needs a one-time udev rule:

```bash
~/.config/omarchy/plugins/xuanping.trackpad/bin/trackpad-pack install-hidraw
```

The rule grants the seated user (`TAG+="uaccess"`) read/write on Magic
Trackpad hidraw nodes only. It does not add the user to the `input` group.

Until that rule is in place, a 0% kernel reading after a Bluetooth reset
is treated as unknown and the last good percentage is kept (stale). The
icon stays visible while the trackpad is connected.

## Switches

All three default on. Each rewrites only
`~/.config/hypr/xuanping-trackpad.lua` (never `input.lua`) and reloads
Hyprland.

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

## Remove

```bash
~/.config/omarchy/plugins/xuanping.trackpad/bin/trackpad-pack disable
omarchy plugin remove xuanping.trackpad --yes
```

Then delete the `-- BEGIN xuanping.trackpad` block from
`~/.config/hypr/hyprland.lua` and `~/.config/hypr/xuanping-trackpad.lua` if
they remain.
