import SwiftUI
import MapKit
import SwiftData
import WalkableKit

@MainActor
@Observable
final class WatchCreateViewModel {
    var waypoints: [CLLocationCoordinate2D] = []
    var isCalculating = false
    var calculationError: String?
    var calculatedRoute: CalculatedRoute?

    /// The center of the map, updated as user pans.
    var mapCenter = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

    /// After route is calculated, this holds the saved Route ready for walking.
    var savedRoute: Route?

    var canCalculate: Bool {
        waypoints.count >= 2 && !isCalculating
    }

    func addPin() {
        waypoints.append(mapCenter)
    }

    func undoLastPin() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        calculatedRoute = nil
        savedRoute = nil
    }

    func reset() {
        waypoints.removeAll()
        calculatedRoute = nil
        savedRoute = nil
        isCalculating = false
        calculationError = nil
    }

    func calculateAndStartWalk(modelContext: ModelContext) async {
        guard waypoints.count >= 2 else { return }

        isCalculating = true
        calculationError = nil

        do {
            let result = try await RoutingService.shared.calculateLoop(through: waypoints)
            calculatedRoute = result

            // Save the route to SwiftData
            let route = Route(
                name: "Watch Route",
                distance: result.distance,
                estimatedDuration: result.expectedTravelTime,
                centerLatitude: waypoints[0].latitude,
                centerLongitude: waypoints[0].longitude
            )

            for (i, coord) in waypoints.enumerated() {
                let wp = Waypoint(
                    index: i,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    label: "Pin \(i + 1)"
                )
                wp.route = route
                route.waypoints.append(wp)
            }

            // Encode polyline
            let polyCoords = result.coordinates.map { CodableCoordinate($0) }
            route.polylineData = try? JSONEncoder().encode(polyCoords)

            modelContext.insert(route)
            try? modelContext.save()

            savedRoute = route
            isCalculating = false

            // Queue for phone sync
            let syncWaypoints = waypoints.enumerated().map { i, coord in
                SyncWaypoint(index: i, latitude: coord.latitude, longitude: coord.longitude, label: "Pin \(i + 1)")
            }
            let syncPayload = SyncPayload(
                operation: .create,
                routeId: route.id.uuidString,
                name: route.name,
                distance: route.distance,
                estimatedDuration: route.estimatedDuration,
                waypoints: syncWaypoints,
                polylineCoordinates: polyCoords
            )
            SyncService.shared.syncWatchCreatedRoute(syncPayload)
        } catch {
            isCalculating = false
            calculationError = error.localizedDescription
        }
    }
}
