import SwiftUI
import WalkableKit

struct WalkTabView: View {
    let route: Route
    let onEnd: () -> Void

    @State private var viewModel: WatchWalkViewModel
    @State private var selectedTab = 0

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
                pace: viewModel.distanceWalked > 0 ? viewModel.elapsedTime / (viewModel.distanceWalked / 1000) : 0,
                onDismiss: onEnd
            )
        } else {
            TabView(selection: $selectedTab) {
                // View 1: Route Map
                WatchMapView(
                    route: route,
                    currentLocation: viewModel.currentLocation,
                    currentWaypointIndex: viewModel.currentWaypointIndex,
                    distanceWalked: viewModel.distanceWalked,
                    elapsedTime: viewModel.elapsedTime,
                    distanceToNext: viewModel.distanceToNextWaypoint
                )
                .tag(0)

                // View 2: Compass
                CompassView(
                    arrowAngle: viewModel.relativeArrowAngle,
                    distanceToWaypoint: viewModel.distanceToNextWaypoint,
                    currentWaypointIndex: viewModel.currentWaypointIndex,
                    totalWaypoints: route.waypoints.count
                )
                .tag(1)

                // View 3: Now Playing
                NowPlayingView()
                    .tag(2)
            }
            .tabViewStyle(.verticalPage)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Task { await viewModel.endWalk() }
                    } label: {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .task {
                await viewModel.startWalk()
            }
        }
    }
}
