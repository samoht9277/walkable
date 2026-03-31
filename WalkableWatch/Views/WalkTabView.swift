import SwiftUI
import WalkableKit

struct WalkTabView: View {
    let route: Route
    let onEnd: () -> Void

    @State private var viewModel: WatchWalkViewModel
    @State private var selectedTab = 1

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
            TabView(selection: $selectedTab) {
                // View 1: Controls
                WalkControlsView(
                    elapsedTime: viewModel.elapsedTime,
                    distance: viewModel.distanceWalked,
                    pace: viewModel.currentPace,
                    isPaused: viewModel.isPaused,
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
                    distanceWalked: viewModel.distanceWalked,
                    elapsedTime: viewModel.elapsedTime,
                    distanceToNext: viewModel.distanceToNextWaypoint
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
            .task {
                await viewModel.startWalk()
            }
        }
    }
}
