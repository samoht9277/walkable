import SwiftUI
import WalkableKit

struct RouteCardView: View {
    let route: Route

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(route.name)
                    .font(.headline)
                if route.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                Spacer()
                Text(String(format: "%.1f km", route.distance / 1000))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label(formatDuration(route.estimatedDuration), systemImage: "clock")
                Label("\(route.waypoints.count) waypoints", systemImage: "mappin.and.ellipse")
                Label("Walked \(route.sessionCount)x", systemImage: "figure.walk")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !route.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(route.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "~\(minutes) min" }
        return "~\(minutes / 60)h \(minutes % 60)m"
    }
}
