import SwiftUI
import SwiftData
import WalkableKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var walkViewModel = ActiveWalkViewModel()
    @State private var isReady = false
    @Environment(\.modelContext) private var modelContext
    @Query private var allRoutes: [Route]

    var body: some View {
        ZStack {
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

            // Splash overlay (TabView renders behind so MapKit initializes)
            if !isReady {
                LinearGradient(colors: [Color(red: 0, green: 0.78, blue: 0.92), Color(red: 0.12, green: 0.47, blue: 1.0)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .overlay {
                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)
                    }
                    .task {
                        try? await Task.sleep(for: .seconds(1))
                        withAnimation(.easeOut(duration: 0.4)) { isReady = true }
                    }
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
            // Sync routes to Watch on launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                SyncService.shared.syncAllRoutes(allRoutes)
            }
        }
        .onReceive(SyncService.shared.watchBecameReachable) {
            SyncService.shared.syncAllRoutes(allRoutes)
        }
        .onChange(of: allRoutes.count) {
            SyncService.shared.syncAllRoutes(allRoutes)
        }
        .onReceive(SyncService.shared.sessionSyncReceived) { payload in
            walkViewModel.pendingWatchSession = payload
            saveWatchSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .endWalkFromDI)) { _ in
            Task {
                await walkViewModel.endWalk(modelContext: modelContext)
            }
        }
    }

    private func saveWatchSession() {
        guard let payload = walkViewModel.pendingWatchSession else { return }
        walkViewModel.pendingWatchSession = nil

        // Find the route by ID
        guard let routeId = UUID(uuidString: payload.routeId),
              let route = allRoutes.first(where: { $0.id == routeId }) else { return }

        let session = WalkSession(route: route)
        session.startedAt = payload.startedAt
        session.completedAt = payload.completedAt
        session.totalDistance = payload.totalDistance
        session.totalDuration = payload.totalDuration
        session.calories = payload.calories
        session.elevationGain = payload.elevationGain
        session.avgPace = payload.avgPace

        // Store GPS track
        if let gpsTrack = payload.gpsTrack {
            session.gpsTrackData = try? JSONEncoder().encode(gpsTrack)
        }

        // Store analysis data from Watch
        session.analysisData = payload.analysisData

        // Store leg splits
        for split in payload.legSplits {
            let legSplit = LegSplit(
                session: session,
                fromWaypointIndex: split.fromWaypointIndex,
                toWaypointIndex: split.toWaypointIndex,
                distance: split.distance,
                duration: split.duration,
                pace: split.pace
            )
            session.legSplits.append(legSplit)
        }

        session.source = payload.source ?? "watch"

        modelContext.insert(session)
        try? modelContext.save()
    }
}
