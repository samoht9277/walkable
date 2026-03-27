# Walkable — Design Spec

iOS + WatchOS walking app built on native Apple Maps. Create walking loops, walk them with turn-by-turn waypoint guidance, track fitness progress via Apple Health.

## Architecture

**Approach:** Pure Apple stack — SwiftUI + MapKit + SwiftData + HealthKit + WatchConnectivity. Zero external dependencies.

**Minimum deployment:** iOS 17+ / watchOS 10+

### Project Structure

```
Walkable/
  WalkableApp/          — iOS app target
    Views/              — SwiftUI views (Map, RouteCreation, Library, Walk, Stats)
    ViewModels/         — MVVM view models
  WalkableWatch/        — WatchOS app target
    Views/              — Watch views (MapRoute, Compass, MusicControl)
    ViewModels/         — Watch-specific view models
  WalkableKit/          — Shared Swift package (both targets)
    Models/             — SwiftData models
    Services/           — RoutingService, HealthService, LocationService, SyncService
```

**Pattern:** MVVM with SwiftUI. Shared logic lives in WalkableKit as a local Swift package.

## Data Models (SwiftData)

### Route
- `id: UUID`
- `name: String`
- `tags: [String]`
- `isFavorite: Bool`
- `distance: Double` (meters)
- `estimatedDuration: TimeInterval`
- `createdAt: Date`
- `centerLatitude: Double`, `centerLongitude: Double` (for map preview positioning)
- `waypoints: [Waypoint]` (ordered, 1:many)
- `polylineData: Data` (encoded MKPolyline, avoids recalculation for display)
- `sessions: [WalkSession]` (1:many)

### Waypoint
- `id: UUID`
- `index: Int` (order in route)
- `latitude: Double`, `longitude: Double`
- `label: String?` (optional user-defined name)
- `route: Route` (inverse)

### WalkSession
- `id: UUID`
- `route: Route` (inverse)
- `startedAt: Date`
- `completedAt: Date?`
- `totalDistance: Double` (meters)
- `totalDuration: TimeInterval`
- `calories: Double`
- `elevationGain: Double` (meters)
- `avgPace: Double` (seconds per km)
- `healthKitWorkoutID: UUID?`
- `gpsTrackData: Data` (encoded CLLocation array, the actual path walked)
- `legSplits: [LegSplit]` (1:many)

### LegSplit
- `id: UUID`
- `session: WalkSession` (inverse)
- `fromWaypointIndex: Int`
- `toWaypointIndex: Int`
- `distance: Double`
- `duration: TimeInterval`
- `pace: Double` (seconds per km)

## iPhone App

### Tab Bar (4 tabs)

#### 1. Create — Route Builder

Full-screen Apple Maps with floating glass-effect controls. Three creation modes via a segmented control:

**Pin Mode (primary):**
- Tap the map to place waypoints (pins with numbered labels)
- Route auto-previews between consecutive pins using MKDirections (walking)
- Last pin connects back to the first to close the loop
- Can drag pins to reposition (only recalculates affected segments)
- "Undo Last Pin" and "Calculate Route" floating buttons

**Draw Mode:**
- Finger freehand drawing directly on the map
- On release: Douglas-Peucker algorithm simplifies the raw touch points
- Sample simplified path every ~200m to generate waypoints
- Snap waypoints to walkable roads via MKDirections
- User can adjust auto-generated waypoints after snapping
- "Clear Drawing" and "Snap to Roads" buttons

**Quick Templates:**
- Three shape options: Loop (circle), Out & Back (line), Figure-8 (two loops)
- User sets target distance (e.g., "3 km")
- App generates waypoints from current location in the chosen shape
- Loop: N points on a circle with radius = target distance / 2pi, centered on user location
- Out & Back: waypoints along a line for half the distance, mirrored back
- Figure-8: two smaller loops sharing a center point at user location
- All templates snap to walkable roads via MKDirections after generating geometric waypoints
- Generated route shown on map, user can adjust waypoints before saving

**After route calculation:**
- Bottom sheet slides up showing: total distance, estimated time, waypoint count
- "Save Route" prompts for name and optional tags
- Route preview with the calculated polyline overlaid on the map

#### 2. Library — Route Collection

- Search bar + tag filter chips (Favorites, custom tags)
- Sort by: date created, distance, times walked, nearest to current location
- Route cards showing: name, favorite star, distance, estimated time, waypoint count, times walked
- Tap a route to see it on a map preview with a "Start Walk" button
- Swipe actions: favorite, edit, delete
- Map view toggle: shows all saved routes as pins on a full map, clustered by proximity

#### 3. Active Walk — Live Tracking

Only visible when a walk is in progress. Otherwise shows prompt to start from Library.

- Full-screen map with route polyline overlay
- Green for walked portion, blue for remaining
- User's current position as a pulsing dot
- Next waypoint highlighted in orange
- Bottom stats bar (glass material): distance walked, elapsed time, current pace, calories
- Waypoint arrival: haptic feedback + brief card showing leg split time vs previous best
- "Pause" and "End Walk" buttons
- On completion: summary screen with total stats, per-leg splits, option to save

#### 4. Stats — Fitness Dashboard

- Weekly / monthly toggle
- Cards: total distance, total walks, avg pace, total calories, elevation gain
- Streak tracker (consecutive days with a walk)
- Pace trend line chart
- Per-route leaderboard (best times on each saved route)
- All data sourced from WalkSession records + HealthKit

