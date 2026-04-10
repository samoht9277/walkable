import SwiftUI
import MapKit
import WalkableKit

struct WatchMapView: View {
    let route: Route
    let currentLocation: CLLocationCoordinate2D?
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
        ZStack(alignment: .bottom) {
            // Full-screen map
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
                        Circle()
                            .fill(.blue)
                            .frame(width: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .onMapCameraChange { _ in
                onManualMapInteraction()
            }
            .onChange(of: isAOD) {
                if let loc = currentLocation {
                    cameraPosition = .camera(MapCamera(centerCoordinate: loc, distance: 800))
                }
            }

            // Glass stats bar overlaid on map
                TimelineView(.periodic(from: .now, by: 3)) { timeline in
                    let index = Int(timeline.date.timeIntervalSinceReferenceDate / 3) % 3
                    HStack(spacing: 4) {
                        Group {
                            switch index {
                            case 0:
                                Image(systemName: "ruler")
                                Text(distanceWalked.formattedDistance)
                            case 1:
                                Image(systemName: "clock")
                                Text(timerStartDate, style: .timer)
                            default:
                                Image(systemName: "mappin")
                                Text(distanceToNext?.formattedDistance ?? "--")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .frame(width: 130)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle().inset(by: -25))
                    .offset(y: 18)
                    .ignoresSafeArea()
                    .contentTransition(.numericText())
                    .animation(.smooth, value: index)
                }
        }
    }
}
