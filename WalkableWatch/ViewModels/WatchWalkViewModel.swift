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

        let walkStart = startTime
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedTime = Date().timeIntervalSince(walkStart)
            }
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
