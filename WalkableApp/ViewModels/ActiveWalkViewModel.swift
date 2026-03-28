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

    // Watch handoff state
    var isWalkingOnWatch = false

    var elapsedTime: TimeInterval = 0
    var distanceWalked: Double = 0
    var currentPace: Double = 0
    var calories: Double = 0

    var currentWaypointIndex = 0
    var arrivedWaypointMessage: String?
    var showArrivalCard = false

    var gpsLocations: [CLLocation] = []
    var waypointArrivalTimes: [Int: Date] = [:]

    // Follow camera mode
    var isFollowMode = false
    var followCameraPosition: MapCameraPosition = .automatic
    var deviceHeading: Double = 0

    private var timer: Timer?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var walkCancellables = Set<AnyCancellable>()

    private let locationService = LocationService.shared
    private let healthService = HealthService.shared

    init() {
        listenForWatchWalkStatus()
    }

    private func listenForWatchWalkStatus() {
        SyncService.shared.watchWalkStatusReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] routeId, status in
                guard let self else { return }
                switch status {
                case .started:
                    self.isWalkingOnWatch = true
                    self.walkCancellables.removeAll()
                    self.locationService.stopTracking()
                    self.locationService.clearWaypointMonitoring()
                    self.timer?.invalidate()
                case .ended:
                    // Watch walk completed, return to normal state
                    self.isWalkingOnWatch = false
                    self.isWalking = false
                    self.route = nil
                }
            }
            .store(in: &cancellables)

        // Also listen for session sync (results from Watch)
        SyncService.shared.sessionSyncReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.isWalkingOnWatch {
                    self.isWalkingOnWatch = false
                    self.isWalking = false
                    self.route = nil
                }
            }
            .store(in: &cancellables)
    }

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

        // Try to hand off to Watch (sends via message if reachable, transferUserInfo if not)
        // Phone still tracks locally as primary — Watch will take over if it receives the handoff
        SyncService.shared.startWalkOnWatch(route: route)

        isWalking = true
        isPaused = false
        isWalkingOnWatch = false
        currentWaypointIndex = 0
        elapsedTime = 0
        distanceWalked = 0
        calories = 0
        gpsLocations.removeAll()
        waypointArrivalTimes.removeAll()
        pausedDuration = 0
        pauseStartTime = nil
        startTime = Date()

        let coords = route.sortedWaypoints.map { $0.coordinate }
        locationService.monitorWaypoints(coords)
        locationService.startTracking()

        locationService.waypointArrival
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                self?.handleWaypointArrival(index)
            }
            .store(in: &walkCancellables)

        locationService.$currentLocation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self else { return }
                #if os(watchOS)
                self.gpsLocations.append(location)
                self.distanceWalked = self.healthService.distanceWalked
                self.calories = self.healthService.activeCalories
                #else
                // On iOS, calculate distance from GPS since HKLiveWorkoutBuilder is unavailable
                if let lastLocation = self.gpsLocations.last {
                    let delta = location.distance(from: lastLocation)
                    if delta > 0, delta < 100 { // ignore GPS jumps > 100m
                        self.distanceWalked += delta
                        self.calories = self.distanceWalked * 0.05 // ~0.05 kcal/meter walking estimate
                    }
                }
                self.gpsLocations.append(location)
                #endif
                self.healthService.addRouteLocation(location)
                self.updateFollowCamera(location: location.coordinate)
            }
            .store(in: &walkCancellables)

        // Subscribe to heading updates for follow camera
        locationService.startHeadingUpdates()
        locationService.$heading
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heading in
                guard let self else { return }
                self.deviceHeading = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
                if self.isFollowMode, let loc = self.locationService.currentLocation?.coordinate {
                    self.updateFollowCamera(location: loc)
                }
            }
            .store(in: &walkCancellables)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isPaused, let start = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start) - self.pausedDuration
                if self.distanceWalked > 0 {
                    self.currentPace = self.elapsedTime / (self.distanceWalked / 1000) // sec/km
                }
            }
        }

        SyncService.shared.setActiveRoute(route)
    }

    func pauseWalk() {
        isPaused = true
        pauseStartTime = Date()
        Haptics.medium()
    }

    func resumeWalk() {
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        isPaused = false
        Haptics.medium()
    }

    func updateFollowCamera(location: CLLocationCoordinate2D) {
        guard isFollowMode else { return }
        followCameraPosition = .camera(
            MapCamera(
                centerCoordinate: location,
                distance: 400,
                heading: deviceHeading,
                pitch: 60
            )
        )
    }

    func endWalk(modelContext: ModelContext) async {
        Haptics.heavy()
        timer?.invalidate()
        timer = nil
        locationService.stopTracking()
        locationService.stopHeadingUpdates()
        locationService.clearWaypointMonitoring()
        walkCancellables.removeAll()
        isFollowMode = false

        if let route {
            let session = WalkSession(route: route)
            session.completedAt = Date()
            session.totalDistance = distanceWalked
            session.totalDuration = elapsedTime
            session.calories = calories
            session.avgPace = distanceWalked > 0 ? elapsedTime / (distanceWalked / 1000) : 0

            let coords = gpsLocations.map { CodableCoordinate($0.coordinate) }
            session.gpsTrackData = try? JSONEncoder().encode(coords)

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
        Haptics.success()
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

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showArrivalCard = false
        }
    }
}
