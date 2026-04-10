import SwiftUI
import WatchKit
import WalkableKit

struct WalkControlsView: View {
    let timerStartDate: Date
    let elapsedTime: TimeInterval
    let distance: Double
    let pace: Double
    let heartRate: Double
    let currentWaypointIndex: Int
    let totalWaypoints: Int
    let isPaused: Bool
    let loopCompleted: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: () -> Void
    @Environment(\.isLuminanceReduced) private var isAOD

    var body: some View {
        VStack(spacing: 12) {
            if isPaused || isAOD {
                // Static short format for paused and AOD
                // (.timer style renders "60 minutes, 40 seconds" in AOD which truncates)
                let elapsed = isPaused ? elapsedTime : Date().timeIntervalSince(timerStartDate)
                let mins = Int(elapsed) / 60
                let secs = Int(elapsed) % 60
                Text(String(format: "%d:%02d", mins, secs))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isPaused ? .secondary : .primary)
            } else {
                Text(timerStartDate, style: .timer)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            HStack(spacing: 16) {
                VStack {
                    Text(String(format: "%.2f", distance / 1000))
                        .font(.headline.monospacedDigit())
                    Text("km")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(pace.formattedPaceShort)
                        .font(.headline.monospacedDigit())
                    Text("pace")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                        Text(heartRate > 0 ? String(format: "%.0f", heartRate) : "--")
                            .font(.headline.monospacedDigit())
                    }
                    Text("bpm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("\(currentWaypointIndex)/\(totalWaypoints)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if loopCompleted {
                Text("🏁 Route Complete!")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            }

            HStack(spacing: 12) {
                if !loopCompleted {
                    Button {
                        WKInterfaceDevice.current().play(isPaused ? .start : .stop)
                        if isPaused { onResume() } else { onPause() }
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title3)
                            .frame(width: 50, height: 50)
                    }
                    .tint(isPaused ? .green : .yellow)
                }

                Button {
                    WKInterfaceDevice.current().play(.notification)
                    onEnd()
                } label: {
                    Image(systemName: loopCompleted ? "checkmark" : "stop.fill")
                        .font(.title3)
                        .frame(width: 50, height: 50)
                }
                .tint(loopCompleted ? .green : .red)
            }
        }
    }
}
