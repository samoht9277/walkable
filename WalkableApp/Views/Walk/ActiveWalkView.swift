import SwiftUI
import MapKit
import WalkableKit

struct ActiveWalkView: View {
    @Bindable var viewModel: ActiveWalkViewModel
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var locationService = LocationService.shared

    var body: some View {
        ZStack {
            if viewModel.isWalkingOnWatch, let route = viewModel.route {
                // Passive Watch handoff view
                watchHandoffView(route: route)
            } else if viewModel.isWalking, let route = viewModel.route {
                // Map layer: overview or follow mode
                if viewModel.isFollowMode {
                    followModeMap(route: route)
                        .ignoresSafeArea()
                } else {
                    RouteMapOverlay(
                        route: route,
                        walkedDistance: viewModel.distanceWalked,
                        currentLocation: locationService.currentLocation?.coordinate,
                        nextWaypointIndex: viewModel.currentWaypointIndex
                    )
                    .ignoresSafeArea()
                }

                // Stats and controls overlay
                VStack {
                    HStack {
                        Spacer()
                        // View mode toggle
                        Button {
                            viewModel.isFollowMode.toggle()
                            if viewModel.isFollowMode,
                               let loc = locationService.currentLocation?.coordinate {
                                viewModel.updateFollowCamera(location: loc)
                            }
                            Haptics.light()
                        } label: {
                            Image(systemName: viewModel.isFollowMode ? "map" : "location.viewfinder")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.glass)
                        .padding(.trailing, 12)
                        .padding(.top, 8)
                    }

                    // Waypoint arrival notification
                    if viewModel.showArrivalCard, let msg = viewModel.arrivedWaypointMessage {
                        WaypointArrivalCard(waypointName: msg)
                            .padding(.horizontal)
                    }

                    Spacer()

                    // Stats bar
                    WalkStatsBar(
                        distance: viewModel.distanceWalked,
                        elapsed: viewModel.elapsedTime,
                        pace: viewModel.currentPace,
                        calories: viewModel.calories
                    )
                    .padding(.horizontal)

                    // Controls
                    HStack(spacing: 20) {
                        GlassButtonLabel(
                            title: viewModel.isPaused ? "Resume" : "Pause",
                            systemImage: viewModel.isPaused ? "play.fill" : "pause.fill"
                        ) {
                            if viewModel.isPaused {
                                viewModel.resumeWalk()
                            } else {
                                viewModel.pauseWalk()
                            }
                        }

                        GlassButtonLabel(title: "End Walk", systemImage: "stop.fill", action: {
                            Task { await viewModel.endWalk(modelContext: modelContext) }
                        }, tint: .red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 24)
                }
            } else {
                // No active walk
                ContentUnavailableView(
                    "No Active Walk",
                    systemImage: "figure.walk",
                    description: Text("Start a walk from your Library to begin tracking")
                )
            }
        }
        .sheet(isPresented: $viewModel.showSummary) {
            WalkSummaryView(
                distance: viewModel.distanceWalked,
                duration: viewModel.elapsedTime,
                pace: viewModel.currentPace,
                calories: viewModel.calories,
                onDismiss: { viewModel.dismissSummary() }
            )
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private func followModeMap(route: Route) -> some View {
        Map(position: Bindable(viewModel).followCameraPosition) {
            if let coords = route.decodedPolylineCoordinates {
                if let currentLoc = locationService.currentLocation?.coordinate {
                    let split = PolylineSplitter.split(polyline: coords, at: currentLoc)
                    MapPolyline(coordinates: split.walked)
                        .stroke(.gray, lineWidth: 4)
                    MapPolyline(coordinates: split.remaining)
                        .stroke(.blue, lineWidth: 4)
                } else {
                    MapPolyline(coordinates: coords)
                        .stroke(.blue, lineWidth: 4)
                }
            }

            // Next waypoint marker
            if viewModel.currentWaypointIndex < route.sortedWaypoints.count {
                let wp = route.sortedWaypoints[viewModel.currentWaypointIndex]
                Annotation(wp.label ?? "Waypoint \(wp.index + 1)", coordinate: wp.coordinate) {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 20, height: 20)
                        Text("\(wp.index + 1)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                    .shadow(radius: 2)
                }
            }

            // User location marker
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControlVisibility(.hidden)
    }

    @ViewBuilder
    private func watchHandoffView(route: Route) -> some View {
        ZStack {
            // Show the route on a map (passive, no live tracking)
            RouteMapOverlay(route: route)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)

                    Text("Walk in progress on Apple Watch")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text(route.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.1f km · %d waypoints", route.distance / 1000, route.waypoints.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Results will sync back when the walk is complete")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }
}
