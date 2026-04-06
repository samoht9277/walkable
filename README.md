<p align="center">
  <img src="assets/banner.png" alt="Walkable" width="100%">
</p>

<h2 align="center">:construction: Work In Progress :construction:</h2>

<p align="center">
  <strong>A native iOS + watchOS app for creating and walking custom loops around your neighborhood.</strong><br>
  Built entirely with Apple frameworks, zero external dependencies.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-26.0+-007AFF?logo=apple" alt="iOS 26+">
  <img src="https://img.shields.io/badge/watchOS-26.0+-007AFF?logo=apple" alt="watchOS 26+">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift" alt="Swift 6">
  <img src="https://img.shields.io/badge/Dependencies-0-30D158" alt="Zero dependencies">
  <img src="https://img.shields.io/github/actions/workflow/status/samoht9277/walkable/ci.yml?label=CI" alt="CI">
  <img src="https://img.shields.io/github/license/samoht9277/walkable" alt="License">
</p>

<p align="center">
  <img src="assets/screenshot_route.png" alt="Walkable — route creation with waypoints" width="300">
</p>

> **Note:** This app is under active development. Features may change, break, or disappear. [Contributions](CONTRIBUTING.md) and feedback welcome!

## Features

### Create Walking Loops

Three ways to design your route:

- **Pin Mode** — Tap the map to place waypoints. The app calculates a walkable route between them using Apple Maps directions, automatically closing the loop.
- **Draw Mode** — Hold and drag to freehand draw a loop. The app snaps your drawing to walkable roads and generates waypoints. Toggle between pen (draw) and hand (pan) with the floating button.
- **Templates** — Pick a shape (Loop, Out & Back, Figure-8), set a target distance, and generate a route. Out & Back follows the map's current heading direction.

Waypoints snap to the nearest walkable road after route calculation. Long-press any waypoint to move or delete it.

### Walk with Live Guidance

- Real-time GPS tracking with walked (gray) vs remaining (blue) polyline
- Haptic feedback and voice announcements at each waypoint
- Dynamic Island and Lock Screen Live Activity showing distance and time
- Walk banner on other tabs when a walk is in progress
- Pause/resume with correct time accounting
- Walks under 10m / 30s are automatically discarded (testing protection)

### Apple Watch

- Walk synced routes from iPhone — routes sync automatically via WatchConnectivity
- Four swipeable views during a walk: **Controls** (pause/resume/end), **Map** (route + position), **Compass** (arrow to next waypoint), **Now Playing** (native system controls)
- Walk results (GPS track, leg splits, stats) sync back to iPhone
- Sessions done on Watch are tagged with ⌚ on the phone
- Voice announcements on waypoint arrival and walk completion

### Stats & Health

- Walking workouts saved to Apple Health (works on both iPhone and Watch)
- Weekly/monthly dashboard with distance, walks, pace trends, streaks
- Per-route leaderboard with best times
- Per-waypoint leg splits
- Session detail with planned route (blue) + actual GPS track (green) overlay
- Deletable sessions (removes from both app and HealthKit)
- "View All" for complete walk history

### Library

- Save, search, tag, and favorite your routes
- Sort by date, distance, times walked, or nearest
- Route detail with map preview, stats, and "Start Walk" button
- Edit route name and tags (pencil icon in detail view)
- Swipe to favorite or delete

### Design

- iOS 26 Liquid Glass (`.glassEffect`) on all floating controls
- Haptics throughout: light (pin place), medium (calculate), heavy (clear/delete), success (save/complete)
- Shared formatters for consistent distance, pace, and time display
- SF Symbols everywhere, no custom icon assets

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI | SwiftUI + Liquid Glass (iOS 26) |
| Maps | MapKit (MKDirections, MapPolyline, MapCompass) |
| Persistence | SwiftData |
| Health | HealthKit (HKWorkoutSession, HKWorkoutBuilder) |
| Watch Sync | WatchConnectivity (applicationContext + transferUserInfo) |
| Live Activity | ActivityKit + WidgetKit |
| Location | CoreLocation |
| Import/Export | GPX (GPS Exchange Format) |
| Testing | XCTest + XCUITest + Maestro |
| CI | GitHub Actions |
| Project Gen | XcodeGen |

