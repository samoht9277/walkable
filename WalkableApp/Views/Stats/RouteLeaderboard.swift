import SwiftUI
import WalkableKit

struct RouteLeaderboard: View {
    let entries: [(route: Route, bestPace: Double, sessions: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route Best Times")
                .font(.headline)

            if entries.isEmpty {
                Text("Complete some walks to see your best times")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries, id: \.route.id) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.route.name)
                                .font(.subheadline.weight(.medium))
                            Text("\(entry.sessions) walks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatPace(entry.bestPace))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)
                    if entry.route.id != entries.last?.route.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }
}
