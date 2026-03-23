#!/bin/bash
# Auto-build & launch Huselen on iOS Simulator after Claude finishes
# Only runs if Swift files were modified in the last 2 minutes

PROJ_DIR="/Users/finos/Developer/Me/Huselen"
SCHEME="Huselen"
BUNDLE_ID="vietmind.Huselen"
SIM_ID="60243D41-0E1C-4256-BA00-3F4EF92AE6B9"
BUILD_DIR="/tmp/huselen-sim-build"

# Skip if no Swift files were recently modified
RECENT=$(find "$PROJ_DIR/Huselen" -name "*.swift" -mmin -2 2>/dev/null | head -1)
if [ -z "$RECENT" ]; then
  exit 0
fi

echo "=== Building Huselen for iOS Simulator ==="

# Boot simulator if not already running
xcrun simctl boot "$SIM_ID" 2>/dev/null || true

# Open Simulator.app
open -a Simulator

# Build
xcodebuild \
  -project "$PROJ_DIR/Huselen.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -configuration Debug \
  SYMROOT="$BUILD_DIR" \
  -quiet \
  build

APP_PATH="$BUILD_DIR/Debug-iphonesimulator/$SCHEME.app"

# Install & launch
xcrun simctl install "$SIM_ID" "$APP_PATH"
xcrun simctl launch --console-pty "$SIM_ID" "$BUNDLE_ID"

echo "=== Launched $BUNDLE_ID on simulator ==="
