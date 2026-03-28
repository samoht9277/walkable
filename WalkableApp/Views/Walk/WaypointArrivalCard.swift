import SwiftUI

struct WaypointArrivalCard: View {
    let waypointName: String

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 44))
            .foregroundStyle(.green)
            .symbolEffect(.bounce, value: waypointName)
            .shadow(color: .black.opacity(0.3), radius: 8)
            .transition(.scale.combined(with: .opacity))
    }
}
