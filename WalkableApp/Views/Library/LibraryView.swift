import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CoreLocation
import WalkableKit

struct LibraryView: View {
    @Query private var routes: [Route]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @State private var showImportPicker = false
    @State private var importError: String?
    @State private var showImportError = false

    // Callback when user starts a walk from library
    var onStartWalk: ((Route) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tag filter chips
                if !viewModel.allTags(routes).isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            tagChip("All", isSelected: viewModel.selectedTag == nil) {
                                viewModel.selectedTag = nil
                            }
                            ForEach(viewModel.allTags(routes), id: \.self) { tag in
                                tagChip(tag, isSelected: viewModel.selectedTag == tag) {
                                    viewModel.selectedTag = viewModel.selectedTag == tag ? nil : tag
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }

                // Route list
                let filtered = viewModel.filteredRoutes(routes, currentLocation: locationService.currentLocation)

                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Routes",
                        systemImage: "map",
                        description: Text("Create your first walking loop in the Create tab")
                    )
                } else {
                    List {
                        ForEach(filtered) { route in
                            Button {
                                viewModel.selectedRoute = route
                            } label: {
                                RouteCardView(route: route)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button {
                                    viewModel.toggleFavorite(route)
                                } label: {
                                    Label(
                                        route.isFavorite ? "Unfavorite" : "Favorite",
                                        systemImage: route.isFavorite ? "star.slash" : "star.fill"
                                    )
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteRoute(route, modelContext: modelContext)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
            .searchable(text: $viewModel.searchText, prompt: "Search routes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(RouteSortOption.allCases, id: \.self) { option in
                            Button {
                                viewModel.sortOption = option
                            } label: {
                                Label(option.rawValue, systemImage: viewModel.sortOption == option ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showImportPicker = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.xml, UTType(filenameExtension: "gpx") ?? .xml]
            ) { result in
                handleImport(result)
            }
            .alert("Import Failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "Could not read GPX file.")
            }
            .sheet(item: $viewModel.selectedRoute) { route in
                RouteDetailSheet(route: route) {
                    onStartWalk?(route)
                }
                .presentationDetents([.large])
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            importError = "Could not access the file."
            showImportError = true
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            importError = "Permission denied."
            showImportError = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let gpxString = try? String(contentsOf: url, encoding: .utf8),
              let gpxData = GPXService.parse(gpxString: gpxString) else {
            importError = "Invalid or unreadable GPX file."
            showImportError = true
            return
        }

        let route = Route(name: gpxData.name ?? url.deletingPathExtension().lastPathComponent)

        for (index, wp) in gpxData.waypoints.enumerated() {
            let waypoint = Waypoint(index: index, latitude: wp.latitude, longitude: wp.longitude, label: wp.name)
            route.waypoints.append(waypoint)
        }

        if !gpxData.trackPoints.isEmpty {
            let coords = gpxData.trackPoints.map { CodableCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
            route.polylineData = try? JSONEncoder().encode(coords)

            var totalDistance = 0.0
            for i in 1..<gpxData.trackPoints.count {
                let a = CLLocation(latitude: gpxData.trackPoints[i - 1].latitude, longitude: gpxData.trackPoints[i - 1].longitude)
                let b = CLLocation(latitude: gpxData.trackPoints[i].latitude, longitude: gpxData.trackPoints[i].longitude)
                totalDistance += a.distance(from: b)
            }
            route.distance = totalDistance
            // Estimate walking time at 5 km/h
            route.estimatedDuration = totalDistance / (5000.0 / 3600.0)
        }

        let allLats = gpxData.waypoints.map(\.latitude) + gpxData.trackPoints.map(\.latitude)
        let allLons = gpxData.waypoints.map(\.longitude) + gpxData.trackPoints.map(\.longitude)
        if let minLat = allLats.min(), let maxLat = allLats.max(),
           let minLon = allLons.min(), let maxLon = allLons.max() {
            route.centerLatitude = (minLat + maxLat) / 2
            route.centerLongitude = (minLon + maxLon) / 2
        }

        modelContext.insert(route)
        try? modelContext.save()
        Haptics.success()
        SyncService.shared.syncRoute(route, operation: .create)
    }

    private func tagChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? Color.blue : Color.clear)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
}
