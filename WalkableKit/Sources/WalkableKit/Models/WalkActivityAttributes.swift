import ActivityKit
import Foundation

public struct WalkActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var distance: Double // meters
        public var elapsedTime: TimeInterval
        public var pace: Double // sec/km
        public var nextWaypointDistance: Double? // meters
        public var currentWaypointIndex: Int
        public var totalWaypoints: Int

        public init(
            distance: Double,
            elapsedTime: TimeInterval,
            pace: Double,
            nextWaypointDistance: Double?,
            currentWaypointIndex: Int,
            totalWaypoints: Int
        ) {
            self.distance = distance
            self.elapsedTime = elapsedTime
            self.pace = pace
            self.nextWaypointDistance = nextWaypointDistance
            self.currentWaypointIndex = currentWaypointIndex
            self.totalWaypoints = totalWaypoints
        }
    }

    public var routeName: String
    public var totalDistance: Double

    public init(routeName: String, totalDistance: Double) {
        self.routeName = routeName
        self.totalDistance = totalDistance
    }
}
