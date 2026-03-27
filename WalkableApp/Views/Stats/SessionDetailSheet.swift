import SwiftUI
@preconcurrency import MapKit
import WalkableKit

struct SessionDetailSheet: View {
    let session: WalkSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Map with route + GPS track
                    sessionMap
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCardView(
                            title: "Distance",
                            value: String(format: "%.2f km", session.totalDistance / 1000),
                            icon: "ruler",
                            color: .blue
                        )
                        StatCardView(
                            title: "Duration",
                            value: formatDuration(session.totalDuration),
                            icon: "clock",
                            color: .indigo
                        )
                        StatCardView(
                            title: "Pace",
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
                    }
                    .padding(.horizontal)

                    // Leg splits
                    if !session.sortedLegSplits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Leg Splits")
                                .font(.headline)

                            ForEach(session.sortedLegSplits, id: \.id) { leg in
                                HStack {
                                    Text("Leg \(leg.fromWaypointIndex + 1) → \(leg.toWaypointIndex + 1)")
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
        }
    }

    @ViewBuilder
    private var sessionMap: some View {
        Map {
            // Planned route polyline (blue)
            if let polylineData = session.route?.polylineData,
               let polyline = try? MKPolyline.from(encodedData: polylineData) {
                MapPolyline(polyline)
                    .stroke(.blue, lineWidth: 4)
            }

            // Actual GPS track (green)
            if let gpsData = session.gpsTrackData,
               let trackPolyline = try? MKPolyline.from(encodedData: gpsData) {
                MapPolyline(trackPolyline)
                    .stroke(.green, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins >= 60 {
            let hrs = mins / 60
            let remainMins = mins % 60
            return String(format: "%d:%02d:%02d", hrs, remainMins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
}
