import SwiftUI
@preconcurrency import MapKit
import WalkableKit

struct CreateRouteView: View {
    @State private var viewModel = CreateRouteViewModel()
    @State private var storedMapProxy: MapProxy?
    @State private var isPencilActive = true
    @State private var drawCanvasId = UUID()
    @State private var drawingPoints: [CGPoint] = []
    @State private var mapHeading: Double = 0
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            // Full-screen map
            mapView

            // Drawing canvas (full-screen, between map and controls)
            if viewModel.mode == .draw && isPencilActive && !viewModel.hasRoute && viewModel.waypoints.isEmpty {
                DrawingCanvas(isDrawing: $isPencilActive) { points in
                    drawingPoints = points
                }
                .id(drawCanvasId)
                .ignoresSafeArea()
                .allowsHitTesting(true)
            }

            // Bottom controls + mode selector
            VStack(spacing: 8) {
                Spacer()
                bottomControls
                modeSelector
                    .padding(.bottom, 4)
            }

            // Top controls - pin counter (left) + draw toggle (right, below compass)
            VStack {
                HStack(alignment: .top) {
                    if !viewModel.waypoints.isEmpty {
                        Label("\(viewModel.waypoints.count)", systemImage: "mappin")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                    }
                    Spacer()
                    if viewModel.mode == .draw {
                        drawNavigateToggle
                            .padding(.top, 56)
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 15)
                .padding(.top, 8)
                Spacer()
            }

            // Move mode hint
            if viewModel.movingWaypointIndex != nil {
                VStack {
                    Text("Tap to relocate waypoint \(viewModel.movingWaypointIndex! + 1)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.top, 8)
                    Spacer()
                }
            }

            // Loading overlay
            if viewModel.isCalculating {
                calculatingOverlay
            }
        }
        .sheet(isPresented: $viewModel.showSaveSheet) {
            SaveRouteSheet(viewModel: viewModel, modelContext: modelContext)
                .presentationDetents([.medium])
        }
        .alert("Routing Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $viewModel.cameraPosition, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
                // Waypoint pins
                ForEach(Array(viewModel.waypoints.enumerated()), id: \.offset) { index, coord in
                    Annotation("", coordinate: coord) {
                        ZStack {
                            Circle()
                                .fill(index == 0 ? Color.red : Color.blue)
                                .frame(width: 20, height: 20)
                            Circle()
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 20, height: 20)
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(4)
                        .contentShape(Circle())
                        .shadow(radius: viewModel.movingWaypointIndex == index ? 6 : 2)
                        .background {
                            if viewModel.movingWaypointIndex == index {
                                PulsingRing()
                            }
                        }
                        .contextMenu {
                            Text("Waypoint \(index + 1)")
                            Button {
                                viewModel.movingWaypointIndex = index
                                Haptics.medium()
                            } label: {
                                Label("Move", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                            }
                            Button(role: .destructive) {
                                viewModel.removeWaypoint(at: index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } preview: {
                            VStack {
                                Text("\(index + 1)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(index == 0 ? .red : .blue)
                                Text("Waypoint")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 100, height: 80)
                        }
                    }
                }

                // Calculated route polyline
                if let route = viewModel.calculatedRoute {
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(.blue, lineWidth: 4)
                }

                // Keep user location dot visible when camera moves
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                    .mapControlVisibility(.automatic)
            }
            .onTapGesture { screenCoord in
                guard !viewModel.isCalculating else { return }
                guard let mapCoord = proxy.convert(screenCoord, from: .local) else { return }

                // If moving a waypoint, place it at the tapped location
                if let movingIndex = viewModel.movingWaypointIndex {
                    viewModel.moveWaypoint(at: movingIndex, to: mapCoord)
                    viewModel.movingWaypointIndex = nil
                    return
                }

                guard viewModel.mode == .pin else { return }
                viewModel.addWaypoint(mapCoord)
            }
            .onMapCameraChange { context in
                viewModel.visibleRegion = context.region
                mapHeading = context.camera.heading
            }
            .onAppear { storedMapProxy = proxy }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var modeSelector: some View {
        Picker("Mode", selection: $viewModel.mode) {
            ForEach(RouteCreationMode.allCases, id: \.self) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 16)
        .onChange(of: viewModel.mode) {
            Haptics.light()
            viewModel.clearAll()
            drawingPoints.removeAll()
            isPencilActive = true
            drawCanvasId = UUID()
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        switch viewModel.mode {
        case .pin:
            PinModeOverlay(viewModel: viewModel)
        case .draw:
            DrawModeOverlay(viewModel: viewModel, mapProxy: storedMapProxy, isPencilActive: $isPencilActive, drawnPoints: $drawingPoints, canvasId: $drawCanvasId)
        case .template:
            TemplateModeOverlay(viewModel: viewModel, mapHeading: mapHeading)
        }
    }

    private var drawNavigateToggle: some View {
        Button {
            isPencilActive.toggle()
            Haptics.light()
        } label: {
            Image(systemName: isPencilActive ? "pencil.tip" : "hand.draw")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular, in: .circle)
    }

    private var calculatingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(.blue)
            Text("Calculating route...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

private struct PulsingRing: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .stroke(.blue.opacity(0.6), lineWidth: 2)
            .frame(width: 32, height: 32)
            .scaleEffect(isAnimating ? 2.0 : 1.0)
            .opacity(isAnimating ? 0 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }

}
