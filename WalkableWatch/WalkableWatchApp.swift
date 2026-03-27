import SwiftUI
import SwiftData
import WalkableKit

@main
struct WalkableWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Walkable")
        }
        .modelContainer(for: [Route.self, Waypoint.self, WalkSession.self, LegSplit.self])
    }
}