### Design Language

Following iOS 26 / Apple Maps conventions:
- **Map-first UI** — map fills the screen, controls float on top with liquid glass material
- **`.ultraThinMaterial` / `.glass`** for all overlays, bottom sheets, floating buttons
- **Bottom sheet pattern** — pull-up sheets for route details, walk summaries (like native Maps)
- **SF Symbols** throughout, no custom icon assets
- **System colors** — blue (#007AFF) for routes, green (#30D158) for progress/walked, orange (#FF9F0A) for next waypoint
- **Floating circular action buttons** over the map with glass effect
- **Vibrancy effects** for text and icons overlaid on map content
- **Minimal chrome** — no heavy nav bars, the map IS the experience

## Watch App

Route creation happens exclusively on iPhone. Watch is for walking with three swipeable views.

### Pre-Walk
- List of synced routes (name, distance, waypoint count)
- Tap to select, then "Start Walk" button
- Routes synced from phone via WatchConnectivity

### During Walk — Three Views (TabView, page style)

#### View 1: Route Map
- MapKit map showing the full route polyline
- Green for walked portion, blue for remaining
- Current position dot (green, pulsing)
- Next waypoint highlighted (orange)
- Bottom glass bar: distance, elapsed time, distance to next waypoint
- Digital Crown: zoom in/out

#### View 2: Compass
- Large directional arrow pointing toward next waypoint
- Arrow uses CoreLocation heading data, updates in real-time
- Distance to next waypoint (large, readable)
- "Waypoint X of Y" label
- Minimal dark background, arrow in orange (#FF9F0A)

#### View 3: Now Playing
- Album art, song title, artist
- Play/pause, skip forward/back controls
- Volume via Digital Crown
- Uses MediaPlayer / NowPlaying framework (controls whatever audio source is active)

### Watch UX Details
- **Haptic feedback:** Distinct tap pattern when arriving at a waypoint
- **Always-on display:** Simplified view showing distance walked + compass arrow direction
- **Walk completion:** Summary screen with total distance, time, pace, then auto-syncs session back to phone

## Core Services (WalkableKit)

### RoutingService
- Accepts an ordered array of waypoints, calculates walking directions between each consecutive pair + last-to-first using MKDirections
- Rate limit strategy: sequential requests with ~1s delay between calls
- Caches results per waypoint-pair coordinate hash, so editing one pin only recalculates affected segments
- Returns a stitched MKPolyline + total distance + estimated duration
- For draw mode: accepts raw touch coordinates, runs Douglas-Peucker simplification, samples waypoints at ~200m intervals, then routes normally
- For templates: generates geometric waypoint arrays based on shape + target distance + user location

### HealthService
- Requests HealthKit permissions: workout write, heart rate read, energy read, distance read, elevation read, route write
- Starts HKWorkoutSession (activityType: .walking, locationType: .outdoor)
- Uses HKLiveWorkoutBuilder to stream live metrics (heart rate, calories, distance, elevation)
- On Watch: HKWorkoutSession keeps app alive in background with GPS access
- On completion: saves HKWorkout with HKWorkoutRoute (GPS track), associates metadata
- Calculates and stores per-leg splits by matching waypoint arrival timestamps to GPS timeline
- Provides aggregated stats queries for the Stats tab (weekly/monthly totals, trends)
- Streak calculation: queries HealthKit for days with walking workouts from this app

### LocationService
- CLLocationManager with kCLLocationAccuracyBest, distanceFilter: 5m
- allowsBackgroundLocationUpdates = true on iPhone
- On Watch: location stays active via HKWorkoutSession (no separate background mode needed)
- Publishes CLLocation stream for tracking views
- Waypoint proximity detection: triggers "arrived" event at 25m radius
- CLLocationManager.startUpdatingHeading() for watch compass view
- Heading data published as continuous stream for compass arrow rotation

### SyncService (WatchConnectivity)
- Phone → Watch route sync: `transferUserInfo()` with Route + Waypoints + encoded polyline as JSON
- Queued delivery, arrives even if watch app isn't running
- Handles route create, update, delete operations
- Watch → Phone session sync: `transferUserInfo()` with completed WalkSession + LegSplits as JSON
- `updateApplicationContext()` for "currently active route" so Watch can quick-launch it
- Watch stores synced routes in its own SwiftData store for independent operation (phone not needed during walks)

## Error Handling

- **MKDirections failure:** Show error on affected segment, allow user to reposition waypoints. Cache successful segments so partial failures don't lose work.
- **GPS signal loss:** Continue tracking with last known position, show "Signal Lost" indicator. Resume automatically when signal returns.
- **HealthKit denied:** App works without health tracking. Stats tab shows "Enable Health access in Settings" prompt.
- **Watch sync failure:** Routes queued via transferUserInfo are retried automatically by the system. Show sync status indicator on phone (synced/pending).
- **Waypoint unreachable:** If MKDirections can't find a walking route between two waypoints (e.g., across a highway), highlight the problematic segment and suggest moving the waypoint.

## Scope

**Target use case:** Neighborhood walks (1-5km), occasional urban exploration (up to ~15km).

**Not in scope:**
- Offline mode (LTE watch covers connectivity)
- Trail/hiking routes or topographic maps
- Social features or route sharing
- Android or non-Apple platforms
