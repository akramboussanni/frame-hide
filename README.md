# Frame Hide

Hides the Steam Frame's 3D controller models while passthrough (room view) is on, so you just see
your room. Tracking, buttons and the laser pointer are not touched: only the model SteamVR draws for
each controller is swapped for an invisible copy, and swapped back when passthrough goes off.

Unofficial and not affiliated with Valve. It relies on undocumented SteamVR behaviour, so a SteamVR
update may break it.

## Install

On the headset, open a terminal (Desktop Mode → **Konsole**, or `ssh steamos@<headset address>`)
and paste:

```
curl -fsSL https://raw.githubusercontent.com/@REPO@/main/get.sh | bash
```

That's it. It downloads Frame Hide, installs it and restarts SteamVR (the headset view reloads for
a few seconds). Turn passthrough on and the controllers disappear.

No `sudo`, no compiler and no PC needed. Everything goes into your home folder:
`~/.local/share/framehide`, `~/.local/bin/framehide`, `~/.local/state/framehide`, plus the driver
entry that Valve's `vrpathreg` adds to `~/.config/openvr/openvrpaths.vrpath`.

Without the one-liner: download this repository, then `bash install.sh` inside it.

## Use

```
framehide passthrough   # hide only while passthrough is on (default)
framehide always        # always hide
framehide off           # never hide
framehide status        # current mode + last driver log lines
```

When SteamVR shuts down, the driver puts Valve's models back.

## Uninstall

```
framehide uninstall
```

Removes every file above and the driver entry, then restarts SteamVR.

## How it works

- A small SteamVR driver with no device of its own, loaded from your home folder (the same pattern
  as [frame-tint](https://github.com/ugurcansakizli/frame-tint)). It switches each Frame controller's
  `Prop_RenderModelName_String` between Valve's model and `{framehide}framehide_left/right`.
- The invisible models are made at install time from Valve's own model files: every visible part
  points at a zero-size triangle and is marked not visible. The reference points (`tip`, `base`,
  `grip`, `handgrip`, `openxr_aim`, `openxr_grip`, ...) are kept as they are, because the laser
  pointer and game aim/grip use them.
- Passthrough detection: SteamVR sets `camera/enableConstructRoomView` to true when you turn
  passthrough on and removes it when you turn it off. The driver checks it four times a second.
- A prebuilt driver (aarch64) is in `prebuilt/`. `FH_BUILD=1 bash install.sh` builds it from
  `src/` with `g++` instead.

## Not done yet

A dashboard button and a controller shortcut.

## License

MIT. Includes the OpenVR driver header (BSD-3-Clause, `third_party/openvr/LICENSE`).
