#!/bin/bash
# Frame Hide uninstaller. Run ON THE STEAM FRAME:   bash uninstall.sh
set -uo pipefail
ROOT="$HOME/.local/share/framehide"
DRV="$ROOT/driver/framehide"
VRPATHREG=/opt/steamvr/bin/linuxarm64/vrpathreg

rm -f "$HOME/.local/state/framehide/hidden"   # if SteamVR is running, the driver puts the real models back first
sleep 1
STUB="$(mktemp -d)"; printf '#!/bin/sh\nexit 0\n' > "$STUB/xdg-open"; chmod 755 "$STUB/xdg-open"
PATH="$STUB:$PATH" "$VRPATHREG" removedriver "$DRV" >/dev/null 2>&1 || echo "note: vrpathreg removedriver reported a problem (maybe it was not registered)"
rm -rf "$STUB" "$ROOT" "$HOME/.local/bin/framehide" "$HOME/.local/state/framehide"
echo "Removed. Restart SteamVR to unload the driver:"
echo "  XDG_RUNTIME_DIR=/run/user/\$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u)/bus systemctl --user restart steamvr.service"
