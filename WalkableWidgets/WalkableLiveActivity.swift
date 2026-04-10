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
                            Label("PAUSED", systemImage: "pause.fill")
                                .foregroundStyle(.orange)
                        } else {
                            let mins = Int(context.state.elapsedTime) / 60
                            let secs = Int(context.state.elapsedTime) % 60
                            Label(String(format: "%d:%02d", mins, secs), systemImage: "clock")
                                .contentTransition(.numericText())
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(context.state.currentWaypointIndex)/\(context.state.totalWaypoints)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(.blue)
                    if let dist = context.state.nextWaypointDistance {
                        Text(String(format: "%.0fm to next", dist))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 8) {
                        Button(intent: EndWalkIntent()) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 36, height: 36)
                                .background(.red, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .offset(y: -6)

                        // Distance + waypoint counter
                        VStack(alignment: .center, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(String(format: "%.2f", context.state.distance / 1000))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                Text("km")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .fixedSize()
                            Label("\(context.state.currentWaypointIndex)/\(context.state.totalWaypoints)", systemImage: "mappin.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                        .frame(maxWidth: .infinity)

                        RoundedRectangle(cornerRadius: 1)
                            .fill(.quaternary)
                            .frame(width: 2, height: 36)

                        // Timer + distance to next
                        VStack(alignment: .center, spacing: 2) {
                            if context.state.isPaused {
                                let mins = Int(context.state.elapsedTime) / 60
                                let secs = Int(context.state.elapsedTime) % 60
                                Text(String(format: "%d:%02d", mins, secs))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(context.state.timerStart, style: .timer)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            if context.state.isPaused {
                                Text("PAUSED")
                                    .font(.caption2.weight(.light))
                                    .foregroundStyle(.orange)
                            } else if let dist = context.state.nextWaypointDistance {
                                Label(String(format: "%.0fm", dist), systemImage: "arrow.forward")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Label("--", systemImage: "arrow.forward")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Button(intent: TogglePauseIntent()) {
                            Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 36, height: 36)
                                .background(context.state.isPaused ? Color.orange : Color.blue, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .offset(y: -6)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.walk")
                    .foregroundStyle(context.state.isPaused ? .orange : .blue)
            } compactTrailing: {
                Text(String(format: "%.1fkm", context.state.distance / 1000))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(context.state.isPaused ? .orange : .blue)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.walk")
                    .foregroundStyle(context.state.isPaused ? .orange : .blue)
            }
        }
    }
}
