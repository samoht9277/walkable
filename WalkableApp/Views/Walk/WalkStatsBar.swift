import SwiftUI
import WalkableKit

struct WalkStatsBar: View {
    let distance: Double // meters
    let elapsed: TimeInterval
    let pace: Double // sec/km
    let calories: Double

    var body: some View {
        HStack {
            statItem(label: "DISTANCE", value: String(format: "%.2f km", distance / 1000))
            Divider().frame(height: 30)
            statItem(label: "TIME", value: elapsed.formattedDuration)
            Divider().frame(height: 30)
            statItem(label: "PACE", value: pace.formattedPaceShort)
            Divider().frame(height: 30)
            statItem(label: "CAL", value: String(format: "%.0f", calories))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.smooth, value: value)
        }
        .frame(maxWidth: .infinity)
    }
}
