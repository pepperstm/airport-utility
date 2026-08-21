#!/bin/sh

set -eu

SMOKE_TEST=0
if [ "${1:-}" = "--smoke-test" ]; then
  SMOKE_TEST=1
  shift
fi
if [ "$#" -ne 0 ]; then
  echo "usage: ./build-app.sh [--smoke-test]" >&2
  exit 2
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

VERSION=${VERSION:-0.1.0}
BUILD_NUMBER=${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || printf '1')}
OUTPUT_DIR=${OUTPUT_DIR:-$SCRIPT_DIR/.build/release-app}
APP_PATH="$OUTPUT_DIR/AirPort Utility.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

case "$OUTPUT_DIR" in
  "$SCRIPT_DIR"/.build/*) ;;
  *)
    echo "OUTPUT_DIR must be inside $SCRIPT_DIR/.build" >&2
    exit 2
    ;;
esac

swift build -c release --product "AirPort Utility"
BIN_PATH=$(swift build -c release --show-bin-path)

rm -rf "$APP_PATH"
mkdir -p "$MACOS_PATH" "$RESOURCES_PATH/backend"

install -m 755 "$BIN_PATH/AirPort Utility" "$MACOS_PATH/AirPort Utility"
install -m 644 Packaging/Info.plist "$CONTENTS_PATH/Info.plist"
ditto "$BIN_PATH/AirPortUtility_AirPortUtilityCore.bundle" "$RESOURCES_PATH"
for backend_file in backend/*.py; do
  install -m 644 "$backend_file" "$RESOURCES_PATH/backend/$(basename "$backend_file")"
done
chmod 755 "$RESOURCES_PATH/backend/airport_backend.py"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_PATH/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_PATH/Info.plist"
plutil -lint "$CONTENTS_PATH/Info.plist"

PYTHON_PATH=$(command -v python3)
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$RESOURCES_PATH" \
  "$PYTHON_PATH" "$RESOURCES_PATH/backend/airport_backend.py" --help >/dev/null
codesign --force --sign - --identifier com.pepperstm.airport-utility "$APP_PATH"
codesign --verify --strict --verbose=2 "$APP_PATH"

if [ "$SMOKE_TEST" -eq 1 ]; then
  SMOKE_OUTPUT="$OUTPUT_DIR/smoke-snapshots"
  mkdir -p "$SMOKE_OUTPUT"
  (
    cd /tmp
    AIRPORT_UTILITY_SNAPSHOT=1 AIRPORT_UTILITY_SNAPSHOT_DIR="$SMOKE_OUTPUT" \
      "$MACOS_PATH/AirPort Utility" >/dev/null
  )
  test -f "$SMOKE_OUTPUT/main.png"
  test -f "$SMOKE_OUTPUT/diagnostics.png"
  echo "Packaged-app smoke test passed."
fi

echo "$APP_PATH"
