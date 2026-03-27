import Foundation
import SwiftData

@Model
public final class LegSplit {
    public var id: UUID
    public var session: WalkSession?
    public var fromWaypointIndex: Int
    public var toWaypointIndex: Int
    public var distance: Double
    public var duration: TimeInterval
    public var pace: Double

    public init(
        session: WalkSession,
        fromWaypointIndex: Int,
        toWaypointIndex: Int,
        distance: Double,
        duration: TimeInterval,
        pace: Double
    ) {
        self.id = UUID()
        self.session = session
        self.fromWaypointIndex = fromWaypointIndex
        self.toWaypointIndex = toWaypointIndex
        self.distance = distance
        self.duration = duration
        self.pace = pace
    }

    public var formattedPace: String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}
