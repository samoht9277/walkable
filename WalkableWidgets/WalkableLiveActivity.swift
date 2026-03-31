import ActivityKit
import WidgetKit
import SwiftUI
import WalkableKit

struct WalkableLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            // Lock Screen view
            HStack {
                Image(systemName: "figure.walk")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.routeName)
                        .font(.headline)
                    HStack(spacing: 12) {
                        Label(String(format: "%.2f km", context.state.distance / 1000), systemImage: "ruler")
                        Label(context.state.elapsedTime.formattedDuration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(context.state.currentWaypointIndex)/\(context.state.totalWaypoints)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.blue)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.2f", context.state.distance / 1000))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("km")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.elapsedTime.formattedDuration)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text(String(format: "%.1fkm", context.state.distance / 1000))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.blue)
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.blue)
            }
        }
    }
}
