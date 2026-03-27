import Foundation
import SwiftData
import CoreLocation

@Model
public final class Route {
    public var id: UUID
    public var name: String
    public var tags: [String]
    public var isFavorite: Bool
    public var distance: Double
    public var estimatedDuration: TimeInterval
    public var createdAt: Date
    public var centerLatitude: Double
    public var centerLongitude: Double
    @Relationship(deleteRule: .cascade, inverse: \Waypoint.route)
    public var waypoints: [Waypoint]
    public var polylineData: Data?
    @Relationship(deleteRule: .cascade, inverse: \WalkSession.route)
    public var sessions: [WalkSession]

    public init(
        name: String,
        tags: [String] = [],
        isFavorite: Bool = false,
        distance: Double = 0,
        estimatedDuration: TimeInterval = 0,
        centerLatitude: Double = 0,
        centerLongitude: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.tags = tags
        self.isFavorite = isFavorite
        self.distance = distance
        self.estimatedDuration = estimatedDuration
        self.createdAt = Date()
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.waypoints = []
        self.polylineData = nil
        self.sessions = []
    }

    public var sortedWaypoints: [Waypoint] {
        waypoints.sorted { $0.index < $1.index }
    }

    public var sessionCount: Int {
        sessions.count
    }

    public var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }

    public var decodedPolylineCoordinates: [CLLocationCoordinate2D]? {
        polylineData?.decodedCoordinates()
    }
}
