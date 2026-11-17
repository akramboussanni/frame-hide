#!/bin/bash
# Frame Hide installer. Run ON THE STEAM FRAME:   bash install.sh
# (or the one-liner in README.md, which downloads this and runs it).
# Writes only inside your home folder:
#   ~/.local/share/framehide   driver, invisible models, uninstaller
#   ~/.local/bin/framehide     the command
#   ~/.local/state/framehide   mode + log
#   ~/.config/openvr/openvrpaths.vrpath   (Valve's vrpathreg adds the driver folder to "external_drivers")
# Options (environment): FH_BUILD=1 build the driver from source with g++ instead of using the prebuilt one;
#                        FH_NO_RESTART=1 don't restart SteamVR at the end.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
ROOT="$HOME/.local/share/framehide"
DRV="$ROOT/driver/framehide"
VRPATHREG=/opt/steamvr/bin/linuxarm64/vrpathreg
VALVE=/opt/steamvr/drivers/frame_controller/resources/rendermodels
die() { echo "PROBLEM: $*" >&2; exit 1; }

[ "$(uname -m)" = aarch64 ] && [ -x "$VRPATHREG" ] || die "this is for the Steam Frame (SteamOS, aarch64, SteamVR in /opt/steamvr)"
command -v python3 >/dev/null || die "'python3' is missing"
for s in left right; do [ -f "$VALVE/frame_controller_$s/frame_controller_$s.json" ] || die "Valve's $s controller model was not found in $VALVE"; done

mkdir -p build
if [ "${FH_BUILD:-0}" != 1 ] && [ -f prebuilt/driver_framehide.so ]; then
  echo "== using the prebuilt driver"
  cp prebuilt/driver_framehide.so build/
else
  command -v g++ >/dev/null || die "building needs 'g++', which is missing"
  echo "== building the driver"
  g++ -std=c++17 -O2 -fPIC -shared -fvisibility=hidden -Ithird_party/openvr src/driver_framehide.cpp -o build/driver_framehide.so
fi

echo "== installing into $ROOT"
rm -rf "$DRV"
mkdir -p "$DRV/bin/linuxarm64" "$DRV/resources/rendermodels" "$HOME/.local/bin" "$HOME/.local/state/framehide"
install -m 755 build/driver_framehide.so "$DRV/bin/linuxarm64/"
cat > "$DRV/driver.vrdrivermanifest" <<'EOF'
{
	"alwaysActivate": true,
	"name": "framehide",
	"directory": "",
	"resourceOnly": false,
	"hmd_presence": []
}
EOF
for s in left right; do
  python3 -I tools/make_hidden_model.py "$VALVE/frame_controller_$s/frame_controller_$s.json" "$DRV/resources/rendermodels" "framehide_$s"
done
install -m 755 framehide "$HOME/.local/bin/framehide"
install -m 755 uninstall.sh "$ROOT/uninstall.sh"

echo "== registering the driver with SteamVR"
STUB="$(mktemp -d)"; printf '#!/bin/sh\nexit 0\n' > "$STUB/xdg-open"; chmod 755 "$STUB/xdg-open"  # vrpathreg may try to open a URL
PATH="$STUB:$PATH" "$VRPATHREG" adddriver "$DRV" >/dev/null 2>&1 || { rm -rf "$STUB"; die "vrpathreg adddriver failed"; }
rm -rf "$STUB"

if [ "${FH_NO_RESTART:-0}" != 1 ]; then
  echo "== restarting SteamVR to load the driver (the headset view reloads for a few seconds)"
  XDG_RUNTIME_DIR="/run/user/$(id -u)" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \
    systemctl --user restart steamvr.service || echo "note: could not restart SteamVR; reboot the headset instead"
fi

cat <<EOF

DONE. Controllers now hide while passthrough is on.
  framehide passthrough | always | off | status      framehide uninstall
EOF
