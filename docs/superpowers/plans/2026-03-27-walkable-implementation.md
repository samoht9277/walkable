# Walkable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS + WatchOS walking app that lets users create walking loops on a map, walk them with waypoint guidance on Apple Watch, and track fitness via Apple Health.

**Architecture:** SwiftUI + MapKit + SwiftData + HealthKit + WatchConnectivity. MVVM pattern. Shared logic in a local Swift package (WalkableKit) consumed by both iOS and Watch targets. Zero external dependencies.

**Tech Stack:** Swift, SwiftUI, MapKit, SwiftData, HealthKit, CoreLocation, WatchConnectivity, MediaPlayer

---

## File Structure

```
Walkable/
├── Walkable.xcodeproj
├── WalkableKit/                          — Local Swift package (shared)
│   ├── Package.swift
│   └── Sources/
│       └── WalkableKit/
│           ├── Models/
│           │   ├── Route.swift           — SwiftData @Model
│           │   ├── Waypoint.swift        — SwiftData @Model
│           │   ├── WalkSession.swift     — SwiftData @Model
│           │   └── LegSplit.swift        — SwiftData @Model
│           ├── Services/
│           │   ├── RoutingService.swift   — MKDirections routing + caching
│           │   ├── PathSimplifier.swift   — Douglas-Peucker + waypoint sampling
│           │   ├── TemplateGenerator.swift — Loop/OutAndBack/Figure8 generators
│           │   ├── LocationService.swift  — CLLocationManager wrapper
│           │   ├── HealthService.swift    — HKWorkoutSession + stats
│           │   └── SyncService.swift      — WatchConnectivity
│           └── Extensions/
│               ├── CLLocationCoordinate2D+Codable.swift
│               └── MKPolyline+Encoding.swift
├── WalkableApp/                          — iOS target
│   ├── WalkableApp.swift                 — @main entry, ModelContainer setup
│   ├── ContentView.swift                 — TabView root
│   ├── Views/
│   │   ├── Create/
│   │   │   ├── CreateRouteView.swift     — Map + mode switcher
│   │   │   ├── PinModeOverlay.swift      — Pin placement controls
│   │   │   ├── DrawModeOverlay.swift     — Freehand drawing controls
│   │   │   ├── TemplateModeOverlay.swift — Template picker + distance
│   │   │   ├── DrawingCanvas.swift       — UIViewRepresentable for freehand
│   │   │   └── SaveRouteSheet.swift      — Name + tags bottom sheet
│   │   ├── Library/
│   │   │   ├── LibraryView.swift         — List + search + filter
│   │   │   ├── RouteCardView.swift       — Single route row
│   │   │   ├── RouteDetailSheet.swift    — Map preview + start walk
│   │   │   └── LibraryMapView.swift      — All routes on a map
│   │   ├── Walk/
│   │   │   ├── ActiveWalkView.swift      — Live tracking map
│   │   │   ├── WalkStatsBar.swift        — Bottom glass stats
│   │   │   ├── WaypointArrivalCard.swift — Leg split popup
│   │   │   └── WalkSummaryView.swift     — Post-walk results
│   │   ├── Stats/
│   │   │   ├── StatsView.swift           — Dashboard root
│   │   │   ├── StatCardView.swift        — Single metric card
│   │   │   ├── PaceTrendChart.swift      — Swift Charts pace line
│   │   │   └── RouteLeaderboard.swift    — Best times per route
│   │   └── Shared/
│   │       ├── GlassButton.swift         — Floating glass action button
│   │       ├── GlassCard.swift           — Glass material card
│   │       └── RouteMapOverlay.swift     — Reusable route polyline on map
│   └── ViewModels/
│       ├── CreateRouteViewModel.swift
│       ├── LibraryViewModel.swift
│       ├── ActiveWalkViewModel.swift
│       └── StatsViewModel.swift
├── WalkableWatch/                        — watchOS target
│   ├── WalkableWatchApp.swift            — @main entry
│   ├── Views/
│   │   ├── RouteListView.swift           — Synced routes list
│   │   ├── WalkTabView.swift             — PageTabViewStyle container
│   │   ├── WatchMapView.swift            — Route map during walk
│   │   ├── CompassView.swift             — Arrow to next waypoint
│   │   ├── NowPlayingView.swift          — Music controls
│   │   └── WatchSummaryView.swift        — Post-walk results
│   └── ViewModels/
│       ├── WatchRouteListViewModel.swift
│       └── WatchWalkViewModel.swift
└── WalkableTests/                        — Unit tests
    ├── ModelTests.swift
    ├── RoutingServiceTests.swift
    ├── PathSimplifierTests.swift
    ├── TemplateGeneratorTests.swift
    └── StatsViewModelTests.swift
```

---

### Task 1: Xcode Project Setup

**Files:**
- Create: `Walkable.xcodeproj` (via Xcode CLI)
- Create: `WalkableKit/Package.swift`
- Create: `WalkableApp/WalkableApp.swift`
- Create: `WalkableApp/ContentView.swift`
- Create: `WalkableWatch/WalkableWatchApp.swift`

This task sets up the multi-target Xcode project with the shared Swift package.

- [ ] **Step 1: Create the Xcode project with iOS and WatchOS targets**

Use `xcodebuild` isn't great for project creation, so we'll create the project structure manually and use a `project.yml` with XcodeGen (install via `brew install xcodegen`).

Create `project.yml`:

```yaml
name: Walkable
options:
  bundleIdPrefix: com.walkable
  deploymentTarget:
    iOS: "17.0"
    watchOS: "10.0"
  xcodeVersion: "16.0"
  createIntermediateGroups: true

packages:
  WalkableKit:
    path: WalkableKit

targets:
  WalkableApp:
    type: application
    platform: iOS
    sources:
      - WalkableApp
    dependencies:
      - package: WalkableKit
    settings:
      INFOPLIST_KEY_NSLocationWhenInUseUsageDescription: "Walkable needs your location to track walks and show your position on the map."
      INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription: "Walkable needs background location access to track your walks."
      INFOPLIST_KEY_NSHealthShareUsageDescription: "Walkable reads your health data to show fitness stats."
      INFOPLIST_KEY_NSHealthUpdateUsageDescription: "Walkable saves your walking workouts to Apple Health."
    entitlements:
      path: WalkableApp/WalkableApp.entitlements
      properties:
        com.apple.developer.healthkit: true
        com.apple.developer.healthkit.access:
          - health-records

  WalkableWatch:
    type: application
    platform: watchOS
    sources:
      - WalkableWatch
    dependencies:
      - package: WalkableKit
    settings:
      INFOPLIST_KEY_NSLocationWhenInUseUsageDescription: "Walkable needs your location for walk navigation."
      INFOPLIST_KEY_NSHealthShareUsageDescription: "Walkable reads health data during walks."
      INFOPLIST_KEY_NSHealthUpdateUsageDescription: "Walkable saves walking workouts to Apple Health."
      INFOPLIST_KEY_WKCompanionAppBundleIdentifier: com.walkable.WalkableApp
    entitlements:
      path: WalkableWatch/WalkableWatch.entitlements
      properties:
        com.apple.developer.healthkit: true
        com.apple.developer.healthkit.access:
          - health-records

  WalkableTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - WalkableTests
    dependencies:
      - target: WalkableApp
      - package: WalkableKit
```

- [ ] **Step 2: Create the WalkableKit Swift package**

Create `WalkableKit/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WalkableKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "WalkableKit", targets: ["WalkableKit"])
    ],
    targets: [
        .target(
            name: "WalkableKit",
            path: "Sources/WalkableKit"
        )
    ]
)
```

- [ ] **Step 3: Create the iOS app entry point**

Create `WalkableApp/WalkableApp.swift`:

```swift
import SwiftUI
import SwiftData
import WalkableKit

@main
struct WalkableApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Route.self, Waypoint.self, WalkSession.self, LegSplit.self])
    }
}
```

Create `WalkableApp/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Text("Create")
                .tabItem {
                    Label("Create", systemImage: "map")
                }
            Text("Library")
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            Text("Walk")
                .tabItem {
                    Label("Walk", systemImage: "figure.walk")
                }
            Text("Stats")
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
    }
}
```

- [ ] **Step 4: Create the watchOS app entry point**

Create `WalkableWatch/WalkableWatchApp.swift`:

```swift
import SwiftUI
import SwiftData
import WalkableKit

@main
struct WalkableWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Walkable")
        }
        .modelContainer(for: [Route.self, Waypoint.self, WalkSession.self, LegSplit.self])
    }
}
```

- [ ] **Step 5: Create entitlements files**

Create `WalkableApp/WalkableApp.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
</plist>
```

Create `WalkableWatch/WalkableWatch.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
</dict>
</plist>
```

- [ ] **Step 6: Create placeholder file for WalkableKit so it compiles**

Create `WalkableKit/Sources/WalkableKit/WalkableKit.swift`:

```swift
// WalkableKit — Shared framework for Walkable iOS + watchOS
```

- [ ] **Step 7: Generate Xcode project and verify it builds**

Run:
```bash
cd /Users/tomi/Personal/walkable
brew install xcodegen 2>/dev/null || true
xcodegen generate
xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git init
echo ".build/\n*.xcuserdatad/\nDerivedData/\n.superpowers/" > .gitignore
git add -A
git commit -m "scaffold: Xcode project with iOS, watchOS targets and WalkableKit package"
```

---

### Task 2: SwiftData Models

**Files:**
- Create: `WalkableKit/Sources/WalkableKit/Models/Route.swift`
- Create: `WalkableKit/Sources/WalkableKit/Models/Waypoint.swift`
- Create: `WalkableKit/Sources/WalkableKit/Models/WalkSession.swift`
- Create: `WalkableKit/Sources/WalkableKit/Models/LegSplit.swift`
- Create: `WalkableKit/Sources/WalkableKit/Extensions/CLLocationCoordinate2D+Codable.swift`
- Create: `WalkableKit/Sources/WalkableKit/Extensions/MKPolyline+Encoding.swift`
- Create: `WalkableTests/ModelTests.swift`

- [ ] **Step 1: Write model tests**

Create `WalkableTests/ModelTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import WalkableKit

@Suite("Data Models")
struct ModelTests {

    @Test("Route creation with defaults")
    func routeDefaults() {
        let route = Route(name: "Test Loop")
        #expect(route.name == "Test Loop")
        #expect(route.tags.isEmpty)
        #expect(route.isFavorite == false)
        #expect(route.distance == 0)
        #expect(route.estimatedDuration == 0)
        #expect(route.waypoints.isEmpty)
        #expect(route.sessions.isEmpty)
    }

    @Test("Waypoint stores coordinates")
    func waypointCoordinates() {
        let wp = Waypoint(index: 0, latitude: 40.7128, longitude: -74.0060)
        #expect(wp.index == 0)
        #expect(wp.latitude == 40.7128)
        #expect(wp.longitude == -74.0060)
        #expect(wp.label == nil)
    }

    @Test("Waypoint coordinate property")
    func waypointCoordinateProperty() {
        let wp = Waypoint(index: 0, latitude: 40.7128, longitude: -74.0060)
        let coord = wp.coordinate
        #expect(abs(coord.latitude - 40.7128) < 0.0001)
        #expect(abs(coord.longitude - (-74.0060)) < 0.0001)
    }

    @Test("WalkSession pace calculation")
    func sessionPace() {
        let route = Route(name: "Test")
        let session = WalkSession(route: route)
        session.totalDistance = 2000 // 2km
        session.totalDuration = 1200 // 20 min
        #expect(session.avgPace == 600) // 600 sec/km = 10 min/km
    }

    @Test("LegSplit stores segment data")
    func legSplitData() {
        let route = Route(name: "Test")
        let session = WalkSession(route: route)
        let split = LegSplit(
            session: session,
            fromWaypointIndex: 0,
            toWaypointIndex: 1,
            distance: 500,
            duration: 300,
            pace: 600
        )
        #expect(split.fromWaypointIndex == 0)
        #expect(split.toWaypointIndex == 1)
        #expect(split.distance == 500)
    }

    @Test("Route sorted waypoints")
    func routeSortedWaypoints() {
        let route = Route(name: "Test")
        let wp2 = Waypoint(index: 2, latitude: 0, longitude: 0)
        let wp0 = Waypoint(index: 0, latitude: 0, longitude: 0)
        let wp1 = Waypoint(index: 1, latitude: 0, longitude: 0)
        route.waypoints = [wp2, wp0, wp1]
        let sorted = route.sortedWaypoints
        #expect(sorted[0].index == 0)
        #expect(sorted[1].index == 1)
        #expect(sorted[2].index == 2)
    }

    @Test("MKPolyline encoding roundtrip")
    func polylineEncoding() {
        // Test that coordinate arrays can be encoded and decoded
        let coords = [
            CodableCoordinate(latitude: 40.7128, longitude: -74.0060),
            CodableCoordinate(latitude: 40.7138, longitude: -74.0070),
            CodableCoordinate(latitude: 40.7148, longitude: -74.0080)
        ]
        let data = try! JSONEncoder().encode(coords)
        let decoded = try! JSONDecoder().decode([CodableCoordinate].self, from: data)
        #expect(decoded.count == 3)
        #expect(abs(decoded[0].latitude - 40.7128) < 0.0001)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Walkable.xcodeproj -scheme WalkableTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Expected: Compilation errors (types don't exist yet)

- [ ] **Step 3: Create CodableCoordinate extension**

Create `WalkableKit/Sources/WalkableKit/Extensions/CLLocationCoordinate2D+Codable.swift`:

```swift
import CoreLocation

/// Codable wrapper for CLLocationCoordinate2D (which isn't Codable natively).
/// Used for encoding polylines and waypoint data for sync and persistence.
public struct CodableCoordinate: Codable, Equatable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    public var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
```

- [ ] **Step 4: Create MKPolyline encoding extension**

Create `WalkableKit/Sources/WalkableKit/Extensions/MKPolyline+Encoding.swift`:

```swift
import MapKit

