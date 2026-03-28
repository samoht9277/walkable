# Walkable

iOS + watchOS walking loop app. SwiftUI, MapKit, SwiftData, HealthKit, WatchConnectivity, ActivityKit.

## Build
- `xcodegen generate` after creating/moving Swift files (project.yml -> .xcodeproj)
- `xcodebuild -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build`
- `xcodebuild -scheme WalkableWatch -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 3 (49mm)' build`
- `xcodebuild test -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WalkableTests`
- `git -c commit.gpgsign=false commit` (1Password GPG signing broken on this machine)

## Architecture
- MVVM: Views in Views/, ViewModels in ViewModels/, shared logic in WalkableKit package
- WalkableKit is a local Swift package consumed by iOS, watchOS, and widget targets
- Services are @MainActor singletons: RoutingService, LocationService, HealthService, SyncService

## Known Pitfalls
- NEVER use `.safeAreaPadding(.top, N)` on the Map, it shifts MapProxy.convert() coordinates, causing pins to land in wrong positions
- Native MapCompass inside `.mapControls` cannot be repositioned, always goes to top-right safe area
- Dynamic Island: only use `.bottom` or `.center` expanded region, `.leading`/`.trailing` clip at rounded corners
- `MapPolyline(mkPolyline)` drops on zoom/pan, always use `MapPolyline(coordinates:)` with value types
- `.glassEffect()` requires iOS 26+. Use `.thinMaterial` as fallback for older targets
- HKLiveWorkoutBuilder is watchOS-only, use HKWorkoutBuilder on iOS with #if os() guards
- Widget extension caches aggressively, delete app and reinstall to see Live Activity changes
- WatchConnectivity `sendMessage` requires both apps active, use `transferUserInfo` as fallback
- Personal dev teams don't support HealthKit Access (Verifiable Health Records), remove from entitlements
- Watch bundle ID must be prefixed with iOS app bundle ID (e.g., com.walkable.WalkableApp.watchkitapp)

## Testing
- 48 unit tests in WalkableTests (models, routing, path simplifier, templates, polyline splitter, formatters)
- 17 UI tests in WalkableUITests (tab navigation, create modes, library, stats)
- Run all: `xcodebuild test -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16'`

## Style
- Liquid glass: `.glassEffect(.regular, in: .capsule)` for buttons, `.rect(cornerRadius: N)` for panels
- Haptics: light (pin place), medium (calculate), heavy (clear/delete), success (save/complete)
- Shared formatters in WalkableKit/Extensions/FormatUtils.swift, never duplicate format functions
- Commits: title only, no body. Follow existing style via `git log --oneline -10`
