import SwiftUI
import WalkableKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var walkViewModel = ActiveWalkViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            CreateRouteView()
                .tabItem {
                    Label("Create", systemImage: "map")
                }
                .tag(0)
            LibraryView { route in
                Task {
                    await walkViewModel.startWalk(with: route)
                    selectedTab = 2
                }
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            .tag(1)
            ActiveWalkView(viewModel: walkViewModel)
                .tabItem {
                    Label("Walk", systemImage: "figure.walk")
                }
                .tag(2)
            Text("Stats")
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(3)
        }
        .onAppear {
            LocationService.shared.requestAuthorization()
            Task { try? await HealthService.shared.requestAuthorization() }
        }
    }
}
