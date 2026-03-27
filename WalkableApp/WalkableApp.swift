import SwiftUI
import SwiftData
import WalkableKit

@main
struct WalkableApp: App {
    init() {
        // Activate WatchConnectivity sync
        _ = SyncService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Route.self, Waypoint.self, WalkSession.self, LegSplit.self])
    }
}
