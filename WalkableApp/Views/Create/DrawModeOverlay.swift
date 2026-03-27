import SwiftUI
import MapKit
import WalkableKit

struct DrawModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel
    var mapProxy: MapProxy?
    @State private var isDrawing = true
    @State private var drawnPoints: [CGPoint] = []

    var body: some View {
        ZStack {
            // Drawing canvas overlay (only when actively drawing)
            if isDrawing && !viewModel.hasRoute {
                DrawingCanvas(isDrawing: $isDrawing) { points in
                    drawnPoints = points
                }
                .ignoresSafeArea()
                .allowsHitTesting(isDrawing)
            }

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    if viewModel.waypoints.isEmpty && drawnPoints.isEmpty {
                        Text("Draw a loop on the map with your finger")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    HStack(spacing: 12) {
                        if !drawnPoints.isEmpty || !viewModel.waypoints.isEmpty {
                            GlassButtonLabel(title: "Clear", systemImage: "trash", action: {
                                drawnPoints.removeAll()
                                viewModel.clearAll()
                                isDrawing = true
                            }, tint: .red)
                        }

                        if !drawnPoints.isEmpty && viewModel.waypoints.isEmpty {
                            GlassButtonLabel(title: "Snap to Roads", systemImage: "road.lanes", action: {
                                convertDrawingToWaypoints()
                            }, tint: .green)
                        }

                        if viewModel.canCalculate && !viewModel.hasRoute {
                            GlassButtonLabel(title: "Calculate", systemImage: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath", action: {
                                Task { await viewModel.calculateRoute() }
                            }, tint: .green)
                        }

                        if viewModel.hasRoute {
                            GlassButtonLabel(title: "Save", systemImage: "square.and.arrow.down", action: {
                                viewModel.showSaveSheet = true
                            }, tint: .blue)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func convertDrawingToWaypoints() {
        guard drawnPoints.count >= 3 else { return }

        guard let mapProxy else {
            viewModel.errorMessage = "Map proxy unavailable, cannot convert drawing."
            return
        }

        // Convert window-coordinate points to real map coordinates via MapProxy
        let realCoords = drawnPoints.compactMap { point in
            mapProxy.convert(point, from: .global)
        }

        guard realCoords.count >= 3 else {
            viewModel.errorMessage = "Could not convert enough points to map coordinates."
            return
        }

        // Simplify and sample using real coordinates
        let simplified = PathSimplifier.simplify(realCoords, tolerance: 0.00005)
        let sampled = PathSimplifier.sampleWaypoints(along: simplified, intervalMeters: 50)

        viewModel.setWaypoints(sampled)
        isDrawing = false
    }
}
