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
                        if context.state.isPaused {
                            Text("PAUSED")
                                .foregroundStyle(.orange)
                        } else {
                            Text(context.state.timerStart, style: .timer)
                        }
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
                    if context.state.isPaused {
                        Text("PAUSED")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    } else {
                        Text(context.state.timerStart, style: .timer)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Empty bottom pushes leading/trailing content to center vertically
                    Spacer(minLength: 0)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.walk")
                    .foregroundStyle(context.state.isPaused ? .orange : .blue)
            } compactTrailing: {
                if context.state.isPaused {
                    Text("||")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                } else {
                    Text(context.state.timerStart, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.blue)
                }
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.walk")
                    .foregroundStyle(context.state.isPaused ? .orange : .blue)
            }
        }
    }
}
