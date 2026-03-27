import SwiftUI
@preconcurrency import MapKit
import WalkableKit

struct CreateRouteView: View {
    @State private var viewModel = CreateRouteViewModel()
    @State private var storedMapProxy: MapProxy?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            // Full-screen map
            mapView

            // Bottom controls (mode-specific) - rendered before mode selector
            // so the drawing canvas doesn't cover the mode selector
            VStack {
                Spacer()
                bottomControls
            }

            // Top controls - rendered last so they stay clickable above the canvas
            VStack {
                modeSelector
                    .padding(.top, 8)
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
            Map(position: $viewModel.cameraPosition) {
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
            .mapStyle(.standard(elevation: .flat))
            .mapControls { }
            .onTapGesture { screenCoord in
                guard viewModel.mode == .pin, !viewModel.isCalculating else { return }
                if let mapCoord = proxy.convert(screenCoord, from: .local) {
                    viewModel.addWaypoint(mapCoord)
                }
            }
            .onMapCameraChange { context in
                viewModel.visibleRegion = context.region
            }
            .onAppear { storedMapProxy = proxy }
        }
        .ignoresSafeArea()
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 8)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .onChange(of: viewModel.mode) {
            viewModel.clearAll()
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        switch viewModel.mode {
        case .pin:
            PinModeOverlay(viewModel: viewModel)
        case .draw:
            DrawModeOverlay(viewModel: viewModel, mapProxy: storedMapProxy)
        case .template:
            TemplateModeOverlay(viewModel: viewModel)
        }
    }

    private var calculatingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Calculating route...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
}
