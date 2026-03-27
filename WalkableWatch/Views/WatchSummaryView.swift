import SwiftUI

struct WatchSummaryView: View {
    let distance: Double
    let duration: TimeInterval
    let pace: Double
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)

                Text("Walk Complete!")
                    .font(.headline)

                VStack(spacing: 8) {
                    summaryRow("Distance", value: String(format: "%.2f km", distance / 1000))
                    summaryRow("Time", value: formatTime(duration))
                    summaryRow("Pace", value: formatPace(pace))
                }
                .padding()

                Button("Done", action: onDismiss)
                    .tint(.blue)
            }
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }
}
