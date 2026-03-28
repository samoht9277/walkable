import SwiftUI
import MapKit
import WalkableKit

struct RouteDetailSheet: View {
    let route: Route
    let onStartWalk: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Map preview
                RouteMapOverlay(route: route)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(alignment: .bottomTrailing) {
                        // Hide the Apple Maps legal overlay
                        Rectangle()
                            .fill(.clear)
                            .frame(height: 20)
                    }
                    .padding(.horizontal)

                // Stats grid
                HStack(spacing: 10) {
                    StatPill(label: "Distance", value: String(format: "%.1f km", route.distance / 1000), icon: "ruler")
                    StatPill(label: "Est. Time", value: route.estimatedDuration.formattedEstimate, icon: "clock")
                    StatPill(label: "Waypoints", value: "\(route.waypoints.count)", icon: "mappin")
                }
                .padding(.horizontal)

                // Tags
                if !route.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(route.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .glassEffect(.regular, in: .capsule)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Metadata
                HStack(spacing: 16) {
                    Label("Walked \(route.sessionCount) time\(route.sessionCount == 1 ? "" : "s")", systemImage: "figure.walk")
                    Spacer()
                    Label(route.createdAt.formatted(.dateTime.month(.abbreviated).day().year()), systemImage: "calendar")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

                Spacer()

                // Start Walk CTA
                Button {
                    dismiss()
                    onStartWalk()
                } label: {
                    Label("Start Walk", systemImage: "figure.walk")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.green, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .navigationTitle(route.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String
    var icon: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
