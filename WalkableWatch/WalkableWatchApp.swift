import SwiftUI
import SwiftData
import WalkableKit

@main
struct WalkableWatchApp: App {
    @State private var selectedRoute: Route?
    @State private var isWalking = false

    var body: some Scene {
        WindowGroup {
            if isWalking, let route = selectedRoute {
                WalkTabView(route: route) {
                    isWalking = false
                    selectedRoute = nil
                }
            } else if let route = selectedRoute {
                // Pre-walk confirmation
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
        .modelContainer(for: [Route.self, Waypoint.self, WalkSession.self, LegSplit.self])
    }
}
