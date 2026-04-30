#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.derived"
CONFIGURATION="${UTEKONTOR_CONFIGURATION:-Debug}"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/Utekontor.app"
APP_LINK_PATH="$ROOT_DIR/Utekontor.app"
OPEN_AFTER_BUILD="${UTEKONTOR_OPEN_AFTER_BUILD:-0}"

cd "$ROOT_DIR"
xcodebuild \
  -project Utekontor.xcodeproj \
  -scheme Utekontor \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing built app at $APP_PATH"
  exit 1
fi

ln -sfn "$APP_PATH" "$APP_LINK_PATH"

echo "Built $APP_PATH"
echo "Linked $APP_LINK_PATH -> $APP_PATH"

if [[ "$OPEN_AFTER_BUILD" == "1" ]]; then
  open "$APP_LINK_PATH"
fi
