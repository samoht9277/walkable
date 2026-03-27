import SwiftUI

struct WalkStatsBar: View {
    let distance: Double // meters
    let elapsed: TimeInterval
    let pace: Double // sec/km
    let calories: Double

    var body: some View {
        HStack {
            statItem(label: "DISTANCE", value: String(format: "%.2f km", distance / 1000))
            Divider().frame(height: 30)
            statItem(label: "TIME", value: formatTime(elapsed))
            Divider().frame(height: 30)
            statItem(label: "PACE", value: formatPace(pace))
            Divider().frame(height: 30)
            statItem(label: "CAL", value: String(format: "%.0f", calories))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace < 3600 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
