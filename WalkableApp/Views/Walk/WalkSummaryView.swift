import SwiftUI
import WalkableKit

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
                    summaryCard("Distance", value: distance.formattedDistance, icon: "ruler")
                    summaryCard("Duration", value: duration.formattedDuration, icon: "clock")
                    summaryCard("Avg Pace", value: pace.formattedPace, icon: "speedometer")
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
}
