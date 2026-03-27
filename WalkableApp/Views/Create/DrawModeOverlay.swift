import SwiftUI
import MapKit
import WalkableKit

struct DrawModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel
    @State private var isDrawing = true
    @State private var drawnPoints: [CGPoint] = []
    @State private var mapProxy: MapProxy?

    var body: some View {
        ZStack {
            // Drawing canvas overlay (only when actively drawing)
            if isDrawing && !viewModel.hasRoute {
                DrawingCanvas(isDrawing: $isDrawing) { points in
                    drawnPoints = points
                }
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
        // Convert screen points to coordinates would need MapProxy,
        // but for now we use a simplified approach:
        // The drawn points are in screen coordinates. We need the MapReader proxy
        // to convert them. This is wired up through CreateRouteView.
        // For now, use PathSimplifier on the points as a 2D approximation.

        guard drawnPoints.count >= 3 else { return }

        // Simplify the screen-space points first
        let coordPoints = drawnPoints.map {
            CLLocationCoordinate2D(latitude: Double($0.y), longitude: Double($0.x))
        }
        let simplified = PathSimplifier.simplify(coordPoints, tolerance: 20)
        let sampled = PathSimplifier.sampleWaypoints(along: simplified, intervalMeters: 50)

        // This needs proper screen-to-map coordinate conversion
        // which will be connected via the MapReader proxy in CreateRouteView
        viewModel.setWaypoints(sampled.map { $0 })
        isDrawing = false
    }
}