public extension MKPolyline {
    /// Encode polyline coordinates as JSON Data for SwiftData storage.
    func encodedData() throws -> Data {
        var coords = [CodableCoordinate]()
        let points = self.points()
        for i in 0..<self.pointCount {
            let mapPoint = points[i]
            let coord = mapPoint.coordinate
            coords.append(CodableCoordinate(coord))
        }
        return try JSONEncoder().encode(coords)
    }

    /// Decode a polyline from stored JSON Data.
    static func from(encodedData data: Data) throws -> MKPolyline {
        let coords = try JSONDecoder().decode([CodableCoordinate].self, from: data)
        var clCoords = coords.map { $0.clCoordinate }
        return MKPolyline(coordinates: &clCoords, count: clCoords.count)
    }
}
```

- [ ] **Step 5: Create Route model**

Create `WalkableKit/Sources/WalkableKit/Models/Route.swift`:

```swift
import Foundation
import SwiftData
import CoreLocation

@Model
public final class Route {
    public var id: UUID
    public var name: String
    public var tags: [String]
    public var isFavorite: Bool
    public var distance: Double
    public var estimatedDuration: TimeInterval
    public var createdAt: Date
    public var centerLatitude: Double
    public var centerLongitude: Double
    @Relationship(deleteRule: .cascade, inverse: \Waypoint.route)
    public var waypoints: [Waypoint]
    public var polylineData: Data?
    @Relationship(deleteRule: .cascade, inverse: \WalkSession.route)
    public var sessions: [WalkSession]

    public init(
        name: String,
        tags: [String] = [],
        isFavorite: Bool = false,
        distance: Double = 0,
        estimatedDuration: TimeInterval = 0,
        centerLatitude: Double = 0,
        centerLongitude: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.tags = tags
        self.isFavorite = isFavorite
        self.distance = distance
        self.estimatedDuration = estimatedDuration
        self.createdAt = Date()
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.waypoints = []
        self.polylineData = nil
        self.sessions = []
    }

    public var sortedWaypoints: [Waypoint] {
        waypoints.sorted { $0.index < $1.index }
    }

    public var sessionCount: Int {
        sessions.count
    }

    public var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
}
```

- [ ] **Step 6: Create Waypoint model**

Create `WalkableKit/Sources/WalkableKit/Models/Waypoint.swift`:

```swift
import Foundation
import SwiftData
import CoreLocation

@Model
public final class Waypoint {
    public var id: UUID
    public var index: Int
    public var latitude: Double
    public var longitude: Double
    public var label: String?
    public var route: Route?

