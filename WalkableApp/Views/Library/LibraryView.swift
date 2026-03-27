import SwiftUI
import SwiftData
import WalkableKit

struct LibraryView: View {
    @Query private var routes: [Route]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    @ObservedObject private var locationService = LocationService.shared

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
                            RouteCardView(route: route)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .onTapGesture {
                                    viewModel.selectedRoute = route
                                }
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
            }
            .sheet(item: $viewModel.selectedRoute) { route in
                RouteDetailSheet(route: route) {
                    onStartWalk?(route)
                }
                .presentationDetents([.large])
            }
        }
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
