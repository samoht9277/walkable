import CoreLocation

public enum PathSimplifier {

    /// Douglas-Peucker line simplification algorithm.
    /// Removes points that are within `tolerance` degrees of the line between endpoints.
    public static func simplify(
        _ points: [CLLocationCoordinate2D],
        tolerance: Double
    ) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }

        // Find the point with the maximum distance from the line between first and last
        var maxDistance = 0.0
        var maxIndex = 0

        let first = points[0]
        let last = points[points.count - 1]

        for i in 1..<(points.count - 1) {
            let d = perpendicularDistance(point: points[i], lineStart: first, lineEnd: last)
            if d > maxDistance {
                maxDistance = d
                maxIndex = i
            }
        }

        if maxDistance > tolerance {
            let left = simplify(Array(points[0...maxIndex]), tolerance: tolerance)
            let right = simplify(Array(points[maxIndex...]), tolerance: tolerance)
            // Merge, removing duplicate at junction
            return Array(left.dropLast()) + right
        } else {
            return [first, last]
        }
    }

    /// Sample waypoints at regular distance intervals along a path.
    /// Always includes the first and last point.
    public static func sampleWaypoints(
        along points: [CLLocationCoordinate2D],
        intervalMeters: Double
    ) -> [CLLocationCoordinate2D] {
        guard points.count >= 2 else { return points }

        var sampled = [points[0]]
        var accumulatedDistance = 0.0

        for i in 1..<points.count {
            let segmentDistance = metersDistance(from: points[i - 1], to: points[i])
            accumulatedDistance += segmentDistance

            if accumulatedDistance >= intervalMeters {
                sampled.append(points[i])
                accumulatedDistance = 0
            }
        }

        // Always include the last point
        let last = points[points.count - 1]
        if let lastSampled = sampled.last,
           metersDistance(from: lastSampled, to: last) > 10 {
            sampled.append(last)
        }

        return sampled
    }

    /// Perpendicular distance from a point to a line (in degrees, for simplification).
    private static func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude

        if dx == 0 && dy == 0 {
            // lineStart == lineEnd
            let pdx = point.longitude - lineStart.longitude
            let pdy = point.latitude - lineStart.latitude
            return sqrt(pdx * pdx + pdy * pdy)
        }

        let t = ((point.longitude - lineStart.longitude) * dx + (point.latitude - lineStart.latitude) * dy) / (dx * dx + dy * dy)
        let clampedT = max(0, min(1, t))

        let closestLng = lineStart.longitude + clampedT * dx
        let closestLat = lineStart.latitude + clampedT * dy

        let distLng = point.longitude - closestLng
        let distLat = point.latitude - closestLat

        return sqrt(distLng * distLng + distLat * distLat)
    }

    private static func metersDistance(
        from a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D
    ) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
