import SwiftUI
import SwiftData
import WalkableKit

struct RouteListView: View {
    @Query(sort: \Route.createdAt, order: .reverse) private var routes: [Route]
    var onSelectRoute: (Route) -> Void

    var body: some View {
        if routes.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "map")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("No Routes")
                    .font(.footnote.weight(.semibold))
                Text("Sync routes from iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            List {
                ForEach(routes) { route in
                    Button {
                        onSelectRoute(route)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(route.name)
                                .font(.headline)
                            HStack {
                                Text(String(format: "%.1f km", route.distance / 1000))
                                Text("\u{00B7}")
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
