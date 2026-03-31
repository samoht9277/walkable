import SwiftUI
import MapKit
import WalkableKit

struct DrawModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel
    var mapProxy: MapProxy?
    @Binding var isPencilActive: Bool
    @Binding var drawnPoints: [CGPoint]
    @Binding var canvasId: UUID

    private var hasButtons: Bool {
        viewModel.isCalculating || !viewModel.waypoints.isEmpty || viewModel.hasRoute || !drawnPoints.isEmpty
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
                        if !drawnPoints.isEmpty || !viewModel.waypoints.isEmpty {
                            GlassButtonLabel(title: "Clear", systemImage: "trash", action: {
                                drawnPoints.removeAll()
                                viewModel.clearAll()
                                canvasId = UUID()
                                isPencilActive = true
                            }, tint: .red)
                        }

                        if !drawnPoints.isEmpty && viewModel.waypoints.isEmpty {
                            GlassButtonLabel(title: "Snap to Roads", systemImage: "road.lanes", action: {
                                Haptics.medium()
                                convertDrawingToWaypoints()
                                viewModel.calculateRoute()
                            }, tint: .green)
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
                Text("Draw a loop on the map")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .padding(.bottom, 2)
    }

    private func convertDrawingToWaypoints() {
        guard drawnPoints.count >= 3 else { return }

        guard let mapProxy else {
            viewModel.errorMessage = "Map proxy unavailable, cannot convert drawing."
            return
        }

        let realCoords = drawnPoints.compactMap { point in
            mapProxy.convert(point, from: .global)
        }

        guard realCoords.count >= 3 else {
            viewModel.errorMessage = "Could not convert enough points to map coordinates."
            return
        }

        let simplified = PathSimplifier.simplify(realCoords, tolerance: 0.00005)
        let sampled = PathSimplifier.sampleWaypoints(along: simplified, intervalMeters: 50)

        viewModel.setWaypoints(sampled)
        isPencilActive = false
    }
}
