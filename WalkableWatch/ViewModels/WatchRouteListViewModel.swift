import SwiftUI
import SwiftData
import Combine
import WalkableKit

@MainActor
@Observable
final class WatchRouteListViewModel {
    var routes: [Route] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Listen for route syncs from phone
        SyncService.shared.routeSyncReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] payload in
                self?.handleRouteSync(payload)
            }
            .store(in: &cancellables)
    }

    func loadRoutes(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Route>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        routes = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func handleRouteSync(_ payload: SyncPayload) {
        // Route sync is handled at the SwiftData level via SyncService.
        // The view will refresh automatically via @Query or manual fetch.
    }
}
