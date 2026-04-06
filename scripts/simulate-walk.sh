#!/bin/bash
# Simulate a walk on the iOS Simulator using a GPX file
# Usage: ./scripts/simulate-walk.sh [gpx-file] [device-name]
set -e

GPX_FILE="${1:-scripts/simulate_main_route.gpx}"
DEVICE="${2:-iPhone 16}"

if [ ! -f "$GPX_FILE" ]; then
    echo "GPX file not found: $GPX_FILE"
    exit 1
fi

echo "=== Walkable GPS Simulator ==="
echo "Route: $GPX_FILE"
echo "Device: $DEVICE"
echo ""

# Boot simulator if needed
xcrun simctl boot "$DEVICE" 2>/dev/null || true

# Extract waypoints from GPX as "lat,lon" pairs
WAYPOINTS=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$GPX_FILE')
root = tree.getroot()
# Try with and without namespace
tags = ['wpt', 'trkpt', 'rtept']
ns_options = [
    {},
    {'': 'http://www.topografix.com/GPX/1/1'}
]
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
for pt in pts:
    lat = pt.get('lat')
    lon = pt.get('lon')
    key = f'{lat},{lon}'
    if key not in seen:
        seen.add(key)
        print(key)
")

POINT_COUNT=$(echo "$WAYPOINTS" | wc -l | tr -d ' ')
echo "Loaded $POINT_COUNT waypoints"

# Walking speed: 1.4 m/s (~5 km/h)
echo "Starting GPS simulation at walking speed (5 km/h)..."
echo ""
echo "$WAYPOINTS" | xcrun simctl location "$DEVICE" start --speed=1.4 --distance=5 -

echo "GPS simulation running. Press Ctrl+C to stop."
trap 'echo ""; echo "Stopping..."; xcrun simctl location "$DEVICE" clear; echo "Done."' INT
while true; do sleep 1; done
