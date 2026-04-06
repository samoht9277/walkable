import SwiftUI
import SwiftData
import Combine
import WalkableKit

@MainActor
@Observable
final class WatchRouteListViewModel {
    var routes: [Route] = []
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext

        // Listen for route syncs from phone
        SyncService.shared.routeSyncReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] payload in
                self?.handleRouteSync(payload)
            }
            .store(in: &cancellables)

        // Listen for Watch-created routes arriving back from phone (dedup)
        SyncService.shared.watchCreatedRouteReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] payload in
                self?.handleRouteSync(payload)
            }
            .store(in: &cancellables)
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func loadRoutes(modelContext: ModelContext) {
        self.modelContext = modelContext
        let descriptor = FetchDescriptor<Route>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        routes = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Called from ContentWrapper which guarantees a valid modelContext
    func handleSyncFromContentWrapper(_ payload: SyncPayload, context: ModelContext) {
        self.modelContext = context
        handleRouteSync(payload)
    }

    private func handleRouteSync(_ payload: SyncPayload) {
        guard let modelContext else { return }

        switch payload.operation {
        case .create:
            createRoute(from: payload, in: modelContext)
        case .update:
            updateRoute(from: payload, in: modelContext)
        case .delete:
            deleteRoute(routeId: payload.routeId, in: modelContext)
        }

        try? modelContext.save()
        loadRoutes(modelContext: modelContext)
    }

    private func createRoute(from payload: SyncPayload, in context: ModelContext) {
        let route = Route(
            name: payload.name ?? "Synced Route",
            distance: payload.distance ?? 0,
            estimatedDuration: payload.estimatedDuration ?? 0
        )

        // Use the synced UUID so phone and watch share the same ID
        if let uuid = UUID(uuidString: payload.routeId) {
            route.id = uuid
        }

        // Set center from first waypoint if available
        if let first = payload.waypoints?.first {
            route.centerLatitude = first.latitude
            route.centerLongitude = first.longitude
        }

        context.insert(route)

        // Create waypoints
        if let syncWaypoints = payload.waypoints {
            for wp in syncWaypoints {
                let waypoint = Waypoint(
                    index: wp.index,
                    latitude: wp.latitude,
                    longitude: wp.longitude,
                    label: wp.label
                )
                waypoint.route = route
                route.waypoints.append(waypoint)
            }
        }

        // Encode polyline data
        if let polyCoords = payload.polylineCoordinates {
            route.polylineData = try? JSONEncoder().encode(polyCoords)
        }
    }

    private func updateRoute(from payload: SyncPayload, in context: ModelContext) {
        guard let route = fetchRoute(id: payload.routeId, in: context) else {
            // Route doesn't exist yet, create it instead
            createRoute(from: payload, in: context)
            return
        }

        if let name = payload.name { route.name = name }
        if let distance = payload.distance { route.distance = distance }
        if let duration = payload.estimatedDuration { route.estimatedDuration = duration }

        // Replace waypoints
        if let syncWaypoints = payload.waypoints {
            // Delete old waypoints
            for wp in route.waypoints {
                context.delete(wp)
            }
            route.waypoints.removeAll()

            // Create new ones
            for wp in syncWaypoints {
                let waypoint = Waypoint(
                    index: wp.index,
                    latitude: wp.latitude,
                    longitude: wp.longitude,
                    label: wp.label
                )
                waypoint.route = route
                route.waypoints.append(waypoint)
            }
        }

        // Update polyline
        if let polyCoords = payload.polylineCoordinates {
            route.polylineData = try? JSONEncoder().encode(polyCoords)
        }
    }

    private func deleteRoute(routeId: String, in context: ModelContext) {
        guard let route = fetchRoute(id: routeId, in: context) else { return }
        context.delete(route)
    }

    private func fetchRoute(id: String, in context: ModelContext) -> Route? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<Route>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
