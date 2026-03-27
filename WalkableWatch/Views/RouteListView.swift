import SwiftUI
import SwiftData
import WalkableKit

struct RouteListView: View {
    @Query(sort: \Route.createdAt, order: .reverse) private var routes: [Route]
    var onSelectRoute: (Route) -> Void
    var onCreateRoute: (() -> Void)?

    var body: some View {
        NavigationStack {
            if routes.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Routes")
                            .font(.headline)
                        Text("Create a route or sync from iPhone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if let onCreateRoute {
                            Button {
                                onCreateRoute()
                            } label: {
                                Label("Create Route", systemImage: "mappin.and.ellipse")
                            }
                            .tint(.blue)
                        }
                    }
                    .padding(.top, 8)
                }
            } else {
                List {
                    if let onCreateRoute {
                        Button {
                            onCreateRoute()
                        } label: {
                            Label("Create Route", systemImage: "mappin.and.ellipse")
                                .foregroundStyle(.blue)
                        }
                    }
                    ForEach(routes) { route in
                        Button {
                            onSelectRoute(route)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(route.name)
                                    .font(.headline)
                                HStack {
                                    Text(String(format: "%.1f km", route.distance / 1000))
                                    Text("·")
                                    Text("\(route.waypoints.count) pts")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
