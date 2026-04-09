@preconcurrency import CoreLocation
import Combine

public extension Notification.Name {
    static let locationDidUpdate = Notification.Name("locationDidUpdate")
}

@MainActor
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
    }

    public func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    public func startTracking() {
        enableBackgroundLocationIfNeeded()
        manager.startUpdatingLocation()
    }

    private func enableBackgroundLocationIfNeeded() {
        guard manager.authorizationStatus == .authorizedWhenInUse ||
              manager.authorizationStatus == .authorizedAlways else { return }
        #if os(watchOS)
        // watchOS handles background location via HKWorkoutSession
        #else
        if let modes = Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String],
           modes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        #endif
    }

    public func stopTracking() {
        manager.stopUpdatingLocation()
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

    /// Check if current location is within arrival radius of the next expected waypoint.
    /// Only checks sequentially: the next unvisited waypoint, plus one ahead to handle
    /// GPS jumps at high speed. This prevents false triggers on shared streets where
    /// a later waypoint (e.g. 10) is near an earlier one (e.g. 4).
    /// The closing waypoint (last) is only checked after all others are visited.
    private func checkWaypointProximity(_ location: CLLocation) {
        let lastIndex = waypointCoordinates.count - 1
        guard lastIndex >= 0 else { return }

        // Find the next expected waypoint index
        var nextExpected = 0
        while nextExpected <= lastIndex && arrivedWaypoints.contains(nextExpected) {
            nextExpected += 1
        }
        guard nextExpected <= lastIndex else { return }

        // Check a small window: next expected + 1 ahead (for GPS jumps skipping one)
        let checkLimit = min(nextExpected + 2, lastIndex + 1)
        for index in nextExpected..<checkLimit {
            guard !arrivedWaypoints.contains(index) else { continue }
            // Don't check the closing waypoint until all others are visited
            if index == lastIndex && arrivedWaypoints.count < lastIndex { continue }

            let coord = waypointCoordinates[index]
            let waypointLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if location.distance(from: waypointLocation) <= arrivalRadiusMeters {
                // Mark any skipped waypoint between nextExpected and index
                for skipped in nextExpected..<index {
                    if !arrivedWaypoints.contains(skipped) {
                        arrivedWaypoints.insert(skipped)
                        waypointArrival.send(skipped)
                    }
                }
                arrivedWaypoints.insert(index)
                waypointArrival.send(index)
            }
        }
    }

    /// Bearing from current location to a target coordinate, in degrees (0 = north, clockwise).
    nonisolated public func bearing(to target: CLLocationCoordinate2D, from current: CLLocationCoordinate2D) -> Double {
        let lat1 = current.latitude * .pi / 180
        let lat2 = target.latitude * .pi / 180
        let dLng = (target.longitude - current.longitude) * .pi / 180

        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)

        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return bearing
    }

    /// Bearing from current location to a target coordinate, in degrees (0 = north, clockwise).
    public func bearing(to target: CLLocationCoordinate2D) -> Double? {
        guard let current = currentLocation?.coordinate else { return nil }
        return bearing(to: target, from: current)
    }

    /// Distance from current location to a target coordinate, in meters.
    public func distance(to target: CLLocationCoordinate2D) -> Double? {
        guard let current = currentLocation else { return nil }
        return current.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
    }
}

extension LocationService: @preconcurrency CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        checkWaypointProximity(location)
        // Post notification for background Live Activity updates
        // (Combine publishers stop delivering when app is suspended)
        NotificationCenter.default.post(
            name: .locationDidUpdate,
            object: nil,
            userInfo: ["location": location]
        )
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
