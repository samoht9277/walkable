import SwiftUI
import MapKit
import WalkableKit

struct DrawModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel
    var mapProxy: MapProxy?
    @State private var isPencilActive = true
    @State private var drawnPoints: [CGPoint] = []
    @State private var canvasId = UUID()

    var body: some View {
        ZStack {
            // Drawing canvas — only intercepts touches when pencil is active
            if isPencilActive && !viewModel.hasRoute && viewModel.waypoints.isEmpty {
                DrawingCanvas(isDrawing: $isPencilActive) { points in
                    drawnPoints = points
                }
                .id(canvasId)
                .ignoresSafeArea()
            }

            // Pencil/Navigate toggle — top left
            VStack {
                HStack {
                    Button {
                        isPencilActive.toggle()
                        Haptics.light()
                    } label: {
                        Image(systemName: isPencilActive ? "pencil.tip" : "hand.draw")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isPencilActive ? .blue : .white)
                            .frame(width: 40, height: 40)
                    }
                    .glassEffect(.regular, in: .circle)
                    Spacer()
                }
                .padding(.leading, 20)
                Spacer()
            }

            // Bottom controls
            VStack {
                Spacer()

                VStack(spacing: 12) {
                    if viewModel.waypoints.isEmpty && drawnPoints.isEmpty {
                        Text("Draw a loop on the map")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .capsule)
                    }

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
