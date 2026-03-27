import SwiftUI

struct PinModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel

    private var hasButtons: Bool {
        viewModel.isCalculating || !viewModel.waypoints.isEmpty || viewModel.hasRoute
    }

    var body: some View {
        VStack(spacing: 12) {
            if hasButtons {
                HStack(spacing: 8) {
                    if viewModel.isCalculating {
                        GlassButtonLabel(title: "Cancel", systemImage: "xmark", action: {
                            viewModel.cancelCalculation()
                        }, tint: .red)
                    } else {
                        if !viewModel.waypoints.isEmpty {
                            GlassButtonLabel(title: "Undo", systemImage: "arrow.uturn.backward") {
                                viewModel.undoLastWaypoint()
                            }
                        }

                        if viewModel.waypoints.count >= 2 {
                            GlassButtonLabel(title: "Clear", systemImage: "trash", action: {
                                viewModel.clearAll()
                            }, tint: .red)
                        }

                        if viewModel.canCalculate && !viewModel.hasRoute {
                            GlassButtonLabel(title: "Calculate", systemImage: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath", action: {
                                viewModel.calculateRoute()
                            }, tint: .green)
                        }

                        if viewModel.hasRoute {
                            GlassButtonLabel(title: "Save", systemImage: "square.and.arrow.down", action: {
                                viewModel.showSaveSheet = true
                            }, tint: .blue)
                        }
                    }
                }
                .padding(.horizontal, 16)
            } else {
                Text("Tap the map to place waypoints")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .padding(.bottom, 24)
    }
}
