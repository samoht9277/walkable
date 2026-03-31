import SwiftUI
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

    var currentLocation: CLLocationCoordinate2D?
    var currentHeading: Double = 0

    private var timer: Timer?
    private var startTime = Date()
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    private var gpsLocations: [CLLocation] = []
    private var waypointArrivalTimes: [Int: Date] = [:]
    private var cancellables = Set<AnyCancellable>()

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
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.currentLocation = location.coordinate
                self?.distanceWalked = self?.healthService.distanceWalked ?? 0
                self?.gpsLocations.append(location)
                self?.healthService.addRouteLocation(location)
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

        let walkStart = startTime
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isPaused else { return }
                self.elapsedTime = Date().timeIntervalSince(walkStart) - self.pausedDuration
            }
        }
    }

    func pauseWalk() {
        isPaused = true
        pauseStartTime = Date()
        WKInterfaceDevice.current().play(.stop)
    }

    func resumeWalk() {
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        isPaused = false
        WKInterfaceDevice.current().play(.start)
    }

    func endWalk() async {
        timer?.invalidate()
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

        let payload = SessionSyncPayload(
            routeId: route.id.uuidString,
            startedAt: startTime,
            completedAt: Date(),
            totalDistance: distanceWalked,
            totalDuration: elapsedTime,
            calories: healthService.activeCalories,
            elevationGain: 0,
            avgPace: currentPace,
            legSplits: splits,
            gpsTrack: gpsTrack
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
