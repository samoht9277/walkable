import SwiftUI
import MapKit
import Combine
import CoreLocation
import WatchKit
import WalkableKit

@MainActor
@Observable
final class WatchWalkViewModel {
    let route: Route

    var isWalking = true
    var isPaused = false
    var showSummary = false
    var elapsedTime: TimeInterval = 0
    var distanceWalked: Double = 0
    var currentWaypointIndex = 0
    var visitedWaypointIndices: Set<Int> = []
    var loopCompleted = false
    var showArrivalBanner = false
    var arrivedWaypointName: String?

    var currentLocation: CLLocationCoordinate2D?
    var currentHeading: Double = 0
    var mapCameraPosition: MapCameraPosition = .automatic
    var hasZoomedIn = false

    private var startTime = Date()
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    var lastPolylineSegmentIndex = 0
    private var gpsLocations: [CLLocation] = []
    private var waypointArrivalTimes: [Int: Date] = [:]
    private var cancellables = Set<AnyCancellable>()

    // Analysis data collection
    private var altitudeSamples: [(date: Date, altitude: Double)] = []
    private var paceSamples: [(date: Date, pace: Double)] = []
    private var cumulativeElevationGain: Double = 0

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

    var currentPace: Double {
        guard distanceWalked > 0 else { return 0 }
        return elapsedTime / (distanceWalked / 1000)
    }

    var heartRate: Double {
        healthService.heartRate
    }

    /// For Text(date, style: .timer) — system-rendered, AOD-compatible.
    /// Stored, not computed, to avoid fighting with the .timer style's own ticking.
    var timerStartDate: Date = .now

    /// Relative bearing: subtract device heading from absolute bearing to get arrow direction.
    var relativeArrowAngle: Double {
        guard let bearing = bearingToNextWaypoint else { return 0 }
        return bearing - currentHeading
    }

    func startWalk() async {
        startTime = Date()
        timerStartDate = startTime
        var coords = route.sortedWaypoints.map { $0.coordinate }
        if let first = coords.first { coords.append(first) }
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
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self else { return }
                self.currentLocation = location.coordinate
                self.distanceWalked = self.healthService.distanceWalked ?? 0
                self.gpsLocations.append(location)
                self.healthService.addRouteLocation(location)

                // Update elapsed time from location callback (no Timer needed)
                if !self.isPaused {
                    self.elapsedTime = Date().timeIntervalSince(self.startTime) - self.pausedDuration
                }

                // Track polyline progress for correct split on shared streets.
                // Cap advancement to 5 segments per update to avoid jumping ahead
                // when outbound and return legs share a street.
                if let coords = self.route.decodedPolylineCoordinates, coords.count >= 2 {
                    let split = PolylineSplitter.split(polyline: coords, at: location.coordinate, searchFromIndex: self.lastPolylineSegmentIndex, searchWindow: 10)
                    let newIndex = split.walked.count - 2
                    let maxJump = self.lastPolylineSegmentIndex + 5
                    self.lastPolylineSegmentIndex = max(self.lastPolylineSegmentIndex, min(newIndex, maxJump))
                }

                // Altitude sampling
                self.altitudeSamples.append((date: Date(), altitude: location.altitude))

                // Elevation gain (positive changes > 1m to filter GPS noise)
                if let lastAlt = self.altitudeSamples.dropLast().last?.altitude {
                    let delta = location.altitude - lastAlt
                    if delta > 1 { self.cumulativeElevationGain += delta }
                }

                // Pace sampling every 30 seconds
                if let lastPaceSample = self.paceSamples.last {
                    if Date().timeIntervalSince(lastPaceSample.date) >= 30, self.distanceWalked > 0 {
                        let recentPace = self.elapsedTime / (self.distanceWalked / 1000)
                        self.paceSamples.append((date: Date(), pace: recentPace / 60))
                    }
                } else if self.distanceWalked > 20 {
                    self.paceSamples.append((date: Date(), pace: (self.elapsedTime / (self.distanceWalked / 1000)) / 60))
                }
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

        // Start with route overview, zoom to user after 3s
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, let loc = self.currentLocation else { return }
            withAnimation(.smooth(duration: 1.5)) {
                self.mapCameraPosition = .camera(MapCamera(
                    centerCoordinate: loc,
                    distance: 800
                ))
                self.hasZoomedIn = true
            }
        }

