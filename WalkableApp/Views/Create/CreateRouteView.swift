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

            // Top controls
            VStack {
                modeSelector
                    .padding(.top, 8)
                Spacer()
            }

            // Bottom controls (mode-specific)
            VStack {
                Spacer()
                bottomControls
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
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .onTapGesture { screenCoord in
                guard viewModel.mode == .pin, !viewModel.isCalculating else { return }
                if let mapCoord = proxy.convert(screenCoord, from: .local) {
                    viewModel.addWaypoint(mapCoord)
                }
            }
            .onAppear { storedMapProxy = proxy }
        }
        .ignoresSafeArea()
    }

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(RouteCreationMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.mode = mode
                    }
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(viewModel.mode == mode ? .white : .primary)
                        .background(
                            viewModel.mode == mode
                                ? AnyShapeStyle(.blue)
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                }
            }
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    @ViewBuilder
    private var bottomControls: some View {
        switch viewModel.mode {
        case .pin:
            PinModeOverlay(viewModel: viewModel)
        case .draw:
            DrawModeOverlay(viewModel: viewModel)
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