**Zero external dependencies.** Everything is built on Apple frameworks.

## Roadmap

### Phase 1: Polish & Stability
- [ ] Fix Dynamic Island expanded layout ([#2](https://github.com/samoht9277/walkable/issues/2), [#3](https://github.com/samoht9277/walkable/issues/3))
- [ ] Verify Live Activity pause/resume ([#4](https://github.com/samoht9277/walkable/issues/4))
- [x] ~~Deduplicate existing Watch routes~~ ([#5](https://github.com/samoht9277/walkable/issues/5))
- [ ] Redesign session detail like Apple Fitness recap ([#6](https://github.com/samoht9277/walkable/issues/6))
- [ ] Fix walk auto-ending when GPS stops ([#29](https://github.com/samoht9277/walkable/issues/29))

### Phase 2: Features
- [x] ~~Elevation tracking~~ ([#7](https://github.com/samoht9277/walkable/issues/7)) — walk analysis with interactive charts
- [ ] Live heart rate + calories during walks ([#8](https://github.com/samoht9277/walkable/issues/8))
- [ ] Home screen widgets ([#9](https://github.com/samoht9277/walkable/issues/9))
- [x] ~~Settings tab~~ ([#10](https://github.com/samoht9277/walkable/issues/10)) — map style, haptics, units (km/mi)
- [ ] Walking notifications & streak reminders ([#11](https://github.com/samoht9277/walkable/issues/11))
- [ ] Share routes via link or QR code ([#12](https://github.com/samoht9277/walkable/issues/12))
- [ ] Route recommendations near user ([#13](https://github.com/samoht9277/walkable/issues/13))
- [x] ~~Multiple map styles~~ ([#14](https://github.com/samoht9277/walkable/issues/14)) — via Settings tab
- [x] ~~GPX import/export~~ ([#28](https://github.com/samoht9277/walkable/issues/28)) — routes and sessions
- [ ] Interactive chart scrubbing with timestamps ([#32](https://github.com/samoht9277/walkable/issues/32))

### Phase 3: App Store Prep
- [ ] App Store assets and metadata ([#15](https://github.com/samoht9277/walkable/issues/15))
- [ ] First-launch onboarding flow ([#16](https://github.com/samoht9277/walkable/issues/16))
- [ ] TestFlight beta distribution ([#17](https://github.com/samoht9277/walkable/issues/17))

## Requirements

- iOS 26.0+ / watchOS 26.0+
- Xcode 26.3+
- XcodeGen (`brew install xcodegen`)

## Getting Started

```bash
git clone https://github.com/samoht9277/walkable.git
cd walkable
make generate    # Generate Xcode project from project.yml
make build       # Build iOS app
make test-all    # Run all tests
make open        # Open in Xcode
```

To install on your devices: open in Xcode, select your team in Signing & Capabilities, then Cmd+R. The Watch app deploys automatically with the iOS app.

## Project Structure

```
Walkable/
  WalkableKit/          Shared Swift package (models, services, formatters, voice)
  WalkableApp/          iOS app (views, view models, haptics)
  WalkableWatch/        watchOS app (synced routes + walking)
  WalkableWidgets/      Dynamic Island + Lock Screen Live Activity
  WalkableTests/        48 unit tests
  WalkableUITests/      17 UI automation tests
  .maestro/             10 Maestro visual test flows
  .github/              CI, PR template, issue templates
  project.yml           XcodeGen project definition
```

## Testing

```bash
make test        # 48 unit tests (models, routing, path simplifier, templates, formatters)
make test-ui     # 17 UI tests (tab navigation, create modes, library, stats)
make test-all    # Everything
make maestro     # 10 Maestro visual test flows (requires maestro CLI)
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions, development workflow, and code style guidelines.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
