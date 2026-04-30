#!/bin/zsh
set -euo pipefail

# Builds a Release .app and writes dist/Utekontor-<version>.zip for GitHub Releases.
# Usage: from repo root, ./Scripts/release_zip.sh
# Then: shasum -a 256 dist/Utekontor-<version>.zip  → paste into Casks/utekontor.rb

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION_PLIST="$ROOT_DIR/Resources/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$VERSION_PLIST")"
OUT_DIR="$ROOT_DIR/dist"
ZIP_NAME="Utekontor-${VERSION}.zip"

export UTEKONTOR_CONFIGURATION=Release
"$ROOT_DIR/Scripts/package_app.sh"

APP_PATH="$ROOT_DIR/.derived/Build/Products/Release/Utekontor.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing $APP_PATH" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Wrote $ZIP_PATH"
shasum -a 256 "$ZIP_PATH"
echo "Update Casks/utekontor.rb: version \"$VERSION\" and sha256 with the line above."
