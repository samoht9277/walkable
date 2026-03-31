#!/bin/bash
# Run Maestro UI tests and save screenshots
set -e

export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:/opt/homebrew/Cellar/maestro/2.3.0/bin:$PATH"
export MAESTRO_CLI_NO_ANALYTICS=1
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

cd "$(dirname "$0")/.."

# Create screenshots dir
mkdir -p .maestro/screenshots

# Boot simulator if needed
xcrun simctl boot "iPhone 16" 2>/dev/null || true

# Build and install
echo "Building app..."
xcodebuild -project Walkable.xcodeproj -scheme WalkableApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | tail -1

echo "Installing app..."
xcrun simctl install "iPhone 16" \
  ~/Library/Developer/Xcode/DerivedData/Walkable-*/Build/Products/Debug-iphonesimulator/WalkableApp.app

# Set location to San Francisco
xcrun simctl location "iPhone 16" set 37.7749,-122.4194

# Run specific flow or all flows
if [ -n "$1" ]; then
  echo "Running flow: $1"
  maestro test ".maestro/$1"
else
  echo "Running all flows..."
  for flow in .maestro/*.yaml; do
    echo "--- Running $flow ---"
    maestro test "$flow" || echo "FAILED: $flow"
  done
fi

echo ""
echo "Screenshots saved to .maestro/screenshots/"
ls -la .maestro/screenshots/ 2>/dev/null
