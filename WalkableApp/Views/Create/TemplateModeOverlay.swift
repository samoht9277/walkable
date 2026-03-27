import SwiftUI
import CoreLocation
import WalkableKit

enum TemplateShape: String, CaseIterable {
    case loop = "Loop"
    case outAndBack = "Out & Back"
    case figure8 = "Figure-8"

    var icon: String {
        switch self {
        case .loop: return "circle"
        case .outAndBack: return "arrow.left.arrow.right"
        case .figure8: return "infinity"
        }
    }
}

struct TemplateModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel
    @State private var selectedShape: TemplateShape = .loop
    @State private var targetDistanceKm: Double = 2.0

    private let locationService = LocationService.shared

    var body: some View {
        VStack(spacing: 12) {
            // Shape picker
            HStack(spacing: 8) {
                ForEach(TemplateShape.allCases, id: \.self) { shape in
                    Button {
                        selectedShape = shape
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: shape.icon)
                                .font(.title3)
                            Text(shape.rawValue)
                                .font(.caption2)
                        }
                        .frame(width: 80, height: 56)
                        .foregroundStyle(selectedShape == shape ? .white : .primary)
                        .background(
                            selectedShape == shape
                                ? AnyShapeStyle(.blue)
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            // Distance slider
            VStack(spacing: 4) {
                Text(String(format: "%.1f km", targetDistanceKm))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Slider(value: $targetDistanceKm, in: 0.5...10, step: 0.5)
                    .tint(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            HStack(spacing: 12) {
                if !viewModel.waypoints.isEmpty {
                    GlassButtonLabel(title: "Clear", systemImage: "trash", action: {
                        viewModel.clearAll()
                    }, tint: .red)
                }

                GlassButtonLabel(title: "Generate", systemImage: "wand.and.stars", action: {
                    generateTemplate()
                }, tint: .green)

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
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func centerCoordinate() -> CLLocationCoordinate2D? {
        if let gps = locationService.currentLocation?.coordinate { return gps }
        if let region = viewModel.visibleRegion { return region.center }
        return nil
    }

    private func generateTemplate() {
        guard let location = centerCoordinate() else {
            viewModel.errorMessage = "Pan the map to your desired location and try again."
            return
        }

        let distanceMeters = targetDistanceKm * 1000

        let waypoints: [CLLocationCoordinate2D]
        switch selectedShape {
        case .loop:
            waypoints = TemplateGenerator.loop(center: location, targetDistanceMeters: distanceMeters)
        case .outAndBack:
            waypoints = TemplateGenerator.outAndBack(center: location, targetDistanceMeters: distanceMeters, bearingDegrees: 0)
        case .figure8:
            waypoints = TemplateGenerator.figure8(center: location, targetDistanceMeters: distanceMeters)
        }

        viewModel.setWaypoints(waypoints)
    }
}
