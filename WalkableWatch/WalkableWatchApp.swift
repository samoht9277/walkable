import SwiftUI
import SwiftData
import WalkableKit

@main
struct WalkableWatchApp: App {
    @State private var selectedRoute: Route?
    @State private var isWalking = false
    @State private var routeListViewModel = WatchRouteListViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some Scene {
        WindowGroup {
            ContentWrapper(
                selectedRoute: $selectedRoute,
                isWalking: $isWalking,
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
    @Bindable var routeListViewModel: WatchRouteListViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if isWalking, let route = selectedRoute {
                WalkTabView(route: route) {
                    isWalking = false
                    selectedRoute = nil
                }
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
                RouteListView { route in
                    selectedRoute = route
                }
            }
        }
        .onAppear {
            routeListViewModel.setModelContext(modelContext)
            routeListViewModel.loadRoutes(modelContext: modelContext)
        }
    }
}
