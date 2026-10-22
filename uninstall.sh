#!/bin/bash
# Removes DockFix and restores iCUE's original Info.plist entry.
set -euo pipefail

APP="/Applications/Corsair iCUE5 Software/iCUE.app"
PLIST="$APP/Contents/Info.plist"
DEST_DIR="/Library/Application Support/iCUE-DockFix"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Remove the plist key first: if the dylib vanished while the key stayed, iCUE would fail to launch.
sudo plutil -remove LSEnvironment.DYLD_INSERT_LIBRARIES "$PLIST" 2>/dev/null || true
sudo rm -f "$PLIST.dockfix-orig"
sudo rm -rf "$DEST_DIR"
"$LSREGISTER" -f "$APP"
echo "DockFix removed. Quit and relaunch iCUE to finish."
