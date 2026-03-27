import CoreLocation

public enum TemplateGenerator {

    /// Generate waypoints for a circular loop around a center point.
    /// Places waypoints every ~200m along the circle circumference.
    public static func loop(
        center: CLLocationCoordinate2D,
        targetDistanceMeters: Double
    ) -> [CLLocationCoordinate2D] {
        let radiusMeters = targetDistanceMeters / (2 * .pi)
        let waypointCount = max(6, Int(targetDistanceMeters / 200))

        var waypoints = [CLLocationCoordinate2D]()
        for i in 0..<waypointCount {
            let angle = (Double(i) / Double(waypointCount)) * 2 * .pi
            let point = coordinateAt(
                center: center,
                distanceMeters: radiusMeters,
                bearingRadians: angle
            )
            waypoints.append(point)
        }
        return waypoints
    }

    /// Generate waypoints for an out-and-back route.
    /// Goes out for half the target distance, then mirrors waypoints back.
    public static func outAndBack(
        center: CLLocationCoordinate2D,
        targetDistanceMeters: Double,
        bearingDegrees: Double
    ) -> [CLLocationCoordinate2D] {
        let halfDistance = targetDistanceMeters / 2
        let bearingRad = bearingDegrees * .pi / 180
        let segmentCount = max(3, Int(halfDistance / 200))

        var outbound = [CLLocationCoordinate2D]()
        outbound.append(center)

        for i in 1...segmentCount {
            let dist = (Double(i) / Double(segmentCount)) * halfDistance
            let point = coordinateAt(center: center, distanceMeters: dist, bearingRadians: bearingRad)
            outbound.append(point)
        }

        // Mirror back (skip the turnaround point to avoid duplicate)
        let inbound = outbound.dropLast().reversed()
        return outbound + inbound
    }

    /// Generate waypoints for a figure-8 route.
    /// Two smaller loops sharing the center point.
    public static func figure8(
        center: CLLocationCoordinate2D,
        targetDistanceMeters: Double
    ) -> [CLLocationCoordinate2D] {
        let loopDistance = targetDistanceMeters / 2
        let radiusMeters = loopDistance / (2 * .pi)
        let pointsPerLoop = max(5, Int(loopDistance / 200))

        // Upper loop center (offset north)
        let upperCenter = coordinateAt(center: center, distanceMeters: radiusMeters, bearingRadians: 0)
        // Lower loop center (offset south)
        let lowerCenter = coordinateAt(center: center, distanceMeters: radiusMeters, bearingRadians: .pi)

        var waypoints = [CLLocationCoordinate2D]()

        // Upper loop (clockwise, starting from center/south of upper loop)
        for i in 0..<pointsPerLoop {
            let angle = .pi + (Double(i) / Double(pointsPerLoop)) * 2 * .pi
            let point = coordinateAt(center: upperCenter, distanceMeters: radiusMeters, bearingRadians: angle)
            waypoints.append(point)
        }

        // Lower loop (clockwise, starting from center/north of lower loop)
        for i in 0..<pointsPerLoop {
            let angle = (Double(i) / Double(pointsPerLoop)) * 2 * .pi
            let point = coordinateAt(center: lowerCenter, distanceMeters: radiusMeters, bearingRadians: angle)
            waypoints.append(point)
        }

        return waypoints
    }

    /// Calculate a coordinate at a given distance and bearing from a center point.
    /// Uses the Haversine formula inverse.
    private static func coordinateAt(
        center: CLLocationCoordinate2D,
        distanceMeters: Double,
        bearingRadians: Double
    ) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0 // meters
        let angularDistance = distanceMeters / earthRadius

        let lat1 = center.latitude * .pi / 180
        let lng1 = center.longitude * .pi / 180

        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(bearingRadians)
        )
        let lng2 = lng1 + atan2(
            sin(bearingRadians) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lng2 * 180 / .pi
        )
    }
}
