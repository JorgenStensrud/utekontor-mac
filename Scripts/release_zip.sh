#!/bin/zsh
set -euo pipefail

# Builds a Release .app, code-signs with Developer ID, notarizes with Apple,
# staples the ticket, and writes dist/Utekontor-<version>.zip for GitHub Releases.
#
# Usage: from repo root, ./Scripts/release_zip.sh
#
# One-time setup:
#   1. Install a Developer ID Application certificate in your Keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + Developer ID Application)
#   2. Store notary credentials once:
#        xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#          --apple-id "you@example.com" --team-id "$TEAM_ID" \
#          --password "<app-specific-password from appleid.apple.com>"
#
# Optional env overrides:
#   TEAM_ID         Apple Developer Team ID (required if more than one Developer ID
#                   identity is installed; otherwise codesign picks the only match)
#   SIGN_IDENTITY   codesign identity (default: "Developer ID Application")
#   NOTARY_PROFILE  notarytool keychain profile (default: utekontor-notary)
#   SKIP_NOTARIZE   set to 1 to sign but skip notarization (local dry-run)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

TEAM_ID="${TEAM_ID:-}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-utekontor-notary}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"

VERSION_PLIST="$ROOT_DIR/Resources/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Resources/Utekontor.entitlements"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$VERSION_PLIST")"
OUT_DIR="$ROOT_DIR/dist"
ZIP_NAME="Utekontor-${VERSION}.zip"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"

if [[ ! -f "$ENTITLEMENTS" ]]; then
  echo "Missing entitlements file at $ENTITLEMENTS" >&2
  exit 1
fi

export UTEKONTOR_CONFIGURATION=Release
"$ROOT_DIR/Scripts/package_app.sh"

APP_PATH="$ROOT_DIR/.derived/Build/Products/Release/Utekontor.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing $APP_PATH" >&2
  exit 1
fi

echo "==> Code-signing $APP_PATH with hardened runtime"
codesign --force --deep --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" \
  "$APP_PATH"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

mkdir -p "$OUT_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ "$SKIP_NOTARIZE" == "1" ]]; then
  echo "SKIP_NOTARIZE=1 — skipping Apple notarization."
  echo "Wrote $ZIP_PATH (signed, NOT notarized)"
  shasum -a 256 "$ZIP_PATH"
  exit 0
fi

echo "==> Submitting to Apple notary service (typically 2–15 min)"
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "==> Stapling notarization ticket into the .app"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "==> Re-zipping the stapled .app"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Gatekeeper assessment"
spctl --assess --type execute --verbose=2 "$APP_PATH" || true

echo
echo "Wrote $ZIP_PATH"
shasum -a 256 "$ZIP_PATH"
echo "Update Casks/utekontor.rb: version \"$VERSION\" and sha256 with the line above."
