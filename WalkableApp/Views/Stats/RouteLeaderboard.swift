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
                        Text(entry.bestPace.formattedPace)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

}
