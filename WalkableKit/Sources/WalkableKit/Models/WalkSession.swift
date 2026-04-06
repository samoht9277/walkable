import Foundation
import SwiftData

@Model
public final class WalkSession {
    public var id: UUID
    public var route: Route?
    public var startedAt: Date
    public var completedAt: Date?
    public var totalDistance: Double
    public var totalDuration: TimeInterval
    public var calories: Double
    public var elevationGain: Double
    public var avgPace: Double
    public var healthKitWorkoutID: UUID?
    public var gpsTrackData: Data?
    public var source: String?
    @Relationship(deleteRule: .cascade, inverse: \LegSplit.session)
    public var legSplits: [LegSplit]

    public init(route: Route) {
        self.id = UUID()
        self.route = route
        self.startedAt = Date()
        self.completedAt = nil
        self.totalDistance = 0
        self.totalDuration = 0
        self.calories = 0
        self.elevationGain = 0
        self.avgPace = 0
        self.healthKitWorkoutID = nil
        self.gpsTrackData = nil
        self.source = nil
        self.legSplits = []
    }

    public var sortedLegSplits: [LegSplit] {
        legSplits.sorted { $0.fromWaypointIndex < $1.fromWaypointIndex }
    }

    public var formattedPace: String {
        avgPace.formattedPace
    }
}
