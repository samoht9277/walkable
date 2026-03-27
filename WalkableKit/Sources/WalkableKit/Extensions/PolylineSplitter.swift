import CoreLocation

public enum PolylineSplitter {
    /// Split a polyline at the closest point to a given location.
    /// Returns (walked, remaining) coordinate arrays.
    public static func split(
        polyline: [CLLocationCoordinate2D],
        at currentLocation: CLLocationCoordinate2D
    ) -> (walked: [CLLocationCoordinate2D], remaining: [CLLocationCoordinate2D]) {
        guard polyline.count >= 2 else { return (polyline, []) }

        var closestIndex = 0
        var closestDistance = Double.greatestFiniteMagnitude
        var closestProjection: CLLocationCoordinate2D?

        // Find the closest segment and project the current location onto it
        for i in 0..<(polyline.count - 1) {
            let a = polyline[i]
            let b = polyline[i + 1]
            let (projection, distance) = projectPointOntoSegment(point: currentLocation, segStart: a, segEnd: b)

            if distance < closestDistance {
                closestDistance = distance
                closestIndex = i
                closestProjection = projection
            }
        }

        guard let projection = closestProjection else { return (polyline, []) }

        // Split: walked = polyline[0...closestIndex] + projection
        //        remaining = projection + polyline[closestIndex+1...]
        var walked = Array(polyline[0...closestIndex])
        walked.append(projection)

        var remaining = [projection]
        if closestIndex + 1 < polyline.count {
            remaining.append(contentsOf: polyline[(closestIndex + 1)...])
        }

        return (walked, remaining)
    }

    /// Snap a point to the closest position on a polyline (guaranteed to be on the polyline path).
    public static func snapToPolyline(
        point: CLLocationCoordinate2D,
        polyline: [CLLocationCoordinate2D]
    ) -> CLLocationCoordinate2D {
        guard polyline.count >= 2 else { return point }

        var bestProjection = point
        var bestDistance = Double.greatestFiniteMagnitude

        for i in 0..<(polyline.count - 1) {
            let (projection, distance) = projectPointOntoSegment(point: point, segStart: polyline[i], segEnd: polyline[i + 1])
            if distance < bestDistance {
                bestDistance = distance
                bestProjection = projection
            }
        }
        return bestProjection
    }

    /// Project a point onto a line segment, return the projected point and distance.
    private static func projectPointOntoSegment(
        point: CLLocationCoordinate2D,
        segStart: CLLocationCoordinate2D,
        segEnd: CLLocationCoordinate2D
    ) -> (projection: CLLocationCoordinate2D, distance: Double) {
        let dx = segEnd.longitude - segStart.longitude
        let dy = segEnd.latitude - segStart.latitude
        let lengthSq = dx * dx + dy * dy

        if lengthSq == 0 {
            // Segment is a point
            let dist = CLLocation(latitude: point.latitude, longitude: point.longitude)
                .distance(from: CLLocation(latitude: segStart.latitude, longitude: segStart.longitude))
            return (segStart, dist)
        }

        // Parameter t of the projection onto the line (clamped to [0,1] for segment)
        let t = max(0, min(1, ((point.longitude - segStart.longitude) * dx + (point.latitude - segStart.latitude) * dy) / lengthSq))

        let projection = CLLocationCoordinate2D(
            latitude: segStart.latitude + t * dy,
            longitude: segStart.longitude + t * dx
        )

        let dist = CLLocation(latitude: point.latitude, longitude: point.longitude)
            .distance(from: CLLocation(latitude: projection.latitude, longitude: projection.longitude))

        return (projection, dist)
    }
}
