import SwiftUI
import SwiftData
import WalkableKit

struct RouteListView: View {
    @Query(sort: \Route.createdAt, order: .reverse) private var routes: [Route]
    var onSelectRoute: (Route) -> Void

    var body: some View {
        NavigationStack {
            if routes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Routes")
                        .font(.headline)
                    Text("Create routes on your iPhone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                List(routes) { route in
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
