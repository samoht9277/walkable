import SwiftUI
import WalkableKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var walkViewModel = ActiveWalkViewModel()
    @State private var isReady = false

    var body: some View {
        ZStack {
            if !isReady {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "figure.walk.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                            Text("Walkable")
                                .font(.title2.weight(.bold))
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.3)) { isReady = true }
                        }
                    }
            }

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
                StatsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }
                    .tag(3)
            }

            // Active walk banner on non-Walk tabs
            if (walkViewModel.isWalking || walkViewModel.isWalkingOnWatch) && selectedTab != 2 {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "figure.walk")
                        Text("Walk in progress")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(walkViewModel.elapsedTime.formattedDuration)
                            .font(.subheadline.monospacedDigit())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 60)
                    .onTapGesture { selectedTab = 2 }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.smooth, value: selectedTab)
            }
        }
        .onAppear {
            LocationService.shared.requestAuthorization()
            Task { try? await HealthService.shared.requestAuthorization() }
        }
    }
}
