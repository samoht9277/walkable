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
                        Label(String(format: "%.2f km", context.state.distance / 1000), systemImage: "ruler")
                        Label(context.state.elapsedTime.formattedDuration, systemImage: "clock")
                        Label(context.state.pace.formattedPaceShort, systemImage: "speedometer")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(context.state.currentWaypointIndex + 1)/\(context.state.totalWaypoints)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.blue)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // Keep content away from rounded corners
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 8) {
                        // Top row: distance + time
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%.2f km", context.state.distance / 1000))
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(context.state.elapsedTime.formattedDuration)
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .monospacedDigit()
                            }
                        }

                        // Bottom row: pace + route + waypoints
                        HStack {
                            Label(context.state.pace.formattedPaceShort, systemImage: "speedometer")
                            Spacer()
                            Text(context.attributes.routeName)
                                .foregroundStyle(.blue)
                            Spacer()
                            Label("\(context.state.currentWaypointIndex + 1)/\(context.state.totalWaypoints)", systemImage: "mappin")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
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
