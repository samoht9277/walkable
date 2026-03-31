import SwiftUI
import WalkableKit

struct WalkControlsView: View {
    let elapsedTime: TimeInterval
    let distance: Double
    let pace: Double
    let isPaused: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(elapsedTime.formattedDuration)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()

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
            }

            HStack(spacing: 12) {
                Button(action: isPaused ? onResume : onPause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                        .frame(width: 50, height: 50)
                }
                .tint(isPaused ? .green : .yellow)

                Button(action: onEnd) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .frame(width: 50, height: 50)
                }
                .tint(.red)
            }
        }
    }
}
