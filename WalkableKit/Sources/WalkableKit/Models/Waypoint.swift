import Foundation
import SwiftData
import CoreLocation

@Model
public final class Waypoint {
    public var id: UUID
    public var index: Int
    public var latitude: Double
    public var longitude: Double
    public var label: String?
    public var route: Route?

    public init(index: Int, latitude: Double, longitude: Double, label: String? = nil) {
        self.id = UUID()
        self.index = index
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
