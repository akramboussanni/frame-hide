# Frame Hide (test build)

Hides the Steam Frame's 3D controller models in Frame Home and passthrough. Tracking, buttons and the
laser pointer are not touched: only the model SteamVR draws for each controller is swapped for an
invisible copy, and swapped back when you show them again.

Unofficial; relies on undocumented SteamVR behaviour, so a SteamVR update may break it.

## How it works

- A small SteamVR driver with no device of its own, loaded from your home folder (same pattern as
  frame-tint). It changes each Frame controller's `Prop_RenderModelName_String` between Valve's
  model and `{framehide}framehide_left/right`.
- The invisible models are made at install time from Valve's own model files: every visible part is
  pointed at a zero-size triangle and marked not visible, and the reference points
  (`tip`, `base`, `grip`, `handgrip`, `openxr_aim`, `openxr_grip`, ...) are kept as they are,
  because the laser pointer and game aim/grip use them.
- By default the models are hidden only while passthrough (room view) is on. The driver reads
  SteamVR's own setting for that, `camera/enableConstructRoomView`: SteamVR sets it to true when
  you turn passthrough on and removes it when you turn it off.

## Install (on the headset)

```
cd ~/frame-hide
bash install.sh
XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus systemctl --user restart steamvr.service
```

Writes only: `~/.local/share/framehide`, `~/.local/bin/framehide`, `~/.local/state/framehide`, and the
`external_drivers` entry in `~/.config/openvr/openvrpaths.vrpath` (via Valve's `vrpathreg`).

## Use

```
framehide passthrough   # hide only while passthrough is on (default)
framehide always        # always hide
framehide off           # never hide
framehide status        # current mode + last driver log lines
```

When SteamVR shuts down the driver puts Valve's models back.

## Uninstall

```
bash ~/frame-hide/uninstall.sh
```
then restart SteamVR (command above).

## Not in the test build yet

Dashboard button and controller shortcut. Those come after the live swap is confirmed in the headset.
