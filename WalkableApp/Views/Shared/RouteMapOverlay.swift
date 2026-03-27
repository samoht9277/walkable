import SwiftUI
@preconcurrency import MapKit
import WalkableKit

struct RouteMapOverlay: View {
    let route: Route
    var walkedDistance: Double? = nil
    var currentLocation: CLLocationCoordinate2D? = nil
    var nextWaypointIndex: Int? = nil

    var body: some View {
        Map {
            if let coords = route.decodedPolylineCoordinates {
                MapPolyline(coordinates: coords)
                    .stroke(.blue, lineWidth: 4)
            }

            // Waypoint annotations
            ForEach(route.sortedWaypoints, id: \.id) { waypoint in
                Annotation(
                    waypoint.label ?? "Waypoint \(waypoint.index + 1)",
                    coordinate: waypoint.coordinate
                ) {
                    waypointMarker(for: waypoint)
                }
            }

            // Current position
            if let current = currentLocation {
                Annotation("You", coordinate: current) {
                    Circle()
                        .fill(.green)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 4)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    @ViewBuilder
    private func waypointMarker(for waypoint: Waypoint) -> some View {
        let isNext = waypoint.index == nextWaypointIndex
        ZStack {
            Circle()
                .fill(isNext ? Color.orange : Color.blue)
                .frame(width: isNext ? 20 : 14, height: isNext ? 20 : 14)
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: isNext ? 20 : 14, height: isNext ? 20 : 14)
            if isNext {
                Text("\(waypoint.index + 1)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }
        }
        .shadow(radius: 2)
    }
}
