#!/bin/bash
# One-line installer for Frame Hide. On the Steam Frame (Konsole in Desktop Mode, or SSH):
#   curl -fsSL https://raw.githubusercontent.com/@REPO@/main/get.sh | bash
set -euo pipefail
REPO="${FH_REPO:-@REPO@}"
BRANCH="${FH_BRANCH:-main}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "== downloading Frame Hide ($REPO)"
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar xz -C "$TMP"
bash "$TMP"/*/install.sh