    public init(index: Int, latitude: Double, longitude: Double, label: String? = nil) {
        self.id = UUID()
        self.index = index
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
```

- [ ] **Step 7: Create WalkSession model**

Create `WalkableKit/Sources/WalkableKit/Models/WalkSession.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class WalkSession {
    public var id: UUID
    public var route: Route?
    public var startedAt: Date
    public var completedAt: Date?
    public var totalDistance: Double
    public var totalDuration: TimeInterval
    public var calories: Double
    public var elevationGain: Double
    public var avgPace: Double
    public var healthKitWorkoutID: UUID?
    public var gpsTrackData: Data?
    @Relationship(deleteRule: .cascade, inverse: \LegSplit.session)
    public var legSplits: [LegSplit]

    public init(route: Route) {
        self.id = UUID()
        self.route = route
        self.startedAt = Date()
        self.completedAt = nil
        self.totalDistance = 0
        self.totalDuration = 0
        self.calories = 0
        self.elevationGain = 0
        self.avgPace = 0
        self.healthKitWorkoutID = nil
        self.gpsTrackData = nil
        self.legSplits = []
    }

    public var sortedLegSplits: [LegSplit] {
        legSplits.sorted { $0.fromWaypointIndex < $1.fromWaypointIndex }
    }

    public var formattedPace: String {
        guard avgPace > 0 else { return "--:--" }
        let minutes = Int(avgPace) / 60
        let seconds = Int(avgPace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}
```

- [ ] **Step 8: Create LegSplit model**

Create `WalkableKit/Sources/WalkableKit/Models/LegSplit.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class LegSplit {
    public var id: UUID
    public var session: WalkSession?
    public var fromWaypointIndex: Int
    public var toWaypointIndex: Int
    public var distance: Double
    public var duration: TimeInterval
    public var pace: Double

    public init(
        session: WalkSession,
        fromWaypointIndex: Int,
        toWaypointIndex: Int,
        distance: Double,
        duration: TimeInterval,
        pace: Double
    ) {
        self.id = UUID()
        self.session = session
        self.fromWaypointIndex = fromWaypointIndex
        self.toWaypointIndex = toWaypointIndex
        self.distance = distance
        self.duration = duration
        self.pace = pace
    }

    public var formattedPace: String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}
```

- [ ] **Step 9: Remove placeholder file**

Delete `WalkableKit/Sources/WalkableKit/WalkableKit.swift` (no longer needed, models serve as package content).

- [ ] **Step 10: Run tests**

Run: `xcodebuild test -project Walkable.xcodeproj -scheme WalkableTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Expected: All tests pass

- [ ] **Step 11: Commit**

```bash
git add WalkableKit/Sources/WalkableKit/Models/ WalkableKit/Sources/WalkableKit/Extensions/ WalkableTests/ModelTests.swift
git commit -m "feat: add SwiftData models and coordinate encoding helpers"
```

---

### Task 3: RoutingService — Core Routing

**Files:**
- Create: `WalkableKit/Sources/WalkableKit/Services/RoutingService.swift`
- Create: `WalkableTests/RoutingServiceTests.swift`

- [ ] **Step 1: Write routing service tests**

Create `WalkableTests/RoutingServiceTests.swift`:

```swift
import Testing
import Foundation
import CoreLocation
import MapKit
@testable import WalkableKit

@Suite("RoutingService")
struct RoutingServiceTests {

    @Test("Cache key generation is deterministic")
    func cacheKeyDeterministic() {
        let a = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let b = CLLocationCoordinate2D(latitude: 40.7138, longitude: -74.0070)
        let key1 = RoutingService.cacheKey(from: a, to: b)
        let key2 = RoutingService.cacheKey(from: a, to: b)
        #expect(key1 == key2)
    }

    @Test("Cache key differs for different coordinates")
    func cacheKeyDiffers() {
        let a = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let b = CLLocationCoordinate2D(latitude: 40.7138, longitude: -74.0070)
        let c = CLLocationCoordinate2D(latitude: 40.7148, longitude: -74.0080)
        let key1 = RoutingService.cacheKey(from: a, to: b)
        let key2 = RoutingService.cacheKey(from: a, to: c)
        #expect(key1 != key2)
    }

    @Test("Cache key is order-sensitive")
    func cacheKeyOrderSensitive() {
        let a = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let b = CLLocationCoordinate2D(latitude: 40.7138, longitude: -74.0070)
        let key1 = RoutingService.cacheKey(from: a, to: b)
        let key2 = RoutingService.cacheKey(from: b, to: a)
        #expect(key1 != key2)
    }

    @Test("Segment pairs from waypoints creates a loop")
    func segmentPairsLoop() {
        let coords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
            CLLocationCoordinate2D(latitude: 2, longitude: 2)
        ]
        let pairs = RoutingService.segmentPairs(from: coords)
        #expect(pairs.count == 3) // 0->1, 1->2, 2->0
        // Last pair connects back to first
        #expect(pairs[2].to.latitude == coords[0].latitude)
    }

    @Test("Segment pairs requires at least 2 waypoints")
    func segmentPairsMinimum() {
        let one = [CLLocationCoordinate2D(latitude: 0, longitude: 0)]
        let pairs = RoutingService.segmentPairs(from: one)
        #expect(pairs.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Walkable.xcodeproj -scheme WalkableTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Expected: Compilation errors (RoutingService doesn't exist)

- [ ] **Step 3: Implement RoutingService**

Create `WalkableKit/Sources/WalkableKit/Services/RoutingService.swift`:

```swift
import MapKit
import CoreLocation

public struct SegmentPair {
    public let from: CLLocationCoordinate2D
    public let to: CLLocationCoordinate2D
}

public struct CalculatedRoute {
    public let polyline: MKPolyline
    public let distance: CLLocationDistance
    public let expectedTravelTime: TimeInterval
    public let segmentPolylines: [MKPolyline]
}

public final class RoutingService {
    public static let shared = RoutingService()

    private var cache: [String: MKRoute] = [:]

    private init() {}

    /// Generate a deterministic cache key from two coordinates.
    /// Rounds to 5 decimal places (~1m precision) for stable hashing.
    public static func cacheKey(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> String {
        let precision = 100000.0
        let fLat = (from.latitude * precision).rounded() / precision
        let fLng = (from.longitude * precision).rounded() / precision
        let tLat = (to.latitude * precision).rounded() / precision
        let tLng = (to.longitude * precision).rounded() / precision
        return "\(fLat),\(fLng)->\(tLat),\(tLng)"
    }

    /// Generate segment pairs for a loop: each consecutive pair + last back to first.
    public static func segmentPairs(from coordinates: [CLLocationCoordinate2D]) -> [SegmentPair] {
        guard coordinates.count >= 2 else { return [] }
        var pairs = [SegmentPair]()
        for i in 0..<coordinates.count {
            let next = (i + 1) % coordinates.count
            pairs.append(SegmentPair(from: coordinates[i], to: coordinates[next]))
        }
        return pairs
    }

    /// Calculate walking route for a single segment. Uses cache if available.
    public func calculateSegment(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> MKRoute {
        let key = Self.cacheKey(from: from, to: to)

        if let cached = cache[key] {
            return cached
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RoutingError.noRouteFound
        }

        cache[key] = route
        return route
    }

    /// Calculate a complete walking loop through all waypoints.
    /// Calls MKDirections sequentially with a delay to respect rate limits.
    public func calculateLoop(through coordinates: [CLLocationCoordinate2D]) async throws -> CalculatedRoute {
        let pairs = Self.segmentPairs(from: coordinates)
        guard !pairs.isEmpty else {
            throw RoutingError.insufficientWaypoints
        }

        var segmentRoutes = [MKRoute]()
        for (index, pair) in pairs.enumerated() {
            let route = try await calculateSegment(from: pair.from, to: pair.to)
            segmentRoutes.append(route)

            // Rate limit delay between requests (skip after last)
            if index < pairs.count - 1 {
                try await Task.sleep(for: .seconds(1))
            }
        }

        let stitched = stitchPolylines(segmentRoutes.map { $0.polyline })
        let totalDistance = segmentRoutes.reduce(0) { $0 + $1.distance }
        let totalTime = segmentRoutes.reduce(0) { $0 + $1.expectedTravelTime }

        return CalculatedRoute(
            polyline: stitched,
            distance: totalDistance,
            expectedTravelTime: totalTime,
            segmentPolylines: segmentRoutes.map { $0.polyline }
        )
    }

    /// Invalidate cached segment for a specific pair (used when user moves a pin).
    public func invalidateCache(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        let key = Self.cacheKey(from: from, to: to)
        cache.removeValue(forKey: key)
    }

    /// Clear entire cache.
    public func clearCache() {
        cache.removeAll()
    }

    /// Stitch multiple polylines into one continuous polyline.
    private func stitchPolylines(_ polylines: [MKPolyline]) -> MKPolyline {
        var allCoords = [CLLocationCoordinate2D]()
        for polyline in polylines {
            let points = polyline.points()
            for i in 0..<polyline.pointCount {
                allCoords.append(points[i].coordinate)
            }
        }
        return MKPolyline(coordinates: allCoords, count: allCoords.count)
    }
}

public enum RoutingError: Error, LocalizedError {
    case noRouteFound
    case insufficientWaypoints

    public var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "No walking route found between those points."
        case .insufficientWaypoints:
            return "At least 2 waypoints are needed to calculate a route."
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `xcodebuild test -project Walkable.xcodeproj -scheme WalkableTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add WalkableKit/Sources/WalkableKit/Services/RoutingService.swift WalkableTests/RoutingServiceTests.swift
git commit -m "feat: add RoutingService with MKDirections loop calculation and caching"
```

---

### Task 4: PathSimplifier & TemplateGenerator

**Files:**
- Create: `WalkableKit/Sources/WalkableKit/Services/PathSimplifier.swift`
- Create: `WalkableKit/Sources/WalkableKit/Services/TemplateGenerator.swift`
- Create: `WalkableTests/PathSimplifierTests.swift`
- Create: `WalkableTests/TemplateGeneratorTests.swift`

- [ ] **Step 1: Write PathSimplifier tests**

Create `WalkableTests/PathSimplifierTests.swift`:

```swift
import Testing
import Foundation
import CoreLocation
@testable import WalkableKit

@Suite("PathSimplifier")
struct PathSimplifierTests {

    @Test("Douglas-Peucker reduces points on a straight line")
    func straightLineSimplification() {
        // Points along a straight line should simplify to just endpoints
        let points = (0...10).map {
            CLLocationCoordinate2D(latitude: Double($0) * 0.001, longitude: 0)
        }
        let simplified = PathSimplifier.simplify(points, tolerance: 0.0001)
        #expect(simplified.count == 2) // just start and end
    }

    @Test("Douglas-Peucker keeps points on a curve")
    func curveKeepsPoints() {
        // L-shaped path: should keep the corner
        let points = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0.001),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0.002),
        ]
        let simplified = PathSimplifier.simplify(points, tolerance: 0.00005)
        #expect(simplified.count >= 3) // at least start, corner, end
        #expect(simplified.count <= 5)
    }

    @Test("Sample waypoints at interval")
    func sampleWaypoints() {
        // Create a path roughly 1km long (0.01 degrees ~ 1.1km at equator)
        let points = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.005, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0),
        ]
        // Sample every 200m along a ~1.1km path should give ~5-6 points
        let sampled = PathSimplifier.sampleWaypoints(along: points, intervalMeters: 200)
        #expect(sampled.count >= 3)
        #expect(sampled.count <= 8)
    }

    @Test("Sample waypoints always includes first and last")
    func sampleIncludesEndpoints() {
        let points = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0),
        ]
        let sampled = PathSimplifier.sampleWaypoints(along: points, intervalMeters: 200)
        #expect(sampled.first!.latitude == 0)
        #expect(abs(sampled.last!.latitude - 0.01) < 0.001)
    }

    @Test("Empty input returns empty")
    func emptyInput() {
        let simplified = PathSimplifier.simplify([], tolerance: 0.001)
        #expect(simplified.isEmpty)
        let sampled = PathSimplifier.sampleWaypoints(along: [], intervalMeters: 200)
        #expect(sampled.isEmpty)
    }
}
```

- [ ] **Step 2: Write TemplateGenerator tests**

Create `WalkableTests/TemplateGeneratorTests.swift`:

```swift
import Testing
import Foundation
import CoreLocation
@testable import WalkableKit

@Suite("TemplateGenerator")
struct TemplateGeneratorTests {

    let center = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

    @Test("Loop generates correct number of waypoints")
    func loopWaypointCount() {
        let waypoints = TemplateGenerator.loop(center: center, targetDistanceMeters: 2000)
        // 2km loop, waypoints every ~200m = ~10 points
        #expect(waypoints.count >= 6)
        #expect(waypoints.count <= 15)
    }

    @Test("Loop waypoints form a rough circle around center")
    func loopFormation() {
        let waypoints = TemplateGenerator.loop(center: center, targetDistanceMeters: 2000)
        // All points should be roughly equidistant from center
        let distances = waypoints.map { distance(from: center, to: $0) }
        let avgDist = distances.reduce(0, +) / Double(distances.count)
        for d in distances {
            #expect(abs(d - avgDist) / avgDist < 0.15) // within 15% of average
        }
    }

    @Test("Out and back generates symmetric waypoints")
    func outAndBack() {
        let waypoints = TemplateGenerator.outAndBack(center: center, targetDistanceMeters: 2000, bearingDegrees: 0)
        #expect(waypoints.count >= 4)
        // First and last should be close to center
        let firstDist = distance(from: center, to: waypoints.first!)
        let lastDist = distance(from: center, to: waypoints.last!)
        #expect(firstDist < 50) // within 50m of center
        #expect(lastDist < 50)
    }

    @Test("Figure-8 generates two loops worth of waypoints")
    func figure8() {
        let waypoints = TemplateGenerator.figure8(center: center, targetDistanceMeters: 3000)
        // Should have more waypoints than a simple loop of same distance
        let loopWaypoints = TemplateGenerator.loop(center: center, targetDistanceMeters: 3000)
        #expect(waypoints.count >= loopWaypoints.count)
    }

    // Helper: distance between two coords in meters
    private func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -project Walkable.xcodeproj -scheme WalkableTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Expected: Compilation errors

- [ ] **Step 4: Implement PathSimplifier**

Create `WalkableKit/Sources/WalkableKit/Services/PathSimplifier.swift`:

```swift
import CoreLocation

public enum PathSimplifier {

    /// Douglas-Peucker line simplification algorithm.
    /// Removes points that are within `tolerance` degrees of the line between endpoints.
    public static func simplify(
        _ points: [CLLocationCoordinate2D],
        tolerance: Double
    ) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }

        // Find the point with the maximum distance from the line between first and last
        var maxDistance = 0.0
        var maxIndex = 0

        let first = points[0]
        let last = points[points.count - 1]

        for i in 1..<(points.count - 1) {
            let d = perpendicularDistance(point: points[i], lineStart: first, lineEnd: last)
            if d > maxDistance {
                maxDistance = d
                maxIndex = i
            }
        }

        if maxDistance > tolerance {
            let left = simplify(Array(points[0...maxIndex]), tolerance: tolerance)
            let right = simplify(Array(points[maxIndex...]), tolerance: tolerance)
            // Merge, removing duplicate at junction
            return Array(left.dropLast()) + right
        } else {
            return [first, last]
        }
    }

    /// Sample waypoints at regular distance intervals along a path.
    /// Always includes the first and last point.
    public static func sampleWaypoints(
        along points: [CLLocationCoordinate2D],
        intervalMeters: Double
    ) -> [CLLocationCoordinate2D] {
        guard points.count >= 2 else { return points }

        var sampled = [points[0]]
        var accumulatedDistance = 0.0

        for i in 1..<points.count {
            let segmentDistance = metersDistance(from: points[i - 1], to: points[i])
            accumulatedDistance += segmentDistance

            if accumulatedDistance >= intervalMeters {
                sampled.append(points[i])
                accumulatedDistance = 0
            }
        }

        // Always include the last point
        let last = points[points.count - 1]
        if let lastSampled = sampled.last,
           metersDistance(from: lastSampled, to: last) > 10 {
            sampled.append(last)
        }

        return sampled
    }

    /// Perpendicular distance from a point to a line (in degrees, for simplification).
    private static func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude

        if dx == 0 && dy == 0 {
            // lineStart == lineEnd
            let pdx = point.longitude - lineStart.longitude
            let pdy = point.latitude - lineStart.latitude
            return sqrt(pdx * pdx + pdy * pdy)
        }

        let t = ((point.longitude - lineStart.longitude) * dx + (point.latitude - lineStart.latitude) * dy) / (dx * dx + dy * dy)
        let clampedT = max(0, min(1, t))

        let closestLng = lineStart.longitude + clampedT * dx
        let closestLat = lineStart.latitude + clampedT * dy

        let distLng = point.longitude - closestLng
        let distLat = point.latitude - closestLat

        return sqrt(distLng * distLng + distLat * distLat)
    }

    private static func metersDistance(
        from a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D
    ) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
```

- [ ] **Step 5: Implement TemplateGenerator**

Create `WalkableKit/Sources/WalkableKit/Services/TemplateGenerator.swift`:

```swift
import CoreLocation

public enum TemplateGenerator {

    /// Generate waypoints for a circular loop around a center point.
    /// Places waypoints every ~200m along the circle circumference.
    public static func loop(
        center: CLLocationCoordinate2D,
        targetDistanceMeters: Double
    ) -> [CLLocationCoordinate2D] {
        let radiusMeters = targetDistanceMeters / (2 * .pi)
        let waypointCount = max(6, Int(targetDistanceMeters / 200))

        var waypoints = [CLLocationCoordinate2D]()
        for i in 0..<waypointCount {
            let angle = (Double(i) / Double(waypointCount)) * 2 * .pi
            let point = coordinateAt(
                center: center,
                distanceMeters: radiusMeters,
                bearingRadians: angle
            )
            waypoints.append(point)
        }
        return waypoints
    }

    /// Generate waypoints for an out-and-back route.
    /// Goes out for half the target distance, then mirrors waypoints back.
    public static func outAndBack(
        center: CLLocationCoordinate2D,
        targetDistanceMeters: Double,
        bearingDegrees: Double
    ) -> [CLLocationCoordinate2D] {
        let halfDistance = targetDistanceMeters / 2
        let bearingRad = bearingDegrees * .pi / 180
        let segmentCount = max(3, Int(halfDistance / 200))

        var outbound = [CLLocationCoordinate2D]()
        outbound.append(center)

        for i in 1...segmentCount {
            let dist = (Double(i) / Double(segmentCount)) * halfDistance
            let point = coordinateAt(center: center, distanceMeters: dist, bearingRadians: bearingRad)
            outbound.append(point)
        }

        // Mirror back (skip the turnaround point to avoid duplicate)
        let inbound = outbound.dropLast().reversed()
        return outbound + inbound
    }

    /// Generate waypoints for a figure-8 route.
    /// Two smaller loops sharing the center point.
    public static func figure8(
        center: CLLocationCoordinate2D,
        targetDistanceMeters: Double
    ) -> [CLLocationCoordinate2D] {
        let loopDistance = targetDistanceMeters / 2
        let radiusMeters = loopDistance / (2 * .pi)
        let pointsPerLoop = max(5, Int(loopDistance / 200))

        // Upper loop center (offset north)
        let upperCenter = coordinateAt(center: center, distanceMeters: radiusMeters, bearingRadians: 0)
        // Lower loop center (offset south)
        let lowerCenter = coordinateAt(center: center, distanceMeters: radiusMeters, bearingRadians: .pi)

        var waypoints = [CLLocationCoordinate2D]()

        // Upper loop (clockwise, starting from center/south of upper loop)
        for i in 0..<pointsPerLoop {
            let angle = .pi + (Double(i) / Double(pointsPerLoop)) * 2 * .pi
            let point = coordinateAt(center: upperCenter, distanceMeters: radiusMeters, bearingRadians: angle)
            waypoints.append(point)
        }

        // Lower loop (clockwise, starting from center/north of lower loop)
        for i in 0..<pointsPerLoop {
            let angle = (Double(i) / Double(pointsPerLoop)) * 2 * .pi
            let point = coordinateAt(center: lowerCenter, distanceMeters: radiusMeters, bearingRadians: angle)
            waypoints.append(point)
        }

        return waypoints
    }

    /// Calculate a coordinate at a given distance and bearing from a center point.
    /// Uses the Haversine formula inverse.
    private static func coordinateAt(
        center: CLLocationCoordinate2D,
        distanceMeters: Double,
        bearingRadians: Double
    ) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0 // meters
        let angularDistance = distanceMeters / earthRadius

        let lat1 = center.latitude * .pi / 180
        let lng1 = center.longitude * .pi / 180

        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(bearingRadians)
        )
        let lng2 = lng1 + atan2(
            sin(bearingRadians) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lng2 * 180 / .pi
        )
    }
}
```

- [ ] **Step 6: Run tests**

Run: `xcodebuild test -project Walkable.xcodeproj -scheme WalkableTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`

Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add WalkableKit/Sources/WalkableKit/Services/PathSimplifier.swift WalkableKit/Sources/WalkableKit/Services/TemplateGenerator.swift WalkableTests/PathSimplifierTests.swift WalkableTests/TemplateGeneratorTests.swift
git commit -m "feat: add Douglas-Peucker path simplifier and route template generators"
```

---

### Task 5: LocationService

**Files:**
- Create: `WalkableKit/Sources/WalkableKit/Services/LocationService.swift`

- [ ] **Step 1: Implement LocationService**

Create `WalkableKit/Sources/WalkableKit/Services/LocationService.swift`:

```swift
import CoreLocation
import Combine

public final class LocationService: NSObject, ObservableObject {
    public static let shared = LocationService()

    private let manager = CLLocationManager()

    @Published public var currentLocation: CLLocation?
    @Published public var heading: CLHeading?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Fires when user enters the proximity radius of a waypoint.
    /// Value is the index of the waypoint arrived at.
    public let waypointArrival = PassthroughSubject<Int, Never>()

    private var waypointCoordinates: [CLLocationCoordinate2D] = []
    private var arrivedWaypoints: Set<Int> = []
    private let arrivalRadiusMeters: Double = 25

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    public func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    public func startTracking() {
        manager.startUpdatingLocation()
    }

    public func stopTracking() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    public func startHeadingUpdates() {
        manager.startUpdatingHeading()
    }

    public func stopHeadingUpdates() {
        manager.stopUpdatingHeading()
    }

    /// Set waypoints to monitor for proximity arrival during a walk.
    public func monitorWaypoints(_ coordinates: [CLLocationCoordinate2D]) {
        waypointCoordinates = coordinates
        arrivedWaypoints.removeAll()
    }

    /// Clear waypoint monitoring.
    public func clearWaypointMonitoring() {
        waypointCoordinates.removeAll()
        arrivedWaypoints.removeAll()
    }

    /// Check if current location is within arrival radius of any unvisited waypoint.
    private func checkWaypointProximity(_ location: CLLocation) {
        for (index, coord) in waypointCoordinates.enumerated() {
            guard !arrivedWaypoints.contains(index) else { continue }
            let waypointLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if location.distance(from: waypointLocation) <= arrivalRadiusMeters {
                arrivedWaypoints.insert(index)
                waypointArrival.send(index)
            }
        }
    }

    /// Bearing from current location to a target coordinate, in degrees (0 = north, clockwise).
    public func bearing(to target: CLLocationCoordinate2D) -> Double? {
        guard let current = currentLocation?.coordinate else { return nil }

        let lat1 = current.latitude * .pi / 180
        let lat2 = target.latitude * .pi / 180
        let dLng = (target.longitude - current.longitude) * .pi / 180

        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)

        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return bearing
    }

    /// Distance from current location to a target coordinate, in meters.
    public func distance(to target: CLLocationCoordinate2D) -> Double? {
        guard let current = currentLocation else { return nil }
        return current.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
    }
}

extension LocationService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        checkWaypointProximity(location)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add WalkableKit/Sources/WalkableKit/Services/LocationService.swift
git commit -m "feat: add LocationService with GPS tracking, heading, and waypoint proximity"
```

---

### Task 6: HealthService

**Files:**
- Create: `WalkableKit/Sources/WalkableKit/Services/HealthService.swift`

- [ ] **Step 1: Implement HealthService**

Create `WalkableKit/Sources/WalkableKit/Services/HealthService.swift`:

```swift
import HealthKit
import CoreLocation
import Combine

public final class HealthService: ObservableObject {
    public static let shared = HealthService()

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?

    @Published public var isAuthorized = false
    @Published public var heartRate: Double = 0
    @Published public var activeCalories: Double = 0
    @Published public var distanceWalked: Double = 0
    @Published public var currentPace: Double = 0 // sec/km

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Authorization

    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.walkingSpeed),
            HKQuantityType(.flightsClimbed),
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
        await MainActor.run { isAuthorized = true }
    }

    // MARK: - Workout Session

    public func startWalkingWorkout() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .walking
        config.locationType = .outdoor

        session = try HKWorkoutSession(healthStore: store, configuration: config)
        builder = session?.associatedWorkoutBuilder()
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

        session?.delegate = self
        builder?.delegate = self

        let startDate = Date()
        session?.startActivity(with: startDate)
        try await builder?.beginCollection(at: startDate)

        routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
    }

    public func pauseWorkout() {
        session?.pause()
    }

    public func resumeWorkout() {
        session?.resume()
    }

    public func endWorkout() async throws -> HKWorkout? {
        session?.end()
        try await builder?.endCollection(at: Date())

        guard let builder else { return nil }
        let workout = try await builder.finishWorkout()

        // Finish the route and attach it to the workout
        if let routeBuilder {
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }

        self.session = nil
        self.builder = nil
        self.routeBuilder = nil

        return workout
    }

    /// Add a GPS location to the workout route.
    public func addRouteLocation(_ location: CLLocation) {
        routeBuilder?.insertRouteData([location]) { _ in }
    }

    // MARK: - Stats Queries

    /// Get total walking distance for a date range.
    public func totalDistance(from startDate: Date, to endDate: Date) async throws -> Double {
        try await querySum(type: HKQuantityType(.distanceWalkingRunning), from: startDate, to: endDate, unit: .meter())
    }

    /// Get total calories burned from walking workouts in a date range.
    public func totalCalories(from startDate: Date, to endDate: Date) async throws -> Double {
        try await querySum(type: HKQuantityType(.activeEnergyBurned), from: startDate, to: endDate, unit: .kilocalorie())
    }

    /// Count consecutive days (ending today) with a walking workout.
    public func currentStreak() async throws -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today

        while true {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!
            let hasWorkout = try await hasWalkingWorkout(from: checkDate, to: nextDay)
            if hasWorkout {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        return streak
    }

    private func hasWalkingWorkout(from startDate: Date, to endDate: Date) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForWorkouts(with: .walking)
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])

            let query = HKSampleQuery(sampleType: .workoutType(), predicate: compound, limit: 1, sortDescriptors: nil) { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (results?.count ?? 0) > 0)
            }
            store.execute(query)
        }
    }

    private func querySum(type: HKQuantityType, from startDate: Date, to endDate: Date, unit: HKUnit) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}

extension HealthService: HKWorkoutSessionDelegate {
    public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}

    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

extension HealthService: HKLiveWorkoutBuilderDelegate {
    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            switch quantityType {
            case HKQuantityType(.heartRate):
                if let stats = workoutBuilder.statistics(for: quantityType) {
                    let bpm = stats.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                    Task { @MainActor in self.heartRate = bpm }
                }
            case HKQuantityType(.activeEnergyBurned):
                if let stats = workoutBuilder.statistics(for: quantityType) {
                    let cals = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    Task { @MainActor in self.activeCalories = cals }
                }
            case HKQuantityType(.distanceWalkingRunning):
                if let stats = workoutBuilder.statistics(for: quantityType) {
                    let meters = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                    Task { @MainActor in self.distanceWalked = meters }
                }
            default:
                break
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add WalkableKit/Sources/WalkableKit/Services/HealthService.swift
git commit -m "feat: add HealthService with workout sessions, route tracking, and stats queries"
```

---

### Task 7: SyncService (WatchConnectivity)

**Files:**
- Create: `WalkableKit/Sources/WalkableKit/Services/SyncService.swift`

- [ ] **Step 1: Implement SyncService**

Create `WalkableKit/Sources/WalkableKit/Services/SyncService.swift`:

```swift
import WatchConnectivity
import SwiftData
import Combine

public enum SyncOperation: String, Codable {
    case create, update, delete
}

public struct SyncPayload: Codable {
    public let operation: SyncOperation
    public let routeId: String
    public let name: String?
    public let distance: Double?
    public let estimatedDuration: TimeInterval?
    public let waypoints: [SyncWaypoint]?
    public let polylineCoordinates: [CodableCoordinate]?

    public init(
        operation: SyncOperation,
        routeId: String,
        name: String? = nil,
        distance: Double? = nil,
        estimatedDuration: TimeInterval? = nil,
        waypoints: [SyncWaypoint]? = nil,
        polylineCoordinates: [CodableCoordinate]? = nil
    ) {
        self.operation = operation
        self.routeId = routeId
        self.name = name
        self.distance = distance
        self.estimatedDuration = estimatedDuration
        self.waypoints = waypoints
        self.polylineCoordinates = polylineCoordinates
    }
}

public struct SyncWaypoint: Codable {
    public let index: Int
    public let latitude: Double
    public let longitude: Double
    public let label: String?

    public init(index: Int, latitude: Double, longitude: Double, label: String? = nil) {
        self.index = index
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
    }
}

public struct SessionSyncPayload: Codable {
    public let routeId: String
    public let startedAt: Date
    public let completedAt: Date
    public let totalDistance: Double
    public let totalDuration: TimeInterval
    public let calories: Double
    public let elevationGain: Double
    public let avgPace: Double
    public let legSplits: [SyncLegSplit]
}

public struct SyncLegSplit: Codable {
    public let fromWaypointIndex: Int
    public let toWaypointIndex: Int
    public let distance: Double
    public let duration: TimeInterval
    public let pace: Double
}

public final class SyncService: NSObject, ObservableObject {
    public static let shared = SyncService()

    @Published public var isReachable = false

    /// Called on the receiving side when a route sync arrives.
    public let routeSyncReceived = PassthroughSubject<SyncPayload, Never>()

    /// Called on the phone when a walk session arrives from the watch.
    public let sessionSyncReceived = PassthroughSubject<SessionSyncPayload, Never>()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Send Route to Watch

    public func syncRoute(_ route: Route, operation: SyncOperation) {
        let waypoints = route.sortedWaypoints.map {
            SyncWaypoint(index: $0.index, latitude: $0.latitude, longitude: $0.longitude, label: $0.label)
        }

        var polylineCoords: [CodableCoordinate]?
        if let data = route.polylineData {
            polylineCoords = try? JSONDecoder().decode([CodableCoordinate].self, from: data)
        }

        let payload = SyncPayload(
            operation: operation,
            routeId: route.id.uuidString,
            name: route.name,
            distance: route.distance,
            estimatedDuration: route.estimatedDuration,
            waypoints: waypoints,
            polylineCoordinates: polylineCoords
        )

        guard let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        WCSession.default.transferUserInfo(["routeSync": dict])
    }

    /// Set the currently active route for quick-launch on Watch.
    public func setActiveRoute(_ route: Route?) {
        var context: [String: Any] = [:]
        if let route {
            context["activeRouteId"] = route.id.uuidString
            context["activeRouteName"] = route.name
        }
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Send Walk Session to Phone (from Watch)

    public func syncWalkSession(_ payload: SessionSyncPayload) {
        guard let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        WCSession.default.transferUserInfo(["sessionSync": dict])
    }
}

extension SyncService: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let routeDict = userInfo["routeSync"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: routeDict),
           let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) {
            routeSyncReceived.send(payload)
        }

        if let sessionDict = userInfo["sessionSync"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: sessionDict),
           let payload = try? JSONDecoder().decode(SessionSyncPayload.self, from: data) {
            sessionSyncReceived.send(payload)
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }
}
```

- [ ] **Step 2: Build both targets**

Run:
```bash
xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
xcodebuild -project Walkable.xcodeproj -scheme WalkableWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build 2>&1 | tail -5
```

Expected: Both `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add WalkableKit/Sources/WalkableKit/Services/SyncService.swift
git commit -m "feat: add SyncService with WatchConnectivity route and session sync"
```

---

### Task 8: Shared UI Components

**Files:**
- Create: `WalkableApp/Views/Shared/GlassButton.swift`
- Create: `WalkableApp/Views/Shared/GlassCard.swift`
- Create: `WalkableApp/Views/Shared/RouteMapOverlay.swift`

- [ ] **Step 1: Create GlassButton**

Create `WalkableApp/Views/Shared/GlassButton.swift`:

```swift
import SwiftUI

struct GlassButton: View {
    let systemImage: String
    let action: () -> Void
    var size: CGFloat = 44
    var tint: Color = .primary

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}

struct GlassButtonLabel: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    var tint: Color = .primary

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}
```

- [ ] **Step 2: Create GlassCard**

Create `WalkableApp/Views/Shared/GlassCard.swift`:

```swift
import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}
```

- [ ] **Step 3: Create RouteMapOverlay**

Create `WalkableApp/Views/Shared/RouteMapOverlay.swift`:

```swift
import SwiftUI
import MapKit
import WalkableKit

struct RouteMapOverlay: View {
    let route: Route
    var walkedDistance: Double? = nil
    var currentLocation: CLLocationCoordinate2D? = nil
    var nextWaypointIndex: Int? = nil

    var body: some View {
        Map {
            // Full route polyline
            if let polylineData = route.polylineData,
               let polyline = try? MKPolyline.from(encodedData: polylineData) {
                MapPolyline(polyline)
                    .stroke(.blue, lineWidth: 4)
            }

            // Waypoint annotations
            ForEach(route.sortedWaypoints, id: \.id) { waypoint in
                Annotation(
                    waypoint.label ?? "Waypoint \(waypoint.index + 1)",
                    coordinate: waypoint.coordinate
                ) {
                    waypointMarker(for: waypoint)
                }
            }

            // Current position
            if let current = currentLocation {
                Annotation("You", coordinate: current) {
                    Circle()
                        .fill(.green)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 4)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    @ViewBuilder
    private func waypointMarker(for waypoint: Waypoint) -> some View {
        let isNext = waypoint.index == nextWaypointIndex
        ZStack {
            Circle()
                .fill(isNext ? Color.orange : Color.blue)
                .frame(width: isNext ? 20 : 14, height: isNext ? 20 : 14)
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: isNext ? 20 : 14, height: isNext ? 20 : 14)
            if isNext {
                Text("\(waypoint.index + 1)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }
        }
        .shadow(radius: 2)
    }
}
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add WalkableApp/Views/Shared/
git commit -m "feat: add glass button, glass card, and route map overlay shared components"
```

---

### Task 9: Create Tab — Pin Mode

**Files:**
- Create: `WalkableApp/Views/Create/CreateRouteView.swift`
- Create: `WalkableApp/Views/Create/PinModeOverlay.swift`
- Create: `WalkableApp/Views/Create/SaveRouteSheet.swift`
- Create: `WalkableApp/ViewModels/CreateRouteViewModel.swift`

- [ ] **Step 1: Implement CreateRouteViewModel**

Create `WalkableApp/ViewModels/CreateRouteViewModel.swift`:

```swift
import SwiftUI
import MapKit
import SwiftData
import WalkableKit

enum RouteCreationMode: String, CaseIterable {
    case pin = "Pin"
    case draw = "Draw"
    case template = "Template"

    var icon: String {
        switch self {
        case .pin: return "mappin"
        case .draw: return "pencil.tip"
        case .template: return "square.on.square.dashed"
        }
    }
}

@Observable
final class CreateRouteViewModel {
    var mode: RouteCreationMode = .pin
    var waypoints: [CLLocationCoordinate2D] = []
    var calculatedRoute: CalculatedRoute?
    var isCalculating = false
    var errorMessage: String?
    var showSaveSheet = false

    // Save form fields
    var routeName = ""
    var routeTags = ""

    // Map camera
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    private let routingService = RoutingService.shared

    var canCalculate: Bool {
        waypoints.count >= 2
    }

    var hasRoute: Bool {
        calculatedRoute != nil
    }

    func addWaypoint(_ coordinate: CLLocationCoordinate2D) {
        waypoints.append(coordinate)
        calculatedRoute = nil
    }

    func undoLastWaypoint() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        calculatedRoute = nil
    }

    func clearAll() {
        waypoints.removeAll()
        calculatedRoute = nil
        errorMessage = nil
        routingService.clearCache()
    }

    func calculateRoute() async {
        guard canCalculate else { return }
        isCalculating = true
        errorMessage = nil

        do {
            calculatedRoute = try await routingService.calculateLoop(through: waypoints)
        } catch {
            errorMessage = error.localizedDescription
        }

        isCalculating = false
    }

    func saveRoute(modelContext: ModelContext) {
        guard let calculated = calculatedRoute else { return }

        let tags = routeTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let center = calculateCenter(of: waypoints)

        let route = Route(
            name: routeName.isEmpty ? "New Route" : routeName,
            tags: tags,
            distance: calculated.distance,
            estimatedDuration: calculated.expectedTravelTime,
            centerLatitude: center.latitude,
            centerLongitude: center.longitude
        )

        for (index, coord) in waypoints.enumerated() {
            let wp = Waypoint(index: index, latitude: coord.latitude, longitude: coord.longitude)
            route.waypoints.append(wp)
        }

        route.polylineData = try? calculated.polyline.encodedData()

        modelContext.insert(route)
        try? modelContext.save()

        SyncService.shared.syncRoute(route, operation: .create)

        // Reset state
        clearAll()
        routeName = ""
        routeTags = ""
        showSaveSheet = false
    }

    /// Set waypoints directly (used by draw mode and templates).
    func setWaypoints(_ coords: [CLLocationCoordinate2D]) {
        waypoints = coords
        calculatedRoute = nil
    }

    private func calculateCenter(of coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coords.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        let sumLat = coords.reduce(0) { $0 + $1.latitude }
        let sumLng = coords.reduce(0) { $0 + $1.longitude }
        return CLLocationCoordinate2D(
            latitude: sumLat / Double(coords.count),
            longitude: sumLng / Double(coords.count)
        )
    }
}
```

- [ ] **Step 2: Implement CreateRouteView**

Create `WalkableApp/Views/Create/CreateRouteView.swift`:

```swift
import SwiftUI
import MapKit
import WalkableKit

struct CreateRouteView: View {
    @State private var viewModel = CreateRouteViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            // Full-screen map
            mapView

            // Top controls
            VStack {
                modeSelector
                    .padding(.top, 8)
                Spacer()
            }

            // Bottom controls (mode-specific)
            VStack {
                Spacer()
                bottomControls
            }

            // Loading overlay
            if viewModel.isCalculating {
                calculatingOverlay
            }
        }
        .sheet(isPresented: $viewModel.showSaveSheet) {
            SaveRouteSheet(viewModel: viewModel, modelContext: modelContext)
                .presentationDetents([.medium])
        }
        .alert("Routing Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $viewModel.cameraPosition) {
                // Waypoint pins
                ForEach(Array(viewModel.waypoints.enumerated()), id: \.offset) { index, coord in
                    Annotation("", coordinate: coord) {
                        ZStack {
                            Circle()
                                .fill(index == 0 ? Color.red : Color.blue)
                                .frame(width: 16, height: 16)
                            Circle()
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 16, height: 16)
                            Text("\(index + 1)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(radius: 2)
                    }
                }

                // Calculated route polyline
                if let route = viewModel.calculatedRoute {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .onTapGesture { screenCoord in
                guard viewModel.mode == .pin, !viewModel.isCalculating else { return }
                if let mapCoord = proxy.convert(screenCoord, from: .local) {
                    viewModel.addWaypoint(mapCoord)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(RouteCreationMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.mode = mode
                    }
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(viewModel.mode == mode ? .white : .primary)
                        .background(
                            viewModel.mode == mode
                                ? AnyShapeStyle(.blue)
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                }
            }
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    @ViewBuilder
    private var bottomControls: some View {
        switch viewModel.mode {
        case .pin:
            PinModeOverlay(viewModel: viewModel)
        case .draw:
            DrawModeOverlay(viewModel: viewModel)
        case .template:
            TemplateModeOverlay(viewModel: viewModel)
        }
    }

    private var calculatingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Calculating route...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
}
```

- [ ] **Step 3: Implement PinModeOverlay**

Create `WalkableApp/Views/Create/PinModeOverlay.swift`:

```swift
import SwiftUI

struct PinModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Waypoint count hint
            if viewModel.waypoints.isEmpty {
                Text("Tap the map to place waypoints")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            } else {
                Text("\(viewModel.waypoints.count) waypoints")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            HStack(spacing: 12) {
                if !viewModel.waypoints.isEmpty {
                    GlassButtonLabel(title: "Undo", systemImage: "arrow.uturn.backward") {
                        viewModel.undoLastWaypoint()
                    }
                }

                if viewModel.waypoints.count >= 2 {
                    GlassButtonLabel(title: "Clear", systemImage: "trash", action: {
                        viewModel.clearAll()
                    }, tint: .red)
                }

                if viewModel.canCalculate && !viewModel.hasRoute {
                    GlassButtonLabel(title: "Calculate", systemImage: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath", action: {
                        Task { await viewModel.calculateRoute() }
                    }, tint: .green)
                }

                if viewModel.hasRoute {
                    GlassButtonLabel(title: "Save", systemImage: "square.and.arrow.down", action: {
                        viewModel.showSaveSheet = true
                    }, tint: .blue)
                }
            }
        }
        .padding(.bottom, 24)
    }
}
```

- [ ] **Step 4: Implement SaveRouteSheet**

Create `WalkableApp/Views/Create/SaveRouteSheet.swift`:

```swift
import SwiftUI
import SwiftData

struct SaveRouteSheet: View {
    @Bindable var viewModel: CreateRouteViewModel
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Route name", text: $viewModel.routeName)
                    TextField("Tags (comma separated)", text: $viewModel.routeTags)
                }

                if let route = viewModel.calculatedRoute {
                    Section("Route Info") {
                        LabeledContent("Distance") {
                            Text(String(format: "%.1f km", route.distance / 1000))
                        }
                        LabeledContent("Est. Time") {
                            Text(formatDuration(route.expectedTravelTime))
                        }
                        LabeledContent("Waypoints") {
                            Text("\(viewModel.waypoints.count)")
                        }
                    }
                }
            }
            .navigationTitle("Save Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveRoute(modelContext: modelContext)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        return "\(hours)h \(remaining)m"
    }
}
```

- [ ] **Step 5: Create placeholder Draw and Template overlays** (implemented in next tasks)

Create `WalkableApp/Views/Create/DrawModeOverlay.swift`:

```swift
import SwiftUI

struct DrawModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel

    var body: some View {
        Text("Draw mode — coming soon")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 24)
    }
}
```

Create `WalkableApp/Views/Create/TemplateModeOverlay.swift`:

```swift
import SwiftUI

struct TemplateModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel

    var body: some View {
        Text("Template mode — coming soon")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 24)
    }
}
```

- [ ] **Step 6: Wire up ContentView with Create tab**

Update `WalkableApp/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CreateRouteView()
                .tabItem {
                    Label("Create", systemImage: "map")
                }
            Text("Library")
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            Text("Walk")
                .tabItem {
                    Label("Walk", systemImage: "figure.walk")
                }
            Text("Stats")
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
    }
}
```

- [ ] **Step 7: Build and run on simulator**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add WalkableApp/Views/ WalkableApp/ViewModels/ WalkableApp/ContentView.swift
git commit -m "feat: add Create tab with pin mode route builder and save sheet"
```

---

### Task 10: Create Tab — Draw Mode

**Files:**
- Modify: `WalkableApp/Views/Create/DrawModeOverlay.swift`
- Create: `WalkableApp/Views/Create/DrawingCanvas.swift`
- Modify: `WalkableApp/Views/Create/CreateRouteView.swift`

- [ ] **Step 1: Create DrawingCanvas (UIViewRepresentable for freehand drawing)**

Create `WalkableApp/Views/Create/DrawingCanvas.swift`:

```swift
import SwiftUI
import MapKit

struct DrawingCanvas: UIViewRepresentable {
    @Binding var isDrawing: Bool
    var onDrawingComplete: ([CGPoint]) -> Void

    func makeUIView(context: Context) -> DrawingCanvasUIView {
        let view = DrawingCanvasUIView()
        view.onDrawingComplete = onDrawingComplete
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        return view
    }

    func updateUIView(_ uiView: DrawingCanvasUIView, context: Context) {
        uiView.isUserInteractionEnabled = isDrawing
    }
}

class DrawingCanvasUIView: UIView {
    var onDrawingComplete: (([CGPoint]) -> Void)?
    private var points: [CGPoint] = []
    private var currentPath = UIBezierPath()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        points.removeAll()
        currentPath = UIBezierPath()
        let point = touch.location(in: self)
        points.append(point)
        currentPath.move(to: point)
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        points.append(point)
        currentPath.addLine(to: point)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Close the loop by connecting back to start
        if let first = points.first {
            points.append(first)
            currentPath.addLine(to: first)
            currentPath.close()
        }
        setNeedsDisplay()
        onDrawingComplete?(points)
    }

    override func draw(_ rect: CGRect) {
        UIColor.systemBlue.withAlphaComponent(0.6).setStroke()
        currentPath.lineWidth = 4
        currentPath.lineCapStyle = .round
        currentPath.lineJoinStyle = .round
        currentPath.stroke()

        UIColor.systemBlue.withAlphaComponent(0.1).setFill()
        currentPath.fill()
    }

    func clear() {
        points.removeAll()
        currentPath = UIBezierPath()
        setNeedsDisplay()
    }
}
```

- [ ] **Step 2: Implement DrawModeOverlay**

Replace `WalkableApp/Views/Create/DrawModeOverlay.swift`:

```swift
import SwiftUI
import MapKit
import WalkableKit

struct DrawModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel
    @State private var isDrawing = true
    @State private var drawnPoints: [CGPoint] = []
    @State private var mapProxy: MapProxy?

    var body: some View {
        ZStack {
            // Drawing canvas overlay (only when actively drawing)
            if isDrawing && !viewModel.hasRoute {
                DrawingCanvas(isDrawing: $isDrawing) { points in
                    drawnPoints = points
                }
                .allowsHitTesting(isDrawing)
            }

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    if viewModel.waypoints.isEmpty && drawnPoints.isEmpty {
                        Text("Draw a loop on the map with your finger")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    HStack(spacing: 12) {
                        if !drawnPoints.isEmpty || !viewModel.waypoints.isEmpty {
                            GlassButtonLabel(title: "Clear", systemImage: "trash") {
                                drawnPoints.removeAll()
                                viewModel.clearAll()
                                isDrawing = true
                            }
                            .tint(.red)
                        }

                        if !drawnPoints.isEmpty && viewModel.waypoints.isEmpty {
                            GlassButtonLabel(title: "Snap to Roads", systemImage: "road.lanes", action: {
                                convertDrawingToWaypoints()
                            }, tint: .green)
                        }

                        if viewModel.canCalculate && !viewModel.hasRoute {
                            GlassButtonLabel(title: "Calculate", systemImage: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath", action: {
                                Task { await viewModel.calculateRoute() }
                            }, tint: .green)
                        }

                        if viewModel.hasRoute {
                            GlassButtonLabel(title: "Save", systemImage: "square.and.arrow.down", action: {
                                viewModel.showSaveSheet = true
                            }, tint: .blue)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func convertDrawingToWaypoints() {
        // Convert screen points to coordinates would need MapProxy,
        // but for now we use a simplified approach:
        // The drawn points are in screen coordinates. We need the MapReader proxy
        // to convert them. This is wired up through CreateRouteView.
        // For now, use PathSimplifier on the points as a 2D approximation.

        guard drawnPoints.count >= 3 else { return }

        // Simplify the screen-space points first
        let coordPoints = drawnPoints.map {
            CLLocationCoordinate2D(latitude: Double($0.y), longitude: Double($0.x))
        }
        let simplified = PathSimplifier.simplify(coordPoints, tolerance: 20)
        let sampled = PathSimplifier.sampleWaypoints(along: simplified, intervalMeters: 50)

        // This needs proper screen-to-map coordinate conversion
        // which will be connected via the MapReader proxy in CreateRouteView
        viewModel.setWaypoints(sampled.map { $0 })
        isDrawing = false
    }
}
```

- [ ] **Step 3: Update CreateRouteView to handle draw mode map interaction**

In `WalkableApp/Views/Create/CreateRouteView.swift`, replace the `mapView` property to support draw mode. The full `CreateRouteView` is unchanged except adding `@State private var mapProxy: MapProxy?` and passing it through. The core map interaction already works — taps for pin mode, and the DrawingCanvas overlays for draw mode.

The screen-to-coordinate conversion for draw mode needs the MapReader proxy. Update the `onTapGesture` block:

In `CreateRouteView.swift`, update the `mapView` property's MapReader to store the proxy for draw mode conversion. Replace the entire `mapView` computed property:

```swift
    @State private var storedMapProxy: MapProxy?

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $viewModel.cameraPosition) {
                ForEach(Array(viewModel.waypoints.enumerated()), id: \.offset) { index, coord in
                    Annotation("", coordinate: coord) {
                        ZStack {
                            Circle()
                                .fill(index == 0 ? Color.red : Color.blue)
                                .frame(width: 16, height: 16)
                            Circle()
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 16, height: 16)
                            Text("\(index + 1)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(radius: 2)
                    }
                }

                if let route = viewModel.calculatedRoute {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .onTapGesture { screenCoord in
                guard viewModel.mode == .pin, !viewModel.isCalculating else { return }
                if let mapCoord = proxy.convert(screenCoord, from: .local) {
                    viewModel.addWaypoint(mapCoord)
                }
            }
            .onAppear { storedMapProxy = proxy }
        }
        .ignoresSafeArea()
    }
```

- [ ] **Step 4: Build**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add WalkableApp/Views/Create/
git commit -m "feat: add draw mode with freehand canvas and path simplification"
```

---

### Task 11: Create Tab — Template Mode

**Files:**
- Modify: `WalkableApp/Views/Create/TemplateModeOverlay.swift`

- [ ] **Step 1: Implement TemplateModeOverlay**

Replace `WalkableApp/Views/Create/TemplateModeOverlay.swift`:

```swift
import SwiftUI
import CoreLocation
import WalkableKit

enum TemplateShape: String, CaseIterable {
    case loop = "Loop"
    case outAndBack = "Out & Back"
    case figure8 = "Figure-8"

    var icon: String {
        switch self {
        case .loop: return "circle"
        case .outAndBack: return "arrow.left.arrow.right"
        case .figure8: return "infinity"
        }
    }
}

struct TemplateModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel
    @State private var selectedShape: TemplateShape = .loop
    @State private var targetDistanceKm: Double = 2.0

    private let locationService = LocationService.shared

    var body: some View {
        VStack(spacing: 12) {
            // Shape picker
            HStack(spacing: 8) {
                ForEach(TemplateShape.allCases, id: \.self) { shape in
                    Button {
                        selectedShape = shape
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: shape.icon)
                                .font(.title3)
                            Text(shape.rawValue)
                                .font(.caption2)
                        }
                        .frame(width: 80, height: 56)
                        .foregroundStyle(selectedShape == shape ? .white : .primary)
                        .background(
                            selectedShape == shape
                                ? AnyShapeStyle(.blue)
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            // Distance slider
            VStack(spacing: 4) {
                Text(String(format: "%.1f km", targetDistanceKm))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Slider(value: $targetDistanceKm, in: 0.5...10, step: 0.5)
                    .tint(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            // Generate button
            HStack(spacing: 12) {
                GlassButtonLabel(title: "Generate", systemImage: "wand.and.stars", action: {
                    generateTemplate()
                }, tint: .green)

                if viewModel.canCalculate && !viewModel.hasRoute {
                    GlassButtonLabel(title: "Calculate", systemImage: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath", action: {
                        Task { await viewModel.calculateRoute() }
                    }, tint: .green)
                }

                if viewModel.hasRoute {
                    GlassButtonLabel(title: "Save", systemImage: "square.and.arrow.down", action: {
                        viewModel.showSaveSheet = true
                    }, tint: .blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func generateTemplate() {
        guard let location = locationService.currentLocation?.coordinate else {
            viewModel.errorMessage = "Need your location to generate a template. Make sure location access is enabled."
            return
        }

        let distanceMeters = targetDistanceKm * 1000

        let waypoints: [CLLocationCoordinate2D]
        switch selectedShape {
        case .loop:
            waypoints = TemplateGenerator.loop(center: location, targetDistanceMeters: distanceMeters)
        case .outAndBack:
            waypoints = TemplateGenerator.outAndBack(center: location, targetDistanceMeters: distanceMeters, bearingDegrees: 0)
        case .figure8:
            waypoints = TemplateGenerator.figure8(center: location, targetDistanceMeters: distanceMeters)
        }

        viewModel.setWaypoints(waypoints)
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add WalkableApp/Views/Create/TemplateModeOverlay.swift
git commit -m "feat: add template mode with loop, out-and-back, and figure-8 generators"
```

---

### Task 12: Library Tab

**Files:**
- Create: `WalkableApp/Views/Library/LibraryView.swift`
- Create: `WalkableApp/Views/Library/RouteCardView.swift`
- Create: `WalkableApp/Views/Library/RouteDetailSheet.swift`
- Create: `WalkableApp/Views/Library/LibraryMapView.swift`
- Create: `WalkableApp/ViewModels/LibraryViewModel.swift`
- Modify: `WalkableApp/ContentView.swift`

- [ ] **Step 1: Implement LibraryViewModel**

Create `WalkableApp/ViewModels/LibraryViewModel.swift`:

```swift
import SwiftUI
import SwiftData
import CoreLocation
import WalkableKit

enum RouteSortOption: String, CaseIterable {
    case dateCreated = "Date"
    case distance = "Distance"
    case timesWalked = "Times Walked"
    case nearest = "Nearest"
}

@Observable
final class LibraryViewModel {
    var searchText = ""
    var selectedTag: String? = nil
    var sortOption: RouteSortOption = .dateCreated
    var showMapView = false
    var selectedRoute: Route?

    func filteredRoutes(_ routes: [Route], currentLocation: CLLocation?) -> [Route] {
        var result = routes

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Tag filter
        if let tag = selectedTag {
            if tag == "Favorites" {
                result = result.filter { $0.isFavorite }
            } else {
                result = result.filter { $0.tags.contains(tag) }
            }
        }

        // Sort
        switch sortOption {
        case .dateCreated:
            result.sort { $0.createdAt > $1.createdAt }
        case .distance:
            result.sort { $0.distance < $1.distance }
        case .timesWalked:
            result.sort { $0.sessionCount > $1.sessionCount }
        case .nearest:
            if let loc = currentLocation {
                result.sort {
                    let d0 = loc.distance(from: CLLocation(latitude: $0.centerLatitude, longitude: $0.centerLongitude))
                    let d1 = loc.distance(from: CLLocation(latitude: $1.centerLatitude, longitude: $1.centerLongitude))
                    return d0 < d1
                }
            }
        }

        return result
    }

    func allTags(_ routes: [Route]) -> [String] {
        var tags = Set<String>()
        for route in routes {
            tags.formUnion(route.tags)
        }
        return ["Favorites"] + tags.sorted()
    }

    func toggleFavorite(_ route: Route) {
        route.isFavorite.toggle()
        SyncService.shared.syncRoute(route, operation: .update)
    }

    func deleteRoute(_ route: Route, modelContext: ModelContext) {
        SyncService.shared.syncRoute(route, operation: .delete)
        modelContext.delete(route)
        try? modelContext.save()
    }
}
```

- [ ] **Step 2: Implement RouteCardView**

Create `WalkableApp/Views/Library/RouteCardView.swift`:

```swift
import SwiftUI
import WalkableKit

struct RouteCardView: View {
    let route: Route

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(route.name)
                    .font(.headline)
                if route.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                Spacer()
                Text(String(format: "%.1f km", route.distance / 1000))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label(formatDuration(route.estimatedDuration), systemImage: "clock")
                Label("\(route.waypoints.count) waypoints", systemImage: "mappin.and.ellipse")
                Label("Walked \(route.sessionCount)x", systemImage: "figure.walk")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !route.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(route.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "~\(minutes) min" }
        return "~\(minutes / 60)h \(minutes % 60)m"
    }
}
```

- [ ] **Step 3: Implement RouteDetailSheet**

Create `WalkableApp/Views/Library/RouteDetailSheet.swift`:

```swift
import SwiftUI
import MapKit
import WalkableKit

struct RouteDetailSheet: View {
    let route: Route
    let onStartWalk: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Map preview
                RouteMapOverlay(route: route)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()

                // Route info
                VStack(spacing: 16) {
                    HStack {
                        StatPill(label: "Distance", value: String(format: "%.1f km", route.distance / 1000))
                        StatPill(label: "Est. Time", value: formatDuration(route.estimatedDuration))
                        StatPill(label: "Waypoints", value: "\(route.waypoints.count)")
                    }
                    .padding(.horizontal)

                    Button {
                        dismiss()
                        onStartWalk()
                    } label: {
                        Label("Start Walk", systemImage: "figure.walk")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle(route.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "~\(minutes) min" }
        return "~\(minutes / 60)h \(minutes % 60)m"
    }
}

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 4: Implement LibraryView**

Create `WalkableApp/Views/Library/LibraryView.swift`:

```swift
import SwiftUI
import SwiftData
import WalkableKit

struct LibraryView: View {
    @Query private var routes: [Route]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    @ObservedObject private var locationService = LocationService.shared

    // Callback when user starts a walk from library
    var onStartWalk: ((Route) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tag filter chips
                if !viewModel.allTags(routes).isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            tagChip("All", isSelected: viewModel.selectedTag == nil) {
                                viewModel.selectedTag = nil
                            }
                            ForEach(viewModel.allTags(routes), id: \.self) { tag in
                                tagChip(tag, isSelected: viewModel.selectedTag == tag) {
                                    viewModel.selectedTag = viewModel.selectedTag == tag ? nil : tag
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }

                // Route list
                let filtered = viewModel.filteredRoutes(routes, currentLocation: locationService.currentLocation)

                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Routes",
                        systemImage: "map",
                        description: Text("Create your first walking loop in the Create tab")
                    )
                } else {
                    List {
                        ForEach(filtered) { route in
                            RouteCardView(route: route)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .onTapGesture {
                                    viewModel.selectedRoute = route
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        viewModel.toggleFavorite(route)
                                    } label: {
                                        Label(
                                            route.isFavorite ? "Unfavorite" : "Favorite",
                                            systemImage: route.isFavorite ? "star.slash" : "star.fill"
                                        )
                                    }
                                    .tint(.yellow)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        viewModel.deleteRoute(route, modelContext: modelContext)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
            .searchable(text: $viewModel.searchText, prompt: "Search routes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(RouteSortOption.allCases, id: \.self) { option in
                            Button {
                                viewModel.sortOption = option
                            } label: {
                                Label(option.rawValue, systemImage: viewModel.sortOption == option ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(item: $viewModel.selectedRoute) { route in
                RouteDetailSheet(route: route) {
                    onStartWalk?(route)
                }
                .presentationDetents([.large])
            }
        }
    }

    private func tagChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? Color.blue : Color.clear)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
}
```

- [ ] **Step 5: Wire Library into ContentView**

Update `WalkableApp/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CreateRouteView()
                .tabItem {
                    Label("Create", systemImage: "map")
                }
                .tag(0)
            LibraryView { route in
                // TODO: start walk with route (Task 14)
                selectedTab = 2
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            .tag(1)
            Text("Walk")
                .tabItem {
                    Label("Walk", systemImage: "figure.walk")
                }
                .tag(2)
            Text("Stats")
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(3)
        }
    }
}
```

- [ ] **Step 6: Build**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add WalkableApp/Views/Library/ WalkableApp/ViewModels/LibraryViewModel.swift WalkableApp/ContentView.swift
git commit -m "feat: add Library tab with search, tags, sort, and route detail sheet"
```

---

### Task 13: Active Walk Tab

**Files:**
- Create: `WalkableApp/Views/Walk/ActiveWalkView.swift`
- Create: `WalkableApp/Views/Walk/WalkStatsBar.swift`
- Create: `WalkableApp/Views/Walk/WaypointArrivalCard.swift`
- Create: `WalkableApp/Views/Walk/WalkSummaryView.swift`
- Create: `WalkableApp/ViewModels/ActiveWalkViewModel.swift`
- Modify: `WalkableApp/ContentView.swift`

- [ ] **Step 1: Implement ActiveWalkViewModel**

Create `WalkableApp/ViewModels/ActiveWalkViewModel.swift`:

```swift
import SwiftUI
import MapKit
import Combine
import SwiftData
import WalkableKit

@Observable
final class ActiveWalkViewModel {
    var route: Route?
    var isWalking = false
    var isPaused = false
    var showSummary = false

    // Live stats
    var elapsedTime: TimeInterval = 0
    var distanceWalked: Double = 0
    var currentPace: Double = 0
    var calories: Double = 0

    // Waypoint tracking
    var currentWaypointIndex = 0
    var arrivedWaypointMessage: String?
    var showArrivalCard = false

    // GPS track for saving
    var gpsLocations: [CLLocation] = []
    var waypointArrivalTimes: [Int: Date] = [:]

    private var timer: Timer?
    private var startTime: Date?
    private var cancellables = Set<AnyCancellable>()

    private let locationService = LocationService.shared
    private let healthService = HealthService.shared

    var nextWaypointCoordinate: CLLocationCoordinate2D? {
        guard let route, currentWaypointIndex < route.sortedWaypoints.count else { return nil }
        return route.sortedWaypoints[currentWaypointIndex].coordinate
    }

    var distanceToNextWaypoint: Double? {
        guard let coord = nextWaypointCoordinate else { return nil }
        return locationService.distance(to: coord)
    }

    func startWalk(with route: Route) async {
        self.route = route
        isWalking = true
        isPaused = false
        currentWaypointIndex = 0
        elapsedTime = 0
        distanceWalked = 0
        calories = 0
        gpsLocations.removeAll()
        waypointArrivalTimes.removeAll()
        startTime = Date()

        // Set up waypoint monitoring
        let coords = route.sortedWaypoints.map { $0.coordinate }
        locationService.monitorWaypoints(coords)
        locationService.startTracking()

        // Listen for waypoint arrivals
        locationService.waypointArrival
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                self?.handleWaypointArrival(index)
            }
            .store(in: &cancellables)

        // Track GPS locations
        locationService.$currentLocation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.gpsLocations.append(location)
                self?.distanceWalked = self?.healthService.distanceWalked ?? 0
                self?.calories = self?.healthService.activeCalories ?? 0
                self?.healthService.addRouteLocation(location)
            }
            .store(in: &cancellables)

        // Start health workout
        try? await healthService.startWalkingWorkout()

        // Timer for elapsed time
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, !self.isPaused, let start = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
            if self.distanceWalked > 0 {
                self.currentPace = self.elapsedTime / (self.distanceWalked / 1000) // sec/km
            }
        }

        SyncService.shared.setActiveRoute(route)
    }

    func pauseWalk() {
        isPaused = true
        healthService.pauseWorkout()
    }

    func resumeWalk() {
        isPaused = false
        healthService.resumeWorkout()
    }

    func endWalk(modelContext: ModelContext) async {
        timer?.invalidate()
        timer = nil
        locationService.stopTracking()
        locationService.clearWaypointMonitoring()
        cancellables.removeAll()

        let workout = try? await healthService.endWorkout()

        // Save walk session
        if let route {
            let session = WalkSession(route: route)
            session.completedAt = Date()
            session.totalDistance = distanceWalked
            session.totalDuration = elapsedTime
            session.calories = calories
            session.avgPace = distanceWalked > 0 ? elapsedTime / (distanceWalked / 1000) : 0
            session.healthKitWorkoutID = workout?.uuid

            // Encode GPS track
            let coords = gpsLocations.map { CodableCoordinate($0.coordinate) }
            session.gpsTrackData = try? JSONEncoder().encode(coords)

            // Calculate leg splits
            let sortedWaypoints = route.sortedWaypoints
            for i in 0..<(sortedWaypoints.count) {
                let nextIndex = (i + 1) % sortedWaypoints.count
                if let arriveTime = waypointArrivalTimes[i],
                   let nextArriveTime = waypointArrivalTimes[nextIndex] {
                    let duration = nextArriveTime.timeIntervalSince(arriveTime)
                    let wpA = sortedWaypoints[i].coordinate
                    let wpB = sortedWaypoints[nextIndex].coordinate
                    let dist = CLLocation(latitude: wpA.latitude, longitude: wpA.longitude)
                        .distance(from: CLLocation(latitude: wpB.latitude, longitude: wpB.longitude))
                    let pace = dist > 0 ? duration / (dist / 1000) : 0

                    let split = LegSplit(
                        session: session,
                        fromWaypointIndex: i,
                        toWaypointIndex: nextIndex,
                        distance: dist,
                        duration: duration,
                        pace: pace
                    )
                    session.legSplits.append(split)
                }
            }

            modelContext.insert(session)
            try? modelContext.save()
        }

        isWalking = false
        showSummary = true
        SyncService.shared.setActiveRoute(nil)
    }

    func dismissSummary() {
        showSummary = false
        route = nil
        elapsedTime = 0
        distanceWalked = 0
        calories = 0
        currentPace = 0
    }

    private func handleWaypointArrival(_ index: Int) {
        currentWaypointIndex = index + 1
        waypointArrivalTimes[index] = Date()

        guard let route else { return }
        let wp = route.sortedWaypoints[index]
        arrivedWaypointMessage = wp.label ?? "Waypoint \(index + 1)"
        showArrivalCard = true

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showArrivalCard = false
        }
    }
}
```

- [ ] **Step 2: Implement WalkStatsBar**

Create `WalkableApp/Views/Walk/WalkStatsBar.swift`:

```swift
import SwiftUI

struct WalkStatsBar: View {
    let distance: Double // meters
    let elapsed: TimeInterval
    let pace: Double // sec/km
    let calories: Double

    var body: some View {
        HStack {
            statItem(label: "DISTANCE", value: String(format: "%.2f km", distance / 1000))
            Divider().frame(height: 30)
            statItem(label: "TIME", value: formatTime(elapsed))
            Divider().frame(height: 30)
            statItem(label: "PACE", value: formatPace(pace))
            Divider().frame(height: 30)
            statItem(label: "CAL", value: String(format: "%.0f", calories))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace < 3600 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
```

- [ ] **Step 3: Implement WaypointArrivalCard**

Create `WalkableApp/Views/Walk/WaypointArrivalCard.swift`:

```swift
import SwiftUI

struct WaypointArrivalCard: View {
    let waypointName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("Waypoint Reached!")
                    .font(.subheadline.weight(.semibold))
                Text(waypointName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
```

- [ ] **Step 4: Implement WalkSummaryView**

Create `WalkableApp/Views/Walk/WalkSummaryView.swift`:

```swift
import SwiftUI

struct WalkSummaryView: View {
    let distance: Double
    let duration: TimeInterval
    let pace: Double
    let calories: Double
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("Walk Complete!")
                    .font(.title.weight(.bold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    summaryCard("Distance", value: String(format: "%.2f km", distance / 1000), icon: "ruler")
                    summaryCard("Duration", value: formatDuration(duration), icon: "clock")
                    summaryCard("Avg Pace", value: formatPace(pace), icon: "speedometer")
                    summaryCard("Calories", value: String(format: "%.0f kcal", calories), icon: "flame")
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
            }
            .padding(.top, 40)
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func summaryCard(_ label: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace < 3600 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }
}
```

- [ ] **Step 5: Implement ActiveWalkView**

Create `WalkableApp/Views/Walk/ActiveWalkView.swift`:

```swift
import SwiftUI
import MapKit
import WalkableKit

struct ActiveWalkView: View {
    @Bindable var viewModel: ActiveWalkViewModel
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var locationService = LocationService.shared

    var body: some View {
        ZStack {
            if viewModel.isWalking, let route = viewModel.route {
                // Map with route
                RouteMapOverlay(
                    route: route,
                    walkedDistance: viewModel.distanceWalked,
                    currentLocation: locationService.currentLocation?.coordinate,
                    nextWaypointIndex: viewModel.currentWaypointIndex
                )
                .ignoresSafeArea()

                // Stats and controls overlay
                VStack {
                    // Waypoint arrival notification
                    if viewModel.showArrivalCard, let msg = viewModel.arrivedWaypointMessage {
                        WaypointArrivalCard(waypointName: msg)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }

                    Spacer()

                    // Stats bar
                    WalkStatsBar(
                        distance: viewModel.distanceWalked,
                        elapsed: viewModel.elapsedTime,
                        pace: viewModel.currentPace,
                        calories: viewModel.calories
                    )
                    .padding(.horizontal)

                    // Controls
                    HStack(spacing: 20) {
                        GlassButtonLabel(
                            title: viewModel.isPaused ? "Resume" : "Pause",
                            systemImage: viewModel.isPaused ? "play.fill" : "pause.fill"
                        ) {
                            if viewModel.isPaused {
                                viewModel.resumeWalk()
                            } else {
                                viewModel.pauseWalk()
                            }
                        }

                        GlassButtonLabel(title: "End Walk", systemImage: "stop.fill", action: {
                            Task { await viewModel.endWalk(modelContext: modelContext) }
                        }, tint: .red)
                    }
                    .padding(.bottom, 24)
                }
            } else {
                // No active walk
                ContentUnavailableView(
                    "No Active Walk",
                    systemImage: "figure.walk",
                    description: Text("Start a walk from your Library to begin tracking")
                )
            }
        }
        .sheet(isPresented: $viewModel.showSummary) {
            WalkSummaryView(
                distance: viewModel.distanceWalked,
                duration: viewModel.elapsedTime,
                pace: viewModel.currentPace,
                calories: viewModel.calories,
                onDismiss: { viewModel.dismissSummary() }
            )
            .interactiveDismissDisabled()
        }
    }
}
```

- [ ] **Step 6: Wire Active Walk into ContentView**

Update `WalkableApp/ContentView.swift`:

```swift
import SwiftUI
import WalkableKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var walkViewModel = ActiveWalkViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            CreateRouteView()
                .tabItem {
                    Label("Create", systemImage: "map")
                }
                .tag(0)
            LibraryView { route in
                Task {
                    await walkViewModel.startWalk(with: route)
                    selectedTab = 2
                }
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            .tag(1)
            ActiveWalkView(viewModel: walkViewModel)
                .tabItem {
                    Label("Walk", systemImage: "figure.walk")
                }
                .tag(2)
            Text("Stats")
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(3)
        }
        .onAppear {
            LocationService.shared.requestAuthorization()
            Task { try? await HealthService.shared.requestAuthorization() }
        }
    }
}
```

- [ ] **Step 7: Build**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add WalkableApp/Views/Walk/ WalkableApp/ViewModels/ActiveWalkViewModel.swift WalkableApp/ContentView.swift
git commit -m "feat: add Active Walk tab with live tracking, stats bar, and walk summary"
```

---

### Task 14: Stats Tab

**Files:**
- Create: `WalkableApp/Views/Stats/StatsView.swift`
- Create: `WalkableApp/Views/Stats/StatCardView.swift`
- Create: `WalkableApp/Views/Stats/PaceTrendChart.swift`
- Create: `WalkableApp/Views/Stats/RouteLeaderboard.swift`
- Create: `WalkableApp/ViewModels/StatsViewModel.swift`
- Modify: `WalkableApp/ContentView.swift`

- [ ] **Step 1: Implement StatsViewModel**

Create `WalkableApp/ViewModels/StatsViewModel.swift`:

```swift
import SwiftUI
import SwiftData
import WalkableKit

enum StatsPeriod: String, CaseIterable {
    case weekly = "Week"
    case monthly = "Month"
}

@Observable
final class StatsViewModel {
    var period: StatsPeriod = .weekly
    var totalDistance: Double = 0
    var totalWalks: Int = 0
    var avgPace: Double = 0
    var totalCalories: Double = 0
    var elevationGain: Double = 0
    var currentStreak: Int = 0
    var isLoading = false

    var dateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        switch period {
        case .weekly:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        case .monthly:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return (start, now)
        }
    }

    func loadStats(sessions: [WalkSession]) async {
        isLoading = true

        let range = dateRange
        let filtered = sessions.filter { session in
            session.startedAt >= range.start && session.startedAt <= range.end
        }

        totalWalks = filtered.count
        totalDistance = filtered.reduce(0) { $0 + $1.totalDistance }
        totalCalories = filtered.reduce(0) { $0 + $1.calories }
        elevationGain = filtered.reduce(0) { $0 + $1.elevationGain }

        let totalTime = filtered.reduce(0.0) { $0 + $1.totalDuration }
        avgPace = totalDistance > 0 ? totalTime / (totalDistance / 1000) : 0

        currentStreak = (try? await HealthService.shared.currentStreak()) ?? 0

        isLoading = false
    }

    func paceData(sessions: [WalkSession]) -> [(date: Date, pace: Double)] {
        let range = dateRange
        return sessions
            .filter { $0.startedAt >= range.start && $0.startedAt <= range.end && $0.avgPace > 0 }
            .sorted { $0.startedAt < $1.startedAt }
            .map { (date: $0.startedAt, pace: $0.avgPace) }
    }

    func routeBestTimes(routes: [Route]) -> [(route: Route, bestPace: Double, sessions: Int)] {
        routes.compactMap { route in
            let sessions = route.sessions
            guard !sessions.isEmpty else { return nil }
            let best = sessions.filter { $0.avgPace > 0 }.min(by: { $0.avgPace < $1.avgPace })
            guard let bestPace = best?.avgPace else { return nil }
            return (route: route, bestPace: bestPace, sessions: sessions.count)
        }
        .sorted { $0.bestPace < $1.bestPace }
    }
}
```

- [ ] **Step 2: Implement StatCardView**

Create `WalkableApp/Views/Stats/StatCardView.swift`:

```swift
import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 3: Implement PaceTrendChart**

Create `WalkableApp/Views/Stats/PaceTrendChart.swift`:

```swift
import SwiftUI
import Charts

struct PaceTrendChart: View {
    let data: [(date: Date, pace: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pace Trend")
                .font(.headline)

            if data.isEmpty {
                Text("No pace data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(data, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Pace", item.pace / 60) // convert to min/km
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Pace", item.pace / 60)
                    )
                    .foregroundStyle(.blue)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let pace = value.as(Double.self) {
                            AxisValueLabel {
                                Text(String(format: "%.0f min", pace))
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 4: Implement RouteLeaderboard**

Create `WalkableApp/Views/Stats/RouteLeaderboard.swift`:

```swift
import SwiftUI
import WalkableKit

struct RouteLeaderboard: View {
    let entries: [(route: Route, bestPace: Double, sessions: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route Best Times")
                .font(.headline)

            if entries.isEmpty {
                Text("Complete some walks to see your best times")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries, id: \.route.id) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.route.name)
                                .font(.subheadline.weight(.medium))
                            Text("\(entry.sessions) walks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatPace(entry.bestPace))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)
                    if entry.route.id != entries.last?.route.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }
}
```

- [ ] **Step 5: Implement StatsView**

Create `WalkableApp/Views/Stats/StatsView.swift`:

```swift
import SwiftUI
import SwiftData
import WalkableKit

struct StatsView: View {
    @Query private var sessions: [WalkSession]
    @Query private var routes: [Route]
    @State private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Period picker
                    Picker("Period", selection: $viewModel.period) {
                        ForEach(StatsPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Streak
                    if viewModel.currentStreak > 0 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(viewModel.currentStreak) day streak!")
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Stat cards grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCardView(
                            title: "Total Distance",
                            value: String(format: "%.1f km", viewModel.totalDistance / 1000),
                            icon: "ruler",
                            color: .blue
                        )
                        StatCardView(
                            title: "Total Walks",
                            value: "\(viewModel.totalWalks)",
                            icon: "figure.walk",
                            color: .green
                        )
                        StatCardView(
                            title: "Avg Pace",
                            value: formatPace(viewModel.avgPace),
                            icon: "speedometer",
                            color: .purple
                        )
                        StatCardView(
                            title: "Calories",
                            value: String(format: "%.0f kcal", viewModel.totalCalories),
                            icon: "flame",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    // Pace trend chart
                    PaceTrendChart(data: viewModel.paceData(sessions: sessions))
                        .padding(.horizontal)

                    // Route leaderboard
                    RouteLeaderboard(entries: viewModel.routeBestTimes(routes: routes))
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Stats")
            .task { await viewModel.loadStats(sessions: sessions) }
            .onChange(of: viewModel.period) {
                Task { await viewModel.loadStats(sessions: sessions) }
            }
        }
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }
}
```

- [ ] **Step 6: Wire Stats into ContentView**

In `WalkableApp/ContentView.swift`, replace the `Text("Stats")` placeholder:

```swift
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(3)
```

- [ ] **Step 7: Build**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add WalkableApp/Views/Stats/ WalkableApp/ViewModels/StatsViewModel.swift WalkableApp/ContentView.swift
git commit -m "feat: add Stats tab with dashboard, pace chart, streak, and route leaderboard"
```

---

### Task 15: Watch App — Route List & Walk Setup

**Files:**
- Modify: `WalkableWatch/WalkableWatchApp.swift`
- Create: `WalkableWatch/Views/RouteListView.swift`
- Create: `WalkableWatch/ViewModels/WatchRouteListViewModel.swift`

- [ ] **Step 1: Implement WatchRouteListViewModel**

Create `WalkableWatch/ViewModels/WatchRouteListViewModel.swift`:

```swift
import SwiftUI
import SwiftData
import Combine
import WalkableKit

@Observable
final class WatchRouteListViewModel {
    var routes: [Route] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Listen for route syncs from phone
        SyncService.shared.routeSyncReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] payload in
                self?.handleRouteSync(payload)
            }
            .store(in: &cancellables)
    }

    func loadRoutes(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Route>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        routes = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func handleRouteSync(_ payload: SyncPayload) {
        // Route sync is handled at the SwiftData level via SyncService.
        // The view will refresh automatically via @Query or manual fetch.
    }
}
```

- [ ] **Step 2: Implement RouteListView**

Create `WalkableWatch/Views/RouteListView.swift`:

```swift
import SwiftUI
import SwiftData
import WalkableKit

struct RouteListView: View {
    @Query(sort: \Route.createdAt, order: .reverse) private var routes: [Route]
    var onSelectRoute: (Route) -> Void

    var body: some View {
        NavigationStack {
            if routes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Routes")
                        .font(.headline)
                    Text("Create routes on your iPhone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                List(routes) { route in
                    Button {
                        onSelectRoute(route)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(route.name)
                                .font(.headline)
                            HStack {
                                Text(String(format: "%.1f km", route.distance / 1000))
                                Text("·")
                                Text("\(route.waypoints.count) pts")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Update WalkableWatchApp entry point**

Replace `WalkableWatch/WalkableWatchApp.swift`:

```swift
import SwiftUI
import SwiftData
import WalkableKit

@main
struct WalkableWatchApp: App {
    @State private var selectedRoute: Route?
    @State private var isWalking = false

    var body: some Scene {
        WindowGroup {
            if isWalking, let route = selectedRoute {
                WalkTabView(route: route) {
                    isWalking = false
                    selectedRoute = nil
                }
            } else if let route = selectedRoute {
                // Pre-walk confirmation
                VStack(spacing: 12) {
                    Text(route.name)
                        .font(.headline)
                    Text(String(format: "%.1f km · %d waypoints", route.distance / 1000, route.waypoints.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        isWalking = true
                    } label: {
                        Label("Start Walk", systemImage: "figure.walk")
                    }
                    .tint(.green)
                    Button("Back") {
                        selectedRoute = nil
                    }
                }
            } else {
                RouteListView { route in
                    selectedRoute = route
                }
            }
        }
        .modelContainer(for: [Route.self, Waypoint.self, WalkSession.self, LegSplit.self])
    }
}
```

- [ ] **Step 4: Create placeholder WalkTabView** (implemented next task)

Create `WalkableWatch/Views/WalkTabView.swift`:

```swift
import SwiftUI
import WalkableKit

struct WalkTabView: View {
    let route: Route
    let onEnd: () -> Void

    var body: some View {
        Text("Walking...")
    }
}
```

- [ ] **Step 5: Build Watch target**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add WalkableWatch/
git commit -m "feat: add Watch route list and walk setup flow"
```

---

### Task 16: Watch App — Walk Views (Map, Compass, Now Playing)

**Files:**
- Modify: `WalkableWatch/Views/WalkTabView.swift`
- Create: `WalkableWatch/Views/WatchMapView.swift`
- Create: `WalkableWatch/Views/CompassView.swift`
- Create: `WalkableWatch/Views/NowPlayingView.swift`
- Create: `WalkableWatch/Views/WatchSummaryView.swift`
- Create: `WalkableWatch/ViewModels/WatchWalkViewModel.swift`

- [ ] **Step 1: Implement WatchWalkViewModel**

Create `WalkableWatch/ViewModels/WatchWalkViewModel.swift`:

```swift
import SwiftUI
import Combine
import CoreLocation
import WatchKit
import WalkableKit

@Observable
final class WatchWalkViewModel {
    let route: Route

    var isWalking = true
    var showSummary = false
    var elapsedTime: TimeInterval = 0
    var distanceWalked: Double = 0
    var currentWaypointIndex = 0

    var currentLocation: CLLocationCoordinate2D?
    var currentHeading: Double = 0

    private var timer: Timer?
    private var startTime = Date()
    private var cancellables = Set<AnyCancellable>()
    private var waypointArrivalTimes: [Int: Date] = [:]

    private let locationService = LocationService.shared
    private let healthService = HealthService.shared

    init(route: Route) {
        self.route = route
    }

    var nextWaypointCoordinate: CLLocationCoordinate2D? {
        let sorted = route.sortedWaypoints
        guard currentWaypointIndex < sorted.count else { return nil }
        return sorted[currentWaypointIndex].coordinate
    }

    var distanceToNextWaypoint: Double? {
        guard let coord = nextWaypointCoordinate else { return nil }
        return locationService.distance(to: coord)
    }

    var bearingToNextWaypoint: Double? {
        guard let coord = nextWaypointCoordinate else { return nil }
        return locationService.bearing(to: coord)
    }

    /// Relative bearing: subtract device heading from absolute bearing to get arrow direction.
    var relativeArrowAngle: Double {
        guard let bearing = bearingToNextWaypoint else { return 0 }
        return bearing - currentHeading
    }

    func startWalk() async {
        startTime = Date()
        let coords = route.sortedWaypoints.map { $0.coordinate }
        locationService.monitorWaypoints(coords)
        locationService.startTracking()
        locationService.startHeadingUpdates()

        locationService.waypointArrival
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                self?.handleWaypointArrival(index)
            }
            .store(in: &cancellables)

        locationService.$currentLocation
            .compactMap { $0?.coordinate }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coord in
                self?.currentLocation = coord
                self?.distanceWalked = self?.healthService.distanceWalked ?? 0
            }
            .store(in: &cancellables)

        locationService.$heading
            .compactMap { $0?.trueHeading }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heading in
                self?.currentHeading = heading
            }
            .store(in: &cancellables)

        try? await healthService.startWalkingWorkout()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedTime = Date().timeIntervalSince(self.startTime)
        }
    }

    func endWalk() async {
        timer?.invalidate()
        locationService.stopTracking()
        locationService.stopHeadingUpdates()
        locationService.clearWaypointMonitoring()
        cancellables.removeAll()

        _ = try? await healthService.endWorkout()

        // Sync session back to phone
        let payload = SessionSyncPayload(
            routeId: route.id.uuidString,
            startedAt: startTime,
            completedAt: Date(),
            totalDistance: distanceWalked,
            totalDuration: elapsedTime,
            calories: healthService.activeCalories,
            elevationGain: 0,
            avgPace: distanceWalked > 0 ? elapsedTime / (distanceWalked / 1000) : 0,
            legSplits: [] // Simplified for watch
        )
        SyncService.shared.syncWalkSession(payload)

        isWalking = false
        showSummary = true
    }

    private func handleWaypointArrival(_ index: Int) {
        currentWaypointIndex = index + 1
        waypointArrivalTimes[index] = Date()
        WKInterfaceDevice.current().play(.success)
    }
}
```

- [ ] **Step 2: Implement WatchMapView**

Create `WalkableWatch/Views/WatchMapView.swift`:

```swift
import SwiftUI
import MapKit
import WalkableKit

struct WatchMapView: View {
    let route: Route
    let currentLocation: CLLocationCoordinate2D?
    let currentWaypointIndex: Int
    let distanceWalked: Double
    let elapsedTime: TimeInterval
    let distanceToNext: Double?

    var body: some View {
        ZStack {
            Map {
                // Route polyline
                if let data = route.polylineData,
                   let polyline = try? MKPolyline.from(encodedData: data) {
                    MapPolyline(polyline)
                        .stroke(.blue, lineWidth: 3)
                }

                // Waypoint markers
                ForEach(route.sortedWaypoints, id: \.id) { wp in
                    Annotation("", coordinate: wp.coordinate) {
                        Circle()
                            .fill(wp.index == currentWaypointIndex ? Color.orange : Color.blue.opacity(0.5))
                            .frame(width: wp.index == currentWaypointIndex ? 10 : 6)
                            .overlay(
                                Circle().stroke(.white, lineWidth: 1)
                            )
                    }
                }

                // Current position
                if let loc = currentLocation {
                    Annotation("", coordinate: loc) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))

            // Bottom stats bar
            VStack {
                Spacer()
                HStack {
                    VStack(spacing: 0) {
                        Text("DIST")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1fkm", distanceWalked / 1000))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("TIME")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(formatTime(elapsedTime))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("NEXT")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(formatDistance(distanceToNext))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatDistance(_ meters: Double?) -> String {
        guard let m = meters else { return "--" }
        if m < 1000 { return String(format: "%.0fm", m) }
        return String(format: "%.1fkm", m / 1000)
    }
}
```

- [ ] **Step 3: Implement CompassView**

Create `WalkableWatch/Views/CompassView.swift`:

```swift
import SwiftUI

struct CompassView: View {
    let arrowAngle: Double // degrees, 0 = straight ahead
    let distanceToWaypoint: Double? // meters
    let currentWaypointIndex: Int
    let totalWaypoints: Int

    var body: some View {
        VStack(spacing: 8) {
            // Compass ring
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 120, height: 120)

                // Cardinal directions
                ForEach(["N", "E", "S", "W"], id: \.self) { dir in
                    Text(dir)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .offset(y: -55)
                        .rotationEffect(.degrees(cardinalAngle(dir)))
                }

                // Arrow
                Image(systemName: "location.north.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(arrowAngle))
                    .animation(.easeInOut(duration: 0.3), value: arrowAngle)
            }

            // Distance
            if let dist = distanceToWaypoint {
                Text(formatDistance(dist))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            // Waypoint progress
            Text("Waypoint \(currentWaypointIndex + 1) of \(totalWaypoints)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    private func cardinalAngle(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 { return String(format: "%.0fm", meters) }
        return String(format: "%.1fkm", meters / 1000)
    }
}
```

- [ ] **Step 4: Implement NowPlayingView**

Create `WalkableWatch/Views/NowPlayingView.swift`:

```swift
import SwiftUI
import MediaPlayer

struct NowPlayingView: View {
    @State private var nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo
    @State private var isPlaying = MPNowPlayingInfoCenter.default().playbackState == .playing

    var body: some View {
        VStack(spacing: 12) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.7))
                }

            // Song info
            VStack(spacing: 2) {
                Text(songTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(artistName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Playback controls
            HStack(spacing: 24) {
                Button {
                    MPRemoteCommandCenter.shared().previousTrackCommand.invoke()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }

                Button {
                    if isPlaying {
                        MPRemoteCommandCenter.shared().pauseCommand.invoke()
                    } else {
                        MPRemoteCommandCenter.shared().playCommand.invoke()
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }

                Button {
                    MPRemoteCommandCenter.shared().nextTrackCommand.invoke()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    private var songTitle: String {
        (nowPlaying?[MPMediaItemPropertyTitle] as? String) ?? "Not Playing"
    }

    private var artistName: String {
        (nowPlaying?[MPMediaItemPropertyArtist] as? String) ?? "—"
    }

    private func invoke() {}
}

private extension MPRemoteCommand {
    func invoke() {
        let event = MPRemoteCommandEvent()
        self.perform(with: event)
    }
}
```

- [ ] **Step 5: Implement WatchSummaryView**

Create `WalkableWatch/Views/WatchSummaryView.swift`:

```swift
import SwiftUI

struct WatchSummaryView: View {
    let distance: Double
    let duration: TimeInterval
    let pace: Double
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)

                Text("Walk Complete!")
                    .font(.headline)

                VStack(spacing: 8) {
                    summaryRow("Distance", value: String(format: "%.2f km", distance / 1000))
                    summaryRow("Time", value: formatTime(duration))
                    summaryRow("Pace", value: formatPace(pace))
                }
                .padding()

                Button("Done", action: onDismiss)
                    .tint(.blue)
            }
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }
}
```

- [ ] **Step 6: Implement WalkTabView (3-page swipeable)**

Replace `WalkableWatch/Views/WalkTabView.swift`:

```swift
import SwiftUI
import WalkableKit

struct WalkTabView: View {
    let route: Route
    let onEnd: () -> Void

    @State private var viewModel: WatchWalkViewModel
    @State private var selectedTab = 0

    init(route: Route, onEnd: @escaping () -> Void) {
        self.route = route
        self.onEnd = onEnd
        _viewModel = State(initialValue: WatchWalkViewModel(route: route))
    }

    var body: some View {
        if viewModel.showSummary {
            WatchSummaryView(
                distance: viewModel.distanceWalked,
                duration: viewModel.elapsedTime,
                pace: viewModel.distanceWalked > 0 ? viewModel.elapsedTime / (viewModel.distanceWalked / 1000) : 0,
                onDismiss: onEnd
            )
        } else {
            TabView(selection: $selectedTab) {
                // View 1: Route Map
                WatchMapView(
                    route: route,
                    currentLocation: viewModel.currentLocation,
                    currentWaypointIndex: viewModel.currentWaypointIndex,
                    distanceWalked: viewModel.distanceWalked,
                    elapsedTime: viewModel.elapsedTime,
                    distanceToNext: viewModel.distanceToNextWaypoint
                )
                .tag(0)

                // View 2: Compass
                CompassView(
                    arrowAngle: viewModel.relativeArrowAngle,
                    distanceToWaypoint: viewModel.distanceToNextWaypoint,
                    currentWaypointIndex: viewModel.currentWaypointIndex,
                    totalWaypoints: route.waypoints.count
                )
                .tag(1)

                // View 3: Now Playing
                NowPlayingView()
                    .tag(2)
            }
            .tabViewStyle(.verticalPage)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Task { await viewModel.endWalk() }
                    } label: {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .task {
                await viewModel.startWalk()
            }
        }
    }
}
```

- [ ] **Step 7: Build Watch target**

Run: `xcodebuild -project Walkable.xcodeproj -scheme WalkableWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add WalkableWatch/
git commit -m "feat: add Watch walk views with map, compass, now playing, and summary"
```

---

### Task 17: Final Integration & Polish

**Files:**
- Modify: `WalkableApp/WalkableApp.swift` (add SyncService initialization)
- Verify all targets build

- [ ] **Step 1: Update iOS app entry point with service initialization**

Replace `WalkableApp/WalkableApp.swift`:

```swift
import SwiftUI
import SwiftData
import WalkableKit

@main
struct WalkableApp: App {
    init() {
        // Activate WatchConnectivity sync
        _ = SyncService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Route.self, Waypoint.self, WalkSession.self, LegSplit.self])
    }
}
```

- [ ] **Step 2: Build both targets**

Run:
```bash
xcodebuild -project Walkable.xcodeproj -scheme WalkableApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

```bash
xcodebuild -project Walkable.xcodeproj -scheme WalkableWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build 2>&1 | tail -5
```

Expected: Both `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run all tests**

Run: `xcodebuild test -project Walkable.xcodeproj -scheme WalkableTests -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -15`

Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add WalkableApp/WalkableApp.swift
git commit -m "feat: initialize SyncService on app launch for WatchConnectivity"
```

- [ ] **Step 5: Final integration commit**

```bash
git log --oneline -20
```

Verify all 17 commits are present and the project is complete.
