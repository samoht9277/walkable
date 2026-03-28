import ActivityKit
import WidgetKit
import SwiftUI
import WalkableKit

struct WalkableLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            // Lock Screen / StandBy view
            HStack {
                Image(systemName: "figure.walk")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.routeName)
                        .font(.headline)
                    HStack(spacing: 12) {
                        Label(
                            String(format: "%.2f km", context.state.distance / 1000),
                            systemImage: "ruler"
                        )
                        Label(
                            context.state.elapsedTime.formattedDuration,
                            systemImage: "clock"
                        )
                        Label(
                            context.state.pace.formattedPaceShort,
                            systemImage: "speedometer"
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Waypoint progress
                Text("\(context.state.currentWaypointIndex)/\(context.state.totalWaypoints)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.blue)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.routeName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f km", context.state.distance / 1000))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("Time")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.elapsedTime.formattedDuration)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(context.state.pace.formattedPaceShort, systemImage: "speedometer")
                        Spacer()
                        Text("WP \(context.state.currentWaypointIndex + 1)/\(context.state.totalWaypoints)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
