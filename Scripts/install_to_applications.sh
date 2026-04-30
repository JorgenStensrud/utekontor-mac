#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${UTEKONTOR_CONFIGURATION:-Debug}"
APP_PATH="$ROOT_DIR/.derived/Build/Products/$CONFIGURATION/Utekontor.app"
DEST_DIR="${UTEKONTOR_INSTALL_DIR:-/Applications}"
DEST_APP="$DEST_DIR/Utekontor.app"

if [[ ! -d "$APP_PATH/Contents" ]]; then
  echo "Missing $APP_PATH — build the app first, for example:" >&2
  echo "  cd \"$ROOT_DIR\" && ./Scripts/package_app.sh" >&2
  exit 1
fi

rm -rf "$DEST_APP"
cp -R "$APP_PATH" "$DEST_DIR/"
echo "Installed $DEST_APP"
open "$DEST_APP"
