import SwiftUI
import MapKit
import WalkableKit

struct WatchMapView: View {
    let route: Route
    let currentLocation: CLLocationCoordinate2D?
    let currentWaypointIndex: Int
    let distanceWalked: Double
    let elapsedTime: TimeInterval
    let distanceToNext: Double?

    var body: some View {
        ZStack {
            Map {
                // Route polyline
                if let data = route.polylineData,
                   let polyline = try? MKPolyline.from(encodedData: data) {
                    MapPolyline(polyline)
                        .stroke(.blue, lineWidth: 3)
                }

                // Waypoint markers
                ForEach(route.sortedWaypoints, id: \.id) { wp in
                    Annotation("", coordinate: wp.coordinate) {
                        Circle()
                            .fill(wp.index == currentWaypointIndex ? Color.orange : Color.blue.opacity(0.5))
                            .frame(width: wp.index == currentWaypointIndex ? 10 : 6)
                            .overlay(
                                Circle().stroke(.white, lineWidth: 1)
                            )
                    }
                }

                // Current position
                if let loc = currentLocation {
                    Annotation("", coordinate: loc) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))

            // Bottom stats bar
            VStack {
                Spacer()
                HStack {
                    VStack(spacing: 0) {
                        Text("DIST")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1fkm", distanceWalked / 1000))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("TIME")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(formatTime(elapsedTime))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("NEXT")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(formatDistance(distanceToNext))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatDistance(_ meters: Double?) -> String {
        guard let m = meters else { return "--" }
        if m < 1000 { return String(format: "%.0fm", m) }
        return String(format: "%.1fkm", m / 1000)
    }
}
