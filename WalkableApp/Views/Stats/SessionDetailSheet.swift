import SwiftUI
@preconcurrency import MapKit
import WalkableKit

struct SessionDetailSheet: View {
    let session: WalkSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Map with route + GPS track
                    sessionMap
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                    // Date and time header
                    VStack(spacing: 4) {
                        Text(session.startedAt, format: .dateTime.weekday(.wide).month(.wide).day().year())
                            .font(.headline)
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text(session.startedAt, format: .dateTime.hour().minute())
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            if let end = session.completedAt {
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(end, format: .dateTime.hour().minute())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)

                    // Duration prominently
                    Text(session.totalDuration.formattedDuration)
                        .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCardView(
                            title: "Distance",
                            value: String(format: "%.2f km", session.totalDistance / 1000),
                            icon: "ruler",
                            color: .blue
                        )
                        StatCardView(
                            title: "Avg Pace",
                            value: session.formattedPace,
                            icon: "speedometer",
                            color: .purple
                        )
                        StatCardView(
                            title: "Calories",
                            value: String(format: "%.0f kcal", session.calories),
                            icon: "flame",
                            color: .orange
                        )
                        StatCardView(
                            title: "Elevation",
                            value: String(format: "%.0f m", session.elevationGain),
                            icon: "mountain.2",
                            color: .green
                        )
                    }
                    .padding(.horizontal)

                    // Leg splits
                    if !session.sortedLegSplits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Leg Splits")
                                .font(.headline)

                            ForEach(session.sortedLegSplits, id: \.id) { leg in
                                HStack {
                                    Text("Leg \(leg.fromWaypointIndex + 1) \u{2192} \(leg.toWaypointIndex + 1)")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.0f m", leg.distance))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(leg.formattedPace)
                                        .font(.subheadline.weight(.bold).monospacedDigit())
                                        .foregroundStyle(.green)
                                }
                                .padding(.vertical, 2)
                                if leg.id != session.sortedLegSplits.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(session.route?.name ?? "Walk Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sessionMap: some View {
        Map {
            if let coords = session.route?.decodedPolylineCoordinates {
                MapPolyline(coordinates: coords)
                    .stroke(.blue, lineWidth: 4)
            }

            if let coords = session.gpsTrackData?.decodedCoordinates() {
                MapPolyline(coordinates: coords)
                    .stroke(.green, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
    }
}
