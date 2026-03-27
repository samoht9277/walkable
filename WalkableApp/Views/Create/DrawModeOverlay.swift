import SwiftUI
import MapKit
import WalkableKit

struct DrawModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel
    var mapProxy: MapProxy?
    @State private var isDrawing = true
    @State private var drawnPoints: [CGPoint] = []
    @State private var canvasId = UUID()

    var body: some View {
        ZStack {
            if isDrawing && !viewModel.hasRoute {
                DrawingCanvas(isDrawing: $isDrawing) { points in
                    drawnPoints = points
                }
                .id(canvasId)
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
                            .glassEffect(.regular, in: .capsule)
                    }

                    HStack(spacing: 12) {
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
                                    isDrawing = true
                                }, tint: .red)
                            }

                            if !drawnPoints.isEmpty && viewModel.waypoints.isEmpty {
                                GlassButtonLabel(title: "Snap to Roads", systemImage: "road.lanes", action: {
                                    Haptics.medium()
                                    convertDrawingToWaypoints()
                                    viewModel.calculateRoute()
                                }, tint: .green)
                            }
                        }

                        if !viewModel.isCalculating && viewModel.canCalculate && !viewModel.hasRoute {
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
                    .padding(.horizontal, 16)
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
