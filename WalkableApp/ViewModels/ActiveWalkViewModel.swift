import SwiftUI
import MapKit
import Combine
import SwiftData
import WalkableKit

@MainActor
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
                guard let self else { return }
                self.gpsLocations.append(location)
                self.distanceWalked = self.healthService.distanceWalked
                self.calories = self.healthService.activeCalories
                self.healthService.addRouteLocation(location)
            }
            .store(in: &cancellables)

        // Timer for elapsed time
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isPaused, let start = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
                if self.distanceWalked > 0 {
                    self.currentPace = self.elapsedTime / (self.distanceWalked / 1000) // sec/km
                }
            }
        }

        SyncService.shared.setActiveRoute(route)
    }

    func pauseWalk() {
        isPaused = true
    }

    func resumeWalk() {
        isPaused = false
    }

    func endWalk(modelContext: ModelContext) async {
        timer?.invalidate()
        timer = nil
        locationService.stopTracking()
        locationService.clearWaypointMonitoring()
        cancellables.removeAll()

        // Save walk session
        if let route {
            let session = WalkSession(route: route)
            session.completedAt = Date()
            session.totalDistance = distanceWalked
            session.totalDuration = elapsedTime
            session.calories = calories
            session.avgPace = distanceWalked > 0 ? elapsedTime / (distanceWalked / 1000) : 0

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
