import SwiftUI
@preconcurrency import MapKit
import WalkableKit

struct RouteMapOverlay: View {
    let route: Route
    var walkedDistance: Double? = nil
    var currentLocation: CLLocationCoordinate2D? = nil
    var nextWaypointIndex: Int? = nil
    var visitedWaypointIndices: Set<Int> = []
    var polylineSearchFromIndex: Int = 0
    @AppStorage("mapStyle") private var mapStylePref = "standard"

    var body: some View {
        Map {
            if let coords = route.decodedPolylineCoordinates {
                if let currentLoc = currentLocation {
                    let split = PolylineSplitter.split(polyline: coords, at: currentLoc, searchFromIndex: polylineSearchFromIndex, searchWindow: 10)
                    MapPolyline(coordinates: split.walked)
                        .stroke(.gray, lineWidth: 4)
                    MapPolyline(coordinates: split.remaining)
                        .stroke(.blue, lineWidth: 4)
                } else {
                    MapPolyline(coordinates: coords)
                        .stroke(.blue, lineWidth: 4)
                }
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
        .mapStyle(mapStylePref.asMapStyleExcludingPOI)
    }

    @ViewBuilder
    private func waypointMarker(for waypoint: Waypoint) -> some View {
        let isNext = waypoint.index == nextWaypointIndex
        let isVisited = visitedWaypointIndices.contains(waypoint.index)
        let size: CGFloat = isNext ? 20 : 14
        let color: Color = isVisited ? .green : (isNext ? .orange : .blue)
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: size, height: size)
            if isVisited {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            } else if isNext {
                Text("\(waypoint.index + 1)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }
        }
        .shadow(radius: 2)
    }
}
