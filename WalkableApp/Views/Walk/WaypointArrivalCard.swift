import SwiftUI

struct WaypointArrivalCard: View {
    let waypointName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("Waypoint Reached!")
                    .font(.subheadline.weight(.semibold))
                Text(waypointName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
