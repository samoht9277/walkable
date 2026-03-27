import SwiftUI
import MapKit
import WalkableKit

struct WatchCreateRouteView: View {
    @State private var viewModel = WatchCreateViewModel()
    @Environment(\.modelContext) private var modelContext

    let onStartWalk: (Route) -> Void
    let onCancel: () -> Void

    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            // Full-screen map
            MapReader { proxy in
                Map(position: $mapPosition) {
                    // Placed pin markers
                    ForEach(Array(viewModel.waypoints.enumerated()), id: \.offset) { index, coord in
                        Annotation("", coordinate: coord) {
                            ZStack {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 16, height: 16)
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                                    .frame(width: 16, height: 16)
                                Text("\(index + 1)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    // Route polyline (after calculation)
                    if let calc = viewModel.calculatedRoute {
                        MapPolyline(coordinates: calc.coordinates)
                            .stroke(.blue, lineWidth: 3)
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .onMapCameraChange(frequency: .continuous) { context in
                    viewModel.mapCenter = context.camera.centerCoordinate
                }
            }

            // Center crosshair
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)

            // Controls overlay
            VStack {
                Spacer()

                if let error = viewModel.calculationError {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                }

                HStack(spacing: 8) {
                    // Undo button
                    if !viewModel.waypoints.isEmpty {
                        Button {
                            viewModel.undoLastPin()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Pin count
                    if !viewModel.waypoints.isEmpty {
                        Text("\(viewModel.waypoints.count)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Add pin button
                    if viewModel.savedRoute == nil {
                        Button {
                            viewModel.addPin()
                        } label: {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.blue, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Go button (calculate + start walk)
                    if viewModel.canCalculate && viewModel.savedRoute == nil {
                        Button {
                            Task {
                                await viewModel.calculateAndStartWalk(modelContext: modelContext)
                                if let route = viewModel.savedRoute {
                                    onStartWalk(route)
                                }
                            }
                        } label: {
                            if viewModel.isCalculating {
                                ProgressView()
                                    .frame(width: 36, height: 36)
                                    .background(.green, in: Circle())
                            } else {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(.green, in: Circle())
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isCalculating)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("", systemImage: "xmark") {
                    onCancel()
                }
            }
        }
        .onAppear {
            // Center on user location if available
            if let loc = LocationService.shared.currentLocation?.coordinate {
                viewModel.mapCenter = loc
                mapPosition = .camera(MapCamera(centerCoordinate: loc, distance: 1000))
            }
        }
    }
}
