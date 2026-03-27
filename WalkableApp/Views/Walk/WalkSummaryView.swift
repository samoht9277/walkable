import SwiftUI

struct WalkSummaryView: View {
    let distance: Double
    let duration: TimeInterval
    let pace: Double
    let calories: Double
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("Walk Complete!")
                    .font(.title.weight(.bold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    summaryCard("Distance", value: String(format: "%.2f km", distance / 1000), icon: "ruler")
                    summaryCard("Duration", value: formatDuration(duration), icon: "clock")
                    summaryCard("Avg Pace", value: formatPace(pace), icon: "speedometer")
                    summaryCard("Calories", value: String(format: "%.0f kcal", calories), icon: "flame")
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
            }
            .padding(.top, 40)
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func summaryCard(_ label: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace < 3600 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }
}
