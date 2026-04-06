#!/bin/bash
# Full automated walk test: build, import route, start walk, simulate GPS
set -e

DEVICE="iPhone 16"
GPX_FILE="${1:-scripts/simulate_main_route.gpx}"

export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:/opt/homebrew/Cellar/maestro/2.3.0/bin:$PATH"
export MAESTRO_CLI_NO_ANALYTICS=1
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

cd "$(dirname "$0")/.."

echo "=== Full Walk Test ==="
echo ""

# 1. Boot sim
echo "1. Booting simulator..."
xcrun simctl boot "$DEVICE" 2>/dev/null || true

# 2. Build and install
echo "2. Building and installing..."
xcodebuild -project Walkable.xcodeproj -scheme WalkableApp \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    build 2>&1 | tail -1
xcrun simctl install "$DEVICE" \
    ~/Library/Developer/Xcode/DerivedData/Walkable-*/Build/Products/Debug-iphonesimulator/WalkableApp.app

# 3. Set initial location to route start
echo "3. Setting initial location..."
START_COORD=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$GPX_FILE')
root = tree.getroot()
pts = root.findall('.//wpt') or root.findall('.//{http://www.topografix.com/GPX/1/1}wpt')
if not pts:
    pts = root.findall('.//trkpt') or root.findall('.//{http://www.topografix.com/GPX/1/1}trkpt')
if pts:
    print(f'{pts[0].get(\"lat\")},{pts[0].get(\"lon\")}')
")
xcrun simctl location "$DEVICE" set "$START_COORD"

# 4. Use Maestro to create a route and start walking
echo "4. Creating route and starting walk via Maestro..."
maestro test .maestro/11_simulate_walk.yaml 2>&1 | grep -E '(COMPLETED|FAILED)' || true

# 5. Start GPS simulation
echo "5. Starting GPS simulation at 5 km/h..."
python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$GPX_FILE')
root = tree.getroot()
pts = root.findall('.//wpt') or root.findall('.//trkpt')
seen = set()
for pt in pts:
    key = f'{pt.get(\"lat\")},{pt.get(\"lon\")}'
    if key not in seen:
        seen.add(key)
        print(key)
" | xcrun simctl location "$DEVICE" start --speed=1.4 --distance=5 -

echo ""
echo "Walk simulation running! Taking screenshots every 30s..."
echo "Press Ctrl+C to stop."

# 6. Periodic screenshots
trap 'xcrun simctl location "$DEVICE" clear; echo "Stopped."; exit 0' INT
i=0
while true; do
    sleep 30
    i=$((i + 1))
    xcrun simctl io "$DEVICE" screenshot "screenshots/walk_sim_${i}.png" 2>/dev/null
    echo "  Screenshot $i saved"
done
