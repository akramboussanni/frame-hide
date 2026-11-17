#!/bin/bash
# Frame Hide installer (test build). Run ON THE STEAM FRAME:   bash install.sh
# Writes only inside your home folder:
#   ~/.local/share/framehide   driver + invisible models
#   ~/.local/bin/framehide     the switch
#   ~/.config/openvr/openvrpaths.vrpath   (vrpathreg adds the driver folder to "external_drivers")
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
ROOT="$HOME/.local/share/framehide"
DRV="$ROOT/driver/framehide"
VRPATHREG=/opt/steamvr/bin/linuxarm64/vrpathreg
VALVE=/opt/steamvr/drivers/frame_controller/resources/rendermodels
die() { echo "PROBLEM: $*" >&2; exit 1; }

[ "$(uname -m)" = aarch64 ] && [ -x "$VRPATHREG" ] || die "this is for the Steam Frame (SteamOS, aarch64, SteamVR in /opt/steamvr)"
for t in g++ python3; do command -v "$t" >/dev/null || die "'$t' is missing"; done
for s in left right; do [ -f "$VALVE/frame_controller_$s/frame_controller_$s.json" ] || die "Valve's $s controller model was not found in $VALVE"; done

echo "== building"
mkdir -p build
g++ -std=c++17 -O2 -fPIC -shared -fvisibility=hidden -Ithird_party/openvr src/driver_framehide.cpp -o build/driver_framehide.so

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

echo "== registering the driver with SteamVR"
STUB="$(mktemp -d)"; printf '#!/bin/sh\nexit 0\n' > "$STUB/xdg-open"; chmod 755 "$STUB/xdg-open"  # vrpathreg may try to open a URL
PATH="$STUB:$PATH" "$VRPATHREG" adddriver "$DRV" >/dev/null 2>&1 || { rm -rf "$STUB"; die "vrpathreg adddriver failed"; }
rm -rf "$STUB"

cat <<EOF

DONE. Restart SteamVR once so it loads the driver (this reloads the headset session):
  XDG_RUNTIME_DIR=/run/user/\$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u)/bus systemctl --user restart steamvr.service
Then:  framehide hide   /   framehide show   /   framehide status
EOF
