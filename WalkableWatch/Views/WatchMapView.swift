import SwiftUI
import MapKit
import WalkableKit

struct WatchMapView: View {
    let route: Route
    let currentLocation: CLLocationCoordinate2D?
    let currentHeading: Double
    let currentWaypointIndex: Int
    let visitedWaypointIndices: Set<Int>
    let polylineSearchFromIndex: Int
    let timerStartDate: Date
    let distanceWalked: Double
    let elapsedTime: TimeInterval
    let distanceToNext: Double?
    @Binding var cameraPosition: MapCameraPosition
    var onManualMapInteraction: () -> Void = {}
    @Environment(\.isLuminanceReduced) private var isAOD

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition) {
                if let coords = route.decodedPolylineCoordinates {
                    if let currentLoc = currentLocation {
                        let split = PolylineSplitter.split(polyline: coords, at: currentLoc, searchFromIndex: polylineSearchFromIndex, searchWindow: 10)
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
                        let isVisited = visitedWaypointIndices.contains(wp.index)
                        let isNext = wp.index == currentWaypointIndex
                        Circle()
                            .fill(isVisited ? Color.green : (isNext ? Color.orange : Color.blue.opacity(0.5)))
                            .frame(width: (isNext || isVisited) ? 10 : 6)
                            .overlay(
                                Circle().stroke(.white, lineWidth: 1)
                            )
                    }
                }

                if let loc = currentLocation {
                    Annotation("", coordinate: loc) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                            .rotationEffect(.degrees(currentHeading))
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .onMapCameraChange { _ in
                onManualMapInteraction()
            }
            .onChange(of: isAOD) {
                // Re-center map when wrist comes back up or goes down
                if let loc = currentLocation {
                    cameraPosition = .camera(MapCamera(centerCoordinate: loc, distance: 800))
                }
            }

            // Stats bar - outside the map so swiping here switches pages
            HStack {
                VStack(spacing: 0) {
                    Text("DIST")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(distanceWalked.formattedDistance)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("TIME")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(timerStartDate, style: .timer)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
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
