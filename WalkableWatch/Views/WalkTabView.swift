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
                    currentHeading: viewModel.currentHeading,
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
                    )
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
            .onChange(of: isAOD) {
                if isAOD { selectedTab = 0 }
            }
            .task {
                await viewModel.startWalk()
            }

            // Waypoint arrival banner overlay
            if viewModel.showArrivalBanner, let name = viewModel.arrivedWaypointName {
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(name)
                            .font(.headline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.2), in: Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(duration: 0.4), value: viewModel.showArrivalBanner)
            }
            } // ZStack
        }
    }
}
