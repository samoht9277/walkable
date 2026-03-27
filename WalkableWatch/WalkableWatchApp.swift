import SwiftUI
import SwiftData
import Combine
import WalkableKit

@main
struct WalkableWatchApp: App {
    @State private var selectedRoute: Route?
    @State private var isWalking = false
    @State private var isCreatingRoute = false
    @State private var routeListViewModel = WatchRouteListViewModel()

    var body: some Scene {
        WindowGroup {
            ContentWrapper(
                selectedRoute: $selectedRoute,
                isWalking: $isWalking,
                isCreatingRoute: $isCreatingRoute,
                routeListViewModel: routeListViewModel
            )
        }
        .modelContainer(for: [Route.self, Waypoint.self, WalkSession.self, LegSplit.self])
    }
}

/// Wrapper view that has access to the modelContext from the model container
private struct ContentWrapper: View {
    @Binding var selectedRoute: Route?
    @Binding var isWalking: Bool
    @Binding var isCreatingRoute: Bool
    @Bindable var routeListViewModel: WatchRouteListViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        Group {
            if isWalking, let route = selectedRoute {
                WalkTabView(route: route) {
                    // Walk ended, notify phone
                    SyncService.shared.notifyPhoneWalkStatus(
                        routeId: route.id.uuidString,
                        status: .ended
                    )
                    isWalking = false
                    selectedRoute = nil
                }
            } else if isCreatingRoute {
                WatchCreateRouteView(
                    onStartWalk: { route in
                        selectedRoute = route
                        isCreatingRoute = false
                        isWalking = true
                    },
                    onCancel: {
                        isCreatingRoute = false
                    }
                )
            } else if let route = selectedRoute {
                VStack(spacing: 12) {
                    Text(route.name)
                        .font(.headline)
                    Text(String(format: "%.1f km · %d waypoints", route.distance / 1000, route.waypoints.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        isWalking = true
                    } label: {
                        Label("Start Walk", systemImage: "figure.walk")
                    }
                    .tint(.green)
                    Button("Back") {
                        selectedRoute = nil
                    }
                }
            } else {
                RouteListView(
                    onSelectRoute: { route in
                        selectedRoute = route
                    },
                    onCreateRoute: {
                        isCreatingRoute = true
                    }
                )
            }
        }
        .onAppear {
            routeListViewModel.setModelContext(modelContext)
            routeListViewModel.loadRoutes(modelContext: modelContext)
            listenForPhoneWalkRequest()
        }
    }

    private func listenForPhoneWalkRequest() {
        SyncService.shared.startWalkRequested
            .receive(on: DispatchQueue.main)
            .sink { payload in
                handleStartWalkFromPhone(payload)
            }
            .store(in: &cancellables)
    }

    private func handleStartWalkFromPhone(_ payload: SyncPayload) {
        // Create or find the route in local SwiftData
        let routeId = UUID(uuidString: payload.routeId) ?? UUID()
        var descriptor = FetchDescriptor<Route>(predicate: #Predicate { $0.id == routeId })
        descriptor.fetchLimit = 1
        let existing = (try? modelContext.fetch(descriptor))?.first

        let route: Route
        if let existing {
            route = existing
        } else {
            // Create route locally from the payload
            let newRoute = Route(
                name: payload.name ?? "Phone Route",
                distance: payload.distance ?? 0,
                estimatedDuration: payload.estimatedDuration ?? 0
            )
            newRoute.id = routeId

            if let first = payload.waypoints?.first {
                newRoute.centerLatitude = first.latitude
                newRoute.centerLongitude = first.longitude
            }

            modelContext.insert(newRoute)

            if let syncWaypoints = payload.waypoints {
                for wp in syncWaypoints {
                    let waypoint = Waypoint(
                        index: wp.index,
                        latitude: wp.latitude,
                        longitude: wp.longitude,
                        label: wp.label
                    )
                    waypoint.route = newRoute
                    newRoute.waypoints.append(waypoint)
                }
            }

            if let polyCoords = payload.polylineCoordinates {
                newRoute.polylineData = try? JSONEncoder().encode(polyCoords)
            }

            try? modelContext.save()
            route = newRoute
        }

        // Start the walk
        selectedRoute = route
        isWalking = true

        // Notify phone that walk started
        SyncService.shared.notifyPhoneWalkStatus(
            routeId: route.id.uuidString,
            status: .started
        )
    }
}
