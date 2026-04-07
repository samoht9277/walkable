#!/bin/bash
# Simulate a walk on the iOS Simulator using a GPX file
# Usage: ./scripts/simulate-walk.sh [gpx-file] [speed-kmh] [device-name]
#   speed-kmh: walking speed in km/h (default: 5)
#   Examples: 5 = walking, 10 = jogging, 20 = fast-forward testing
set -e

GPX_FILE="${1:-scripts/simulate_main_route.gpx}"
SPEED_KMH="${2:-5}"
DEVICE="${3:-iPhone 16}"

if [ ! -f "$GPX_FILE" ]; then
    echo "GPX file not found: $GPX_FILE"
    exit 1
fi

# Convert km/h to m/s
SPEED_MS=$(python3 -c "print(round($SPEED_KMH * 1000 / 3600, 2))")

echo "=== Walkable GPS Simulator ==="
echo "Route:  $GPX_FILE"
echo "Speed:  $SPEED_KMH km/h ($SPEED_MS m/s)"
echo "Device: $DEVICE"
echo ""

# Boot simulator if needed
xcrun simctl boot "$DEVICE" 2>/dev/null || true

# Extract waypoints from GPX as "lat,lon" pairs
WAYPOINTS=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$GPX_FILE')
root = tree.getroot()
tags = ['wpt', 'trkpt', 'rtept']
ns_options = [{}, {'': 'http://www.topografix.com/GPX/1/1'}]
pts = []
for ns in ns_options:
    for tag in tags:
        found = root.findall('.//' + tag, ns) if ns else root.findall('.//' + tag)
        if found:
            pts = found
            break
    if pts:
        break
seen = set()
last_key = None
for i, pt in enumerate(pts):
    lat = pt.get('lat')
    lon = pt.get('lon')
    key = f'{lat},{lon}'
    is_last = (i == len(pts) - 1)
    if key not in seen or is_last:
        seen.add(key)
        print(key)
        last_key = key
")

POINT_COUNT=$(echo "$WAYPOINTS" | wc -l | tr -d ' ')
echo "Loaded $POINT_COUNT waypoints"
echo "Starting GPS simulation..."
echo ""
echo "$WAYPOINTS" | xcrun simctl location "$DEVICE" start --speed="$SPEED_MS" --distance=5 -

echo "Simulating walk. Press Ctrl+C to stop."
trap 'echo ""; echo "Stopping..."; xcrun simctl location "$DEVICE" clear; echo "Done."' INT
while true; do sleep 1; done
