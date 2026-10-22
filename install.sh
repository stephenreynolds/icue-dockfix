#!/bin/bash
# Installs DockFix so iCUE drops its Dock icon when its window is closed.
# Run as your normal user; it asks for sudo for the two privileged steps.
# Re-run after every iCUE update (updates replace iCUE's Info.plist).
set -euo pipefail

APP="/Applications/Corsair iCUE5 Software/iCUE.app"
PLIST="$APP/Contents/Info.plist"
DEST_DIR="/Library/Application Support/iCUE-DockFix"
DYLIB="$DEST_DIR/libDockFix.dylib"
SRC="$(cd "$(dirname "$0")" && pwd)/DockFix.m"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

[ -d "$APP" ] || { echo "iCUE not found at $APP" >&2; exit 1; }
# Editing Info.plist is only safe while iCUE's signature doesn't cover it.
# (Plain `codesign --verify` fails on iCUE even unmodified: Corsair ships it without a resource seal.)
if ! codesign -dv "$APP" 2>&1 | grep -q 'Info.plist=not bound'; then
    echo "This iCUE version signs its Info.plist; patching it would break the signature. Aborting." >&2
    exit 1
fi

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
echo "Building libDockFix.dylib..."
clang -dynamiclib -fobjc-arc -arch arm64 -arch x86_64 -mmacosx-version-min=12.0 \
    -framework AppKit -O2 -o "$BUILD/libDockFix.dylib" "$SRC"
codesign -s - -f "$BUILD/libDockFix.dylib" 2>/dev/null

echo "Installing to $DEST_DIR and patching iCUE's Info.plist (sudo)..."
sudo mkdir -p "$DEST_DIR"
sudo install -o root -g wheel -m 755 "$BUILD/libDockFix.dylib" "$DYLIB"
sudo cp -p "$PLIST" "$DEST_DIR/Info.plist.backup"
sudo rm -f "$PLIST.dockfix-orig"  # left inside the bundle by an earlier version of this script
sudo plutil -replace LSEnvironment.DYLD_INSERT_LIBRARIES -string "$DYLIB" "$PLIST"

# LaunchServices caches LSEnvironment; refresh it.
"$LSREGISTER" -f "$APP"

if pgrep -x iCUE >/dev/null; then
    echo "Restarting iCUE..."
    osascript -e 'tell application id "com.corsair.cue.main" to quit' >/dev/null 2>&1 || true
    for _ in $(seq 20); do pgrep -x iCUE >/dev/null || break; sleep 0.5; done
    pkill -x iCUE 2>/dev/null || true
    sleep 1
    open -g "$APP" --args --autorun
fi
echo "Done."
