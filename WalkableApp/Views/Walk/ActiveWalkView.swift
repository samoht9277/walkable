import SwiftUI
import MapKit
import WalkableKit

struct ActiveWalkView: View {
    @Bindable var viewModel: ActiveWalkViewModel
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var locationService = LocationService.shared

    var body: some View {
        ZStack {
            if viewModel.isWalking, let route = viewModel.route {
                // Map with route
                RouteMapOverlay(
                    route: route,
                    walkedDistance: viewModel.distanceWalked,
                    currentLocation: locationService.currentLocation?.coordinate,
                    nextWaypointIndex: viewModel.currentWaypointIndex
                )
                .ignoresSafeArea()

                // Stats and controls overlay
                VStack {
                    // Waypoint arrival notification
                    if viewModel.showArrivalCard, let msg = viewModel.arrivedWaypointMessage {
                        WaypointArrivalCard(waypointName: msg)
                            .padding(.horizontal)
                            .padding(.top, 8)
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
}
