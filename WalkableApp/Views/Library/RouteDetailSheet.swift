import SwiftUI
import MapKit
import WalkableKit

struct RouteDetailSheet: View {
    let route: Route
    let onStartWalk: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Map preview
                RouteMapOverlay(route: route)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()

                // Route info
                VStack(spacing: 16) {
                    HStack {
                        StatPill(label: "Distance", value: String(format: "%.1f km", route.distance / 1000))
                        StatPill(label: "Est. Time", value: route.estimatedDuration.formattedEstimate)
                        StatPill(label: "Waypoints", value: "\(route.waypoints.count)")
                    }
                    .padding(.horizontal)

                    Button {
                        dismiss()
                        onStartWalk()
                    } label: {
                        Label("Start Walk", systemImage: "figure.walk")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle(route.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

}

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
