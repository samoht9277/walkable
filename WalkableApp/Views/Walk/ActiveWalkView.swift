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
