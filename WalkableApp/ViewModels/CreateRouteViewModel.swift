import SwiftUI
@preconcurrency import MapKit
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

@MainActor
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
    var visibleRegion: MKCoordinateRegion?

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
        Haptics.light()
    }

    func undoLastWaypoint() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        calculatedRoute = nil
        Haptics.light()
    }

    func clearAll() {
        waypoints.removeAll()
        calculatedRoute = nil
        errorMessage = nil
        routingService.clearCache()
        Haptics.heavy()
    }

    private var calculationTask: Task<Void, Never>?

    func calculateRoute() {
        guard canCalculate else { return }
        isCalculating = true
        errorMessage = nil

        Haptics.medium()
        calculationTask = Task {
            do {
                let result = try await routingService.calculateLoop(through: waypoints)
                calculatedRoute = result
                // Snap waypoints to roads (only for pin/draw modes, not templates which overlap)
                if mode != .template, result.snappedWaypoints.count == waypoints.count {
                    waypoints = result.snappedWaypoints
                }
                Haptics.success()
            } catch is CancellationError {
                // User cancelled
            } catch {
                errorMessage = error.localizedDescription
                Haptics.error()
            }
            isCalculating = false
        }
    }

    func cancelCalculation() {
        calculationTask?.cancel()
        calculationTask = nil
        isCalculating = false
        Haptics.heavy()
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
        Haptics.success()

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
