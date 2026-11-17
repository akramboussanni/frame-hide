#!/bin/bash
# Frame Hide uninstaller. Run ON THE STEAM FRAME:   framehide uninstall   (or: bash uninstall.sh)
# FH_NO_RESTART=1 skips the SteamVR restart.
set -uo pipefail
ROOT="$HOME/.local/share/framehide"
DRV="$ROOT/driver/framehide"
VRPATHREG=/opt/steamvr/bin/linuxarm64/vrpathreg

echo off > "$HOME/.local/state/framehide/mode" 2>/dev/null   # if SteamVR is running, the driver puts Valve's models back first
sleep 1
STUB="$(mktemp -d)"; printf '#!/bin/sh\nexit 0\n' > "$STUB/xdg-open"; chmod 755 "$STUB/xdg-open"
PATH="$STUB:$PATH" "$VRPATHREG" removedriver "$DRV" >/dev/null 2>&1 || echo "note: vrpathreg removedriver reported a problem (maybe it was not registered)"
rm -rf "$STUB" "$ROOT" "$HOME/.local/bin/framehide" "$HOME/.local/state/framehide"
if [ "${FH_NO_RESTART:-0}" != 1 ]; then
  echo "== restarting SteamVR to unload the driver"
  XDG_RUNTIME_DIR="/run/user/$(id -u)" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \
    systemctl --user restart steamvr.service || echo "note: could not restart SteamVR; reboot the headset instead"
fi
echo "Frame Hide removed."
