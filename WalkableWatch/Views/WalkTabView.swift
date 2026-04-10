import SwiftUI
import MapKit
import WalkableKit

struct WalkTabView: View {
    let route: Route
    let onEnd: () -> Void

    @State private var viewModel: WatchWalkViewModel
    @State private var selectedTab = 1
    @Environment(\.isLuminanceReduced) private var isAOD

    init(route: Route, onEnd: @escaping () -> Void) {
        self.route = route
        self.onEnd = onEnd
        _viewModel = State(initialValue: WatchWalkViewModel(route: route))
    }

    var body: some View {
        if viewModel.showSummary {
            WatchSummaryView(
                distance: viewModel.distanceWalked,
                duration: viewModel.elapsedTime,
                pace: viewModel.currentPace,
                onDismiss: onEnd
            )
        } else {
            ZStack {
            TabView(selection: $selectedTab) {
                // View 1: Controls
                WalkControlsView(
                    timerStartDate: viewModel.timerStartDate,
                    elapsedTime: viewModel.elapsedTime,
                    distance: viewModel.distanceWalked,
                    pace: viewModel.currentPace,
                    heartRate: viewModel.heartRate,
                    currentWaypointIndex: viewModel.currentWaypointIndex,
                    totalWaypoints: viewModel.route.waypoints.count,
                    isPaused: viewModel.isPaused,
                    loopCompleted: viewModel.loopCompleted,
                    onPause: { viewModel.pauseWalk() },
                    onResume: { viewModel.resumeWalk() },
                    onEnd: { Task { await viewModel.endWalk() } }
                )
                .tag(0)

                // View 2: Top-down Map (default)
                WatchMapView(
                    route: route,
                    currentLocation: viewModel.currentLocation,
                    currentWaypointIndex: viewModel.currentWaypointIndex,
                    visitedWaypointIndices: viewModel.visitedWaypointIndices,
                    polylineSearchFromIndex: viewModel.lastPolylineSegmentIndex,
                    timerStartDate: viewModel.timerStartDate,
                    distanceWalked: viewModel.distanceWalked,
                    elapsedTime: viewModel.elapsedTime,
                    distanceToNext: viewModel.distanceToNextWaypoint,
                    cameraPosition: Binding(
                        get: { viewModel.mapCameraPosition },
                        set: { viewModel.mapCameraPosition = $0 }
                    ),
                    onManualMapInteraction: {
                        viewModel.lastManualMapInteraction = Date()
                    }
                )
                .tag(1)

                // View 3: Compass
                CompassView(
                    arrowAngle: viewModel.relativeArrowAngle,
                    distanceToWaypoint: viewModel.distanceToNextWaypoint,
                    currentWaypointIndex: viewModel.currentWaypointIndex,
                    totalWaypoints: route.waypoints.count
                )
                .tag(2)

                // View 4: Now Playing
                WalkableNowPlayingView()
                    .tag(3)
            }
            .tabViewStyle(.page)
            .opacity(isAOD ? 0.6 : 1.0)
            .allowsHitTesting(!isAOD)
            .onChange(of: selectedTab) {
                // Re-center map when swiping to the map tab
                if selectedTab == 1, let loc = viewModel.currentLocation {
                    viewModel.mapCameraPosition = .camera(MapCamera(
                        centerCoordinate: loc, distance: 800
                    ))
                }
            }
            .onChange(of: isAOD) {
                if isAOD {
                    selectedTab = 0
                }
                // Re-center map when waking from AOD or going to sleep
                if let loc = viewModel.currentLocation {
                    viewModel.mapCameraPosition = .camera(MapCamera(
                        centerCoordinate: loc, distance: 800
                    ))
                }
            }
            .task {
                await viewModel.startWalk()
            }

            // Waypoint arrival banner overlay
            VStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(viewModel.arrivedWaypointName ?? "")
                        .font(.headline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)
            .opacity(viewModel.showArrivalBanner && !isAOD ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: viewModel.showArrivalBanner)
            .allowsHitTesting(false)
            } // ZStack
            .animation(.easeInOut(duration: 0.5), value: viewModel.showArrivalBanner)
        }
    }
}
