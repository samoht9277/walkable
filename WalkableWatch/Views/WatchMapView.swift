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
    @Binding var cameraPosition: MapCameraPosition

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition) {
                if let coords = route.decodedPolylineCoordinates {
                    if let currentLoc = currentLocation {
                        let split = PolylineSplitter.split(polyline: coords, at: currentLoc)
                        MapPolyline(coordinates: split.walked)
                            .stroke(.gray, lineWidth: 3)
                        MapPolyline(coordinates: split.remaining)
                            .stroke(.blue, lineWidth: 3)
                    } else {
                        MapPolyline(coordinates: coords)
                            .stroke(.blue, lineWidth: 3)
                    }
                }

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

            // Stats bar - outside the map so swiping here switches pages
            HStack {
                VStack(spacing: 0) {
                    Text("DIST")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(distanceWalked.formattedDistance)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.smooth, value: distanceWalked)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("TIME")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(elapsedTime.formattedDuration)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.smooth, value: elapsedTime)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("NEXT")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(distanceToNext?.formattedDistance ?? "--")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.black)
        }
    }
}