        // No Timer — elapsedTime updates from location callbacks instead.
        // Timers keep the run loop active and prevent AOD.
    }

    func pauseWalk() {
        isPaused = true
        pauseStartTime = Date()
        // Freeze timer display
        timerStartDate = .distantFuture
        WKInterfaceDevice.current().play(.stop)
    }

    func resumeWalk() {
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        isPaused = false
        // Resume timer display: set start date accounting for paused duration
        timerStartDate = startTime.addingTimeInterval(pausedDuration)
        WKInterfaceDevice.current().play(.start)
    }

    func endWalk() async {
        locationService.stopTracking()
        locationService.stopHeadingUpdates()
        locationService.clearWaypointMonitoring()
        cancellables.removeAll()

        _ = try? await healthService.endWorkout()

        // Build leg splits from waypoint arrival times
        let sortedWaypoints = route.sortedWaypoints
        var splits = [SyncLegSplit]()
        for i in 0..<sortedWaypoints.count {
            let nextIndex = (i + 1) % sortedWaypoints.count
            if let arriveTime = waypointArrivalTimes[i],
               let nextArriveTime = waypointArrivalTimes[nextIndex] {
                let duration = nextArriveTime.timeIntervalSince(arriveTime)
                let wpA = sortedWaypoints[i].coordinate
                let wpB = sortedWaypoints[nextIndex].coordinate
                let dist = CLLocation(latitude: wpA.latitude, longitude: wpA.longitude)
                    .distance(from: CLLocation(latitude: wpB.latitude, longitude: wpB.longitude))
                let pace = dist > 0 ? duration / (dist / 1000) : 0
                splits.append(SyncLegSplit(
                    fromWaypointIndex: i, toWaypointIndex: nextIndex,
                    distance: dist, duration: duration, pace: pace
                ))
            }
        }

        // GPS track as codable coordinates
        let gpsTrack = gpsLocations.map { CodableCoordinate($0.coordinate) }

        // Encode analysis data for post-walk charts
        let analysis = WalkAnalysisData(
            altitude: altitudeSamples.map { TimedSample(date: $0.date, value: $0.altitude) },
            pace: paceSamples.map { TimedSample(date: $0.date, value: $0.pace) },
            heartRate: []
        )
        let encodedAnalysis = try? JSONEncoder().encode(analysis)

        let payload = SessionSyncPayload(
            routeId: route.id.uuidString,
            startedAt: startTime,
            completedAt: Date(),
            totalDistance: distanceWalked,
            totalDuration: elapsedTime,
            calories: healthService.activeCalories,
            elevationGain: cumulativeElevationGain,
            avgPace: currentPace,
            legSplits: splits,
            gpsTrack: gpsTrack,
            analysisData: encodedAnalysis,
            source: "watch"
        )
        SyncService.shared.syncWalkSession(payload)

        isWalking = false
        showSummary = true
    }

    private func handleWaypointArrival(_ index: Int) {
        currentWaypointIndex = index + 1
        waypointArrivalTimes[index] = Date()

        for i in 0...index {
            visitedWaypointIndices.insert(i)
        }

        if index >= route.waypoints.count {
            loopCompleted = true
            // Triple haptic for loop complete
            WKInterfaceDevice.current().play(.notification)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WKInterfaceDevice.current().play(.notification)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                WKInterfaceDevice.current().play(.notification)
            }
            return
        }

        // Show waypoint arrival banner
        let wp = route.sortedWaypoints[index]
        arrivedWaypointName = wp.label ?? "Waypoint \(index + 1)"
        showArrivalBanner = true
        // Double haptic for waypoint arrival
        WKInterfaceDevice.current().play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            WKInterfaceDevice.current().play(.success)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showArrivalBanner = false
        }
    }
}
