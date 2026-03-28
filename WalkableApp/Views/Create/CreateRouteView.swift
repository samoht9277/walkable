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

            // Bottom controls
            VStack {
                Spacer()
                bottomControls
            }

            // Top controls - rendered last so they stay clickable above the canvas
            VStack(spacing: 6) {
                modeSelector
                    .padding(.top, 8)
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
                    VStack(spacing: 8) {
                        compassButton
                        if viewModel.mode == .draw {
                            drawNavigateToggle
                        }
                    }
                }
                .padding(.horizontal, 20)
                Spacer()
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
                                .frame(width: 16, height: 16)
                            Circle()
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 16, height: 16)
                            Text("\(index + 1)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(radius: 2)
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
            .mapControls { }
            .onTapGesture { screenCoord in
                guard viewModel.mode == .pin, !viewModel.isCalculating else { return }
                if let mapCoord = proxy.convert(screenCoord, from: .local) {
                    viewModel.addWaypoint(mapCoord)
                }
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
            TemplateModeOverlay(viewModel: viewModel)
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
                .frame(width: 40, height: 40)
        }
        .glassEffect(.regular, in: .circle)
    }

    @ViewBuilder
    private var compassButton: some View {
        if abs(mapHeading) > 0.5 {
            Button {
                withAnimation(.smooth) {
                    guard let region = viewModel.visibleRegion else { return }
                    viewModel.cameraPosition = .camera(MapCamera(
                        centerCoordinate: region.center,
                        distance: max(region.span.latitudeDelta, region.span.longitudeDelta) * 111000,
                        heading: 0
                    ))
                }
                Haptics.light()
            } label: {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red, .white)
                    .rotationEffect(.degrees(-mapHeading))
                    .animation(.smooth(duration: 0.15), value: mapHeading)
                    .frame(width: 36, height: 36)
            }
            .glassEffect(.regular, in: .circle)
            .transition(.scale.combined(with: .opacity))
        }
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
