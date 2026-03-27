import SwiftUI
import SwiftData
import CoreLocation
import WalkableKit

enum RouteSortOption: String, CaseIterable {
    case dateCreated = "Date"
    case distance = "Distance"
    case timesWalked = "Times Walked"
    case nearest = "Nearest"
}

@MainActor
@Observable
final class LibraryViewModel {
    var searchText = ""
    var selectedTag: String? = nil
    var sortOption: RouteSortOption = .dateCreated
    var showMapView = false
    var selectedRoute: Route?

    func filteredRoutes(_ routes: [Route], currentLocation: CLLocation?) -> [Route] {
        var result = routes

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Tag filter
        if let tag = selectedTag {
            if tag == "Favorites" {
                result = result.filter { $0.isFavorite }
            } else {
                result = result.filter { $0.tags.contains(tag) }
            }
        }

        // Sort
        switch sortOption {
        case .dateCreated:
            result.sort { $0.createdAt > $1.createdAt }
        case .distance:
            result.sort { $0.distance < $1.distance }
        case .timesWalked:
            result.sort { $0.sessionCount > $1.sessionCount }
        case .nearest:
            if let loc = currentLocation {
                result.sort {
                    let d0 = loc.distance(from: CLLocation(latitude: $0.centerLatitude, longitude: $0.centerLongitude))
                    let d1 = loc.distance(from: CLLocation(latitude: $1.centerLatitude, longitude: $1.centerLongitude))
                    return d0 < d1
                }
            }
        }

        return result
    }

    func allTags(_ routes: [Route]) -> [String] {
        var tags = Set<String>()
        for route in routes {
            tags.formUnion(route.tags)
        }
        return ["Favorites"] + tags.sorted()
    }

    func toggleFavorite(_ route: Route) {
        route.isFavorite.toggle()
        Haptics.light()
        SyncService.shared.syncRoute(route, operation: .update)
    }

    func deleteRoute(_ route: Route, modelContext: ModelContext) {
        Haptics.heavy()
        for session in route.sessions {
            if let healthId = session.healthKitWorkoutID {
                Task { try? await HealthService.shared.deleteWorkout(id: healthId) }
            }
        }
        SyncService.shared.syncRoute(route, operation: .delete)
        modelContext.delete(route)
        try? modelContext.save()
    }
}
