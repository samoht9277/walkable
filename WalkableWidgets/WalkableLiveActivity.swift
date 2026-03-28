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
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Label(
                        String(format: "%.1f km", context.state.distance / 1000),
                        systemImage: "ruler"
                    )
                    .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label(
                        context.state.elapsedTime.formattedDuration,
                        systemImage: "clock"
                    )
                    .font(.caption)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.routeName)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(
                            context.state.pace.formattedPaceShort,
                            systemImage: "speedometer"
                        )
                        Spacer()
                        if let nextDist = context.state.nextWaypointDistance {
                            Label(nextDist.formattedDistance, systemImage: "mappin")
                        }
                        Spacer()
                        Text("WP \(context.state.currentWaypointIndex)/\(context.state.totalWaypoints)")
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text(String(format: "%.1fkm", context.state.distance / 1000))
                    .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.blue)
            }
        }
    }
}
