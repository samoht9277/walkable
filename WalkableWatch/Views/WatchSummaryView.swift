import SwiftUI
import WalkableKit

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
                    summaryRow("Time", value: duration.formattedDuration)
                    summaryRow("Pace", value: pace.formattedPace)
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
}
