@preconcurrency import MapKit
import CoreLocation

public struct SegmentPair: Sendable {
    public let from: CLLocationCoordinate2D
    public let to: CLLocationCoordinate2D
}

public struct CalculatedRoute: Sendable {
    public let coordinates: [CLLocationCoordinate2D]
    public let distance: CLLocationDistance
    public let expectedTravelTime: TimeInterval
    /// Waypoint positions snapped to the nearest walkable road.
    public let snappedWaypoints: [CLLocationCoordinate2D]

    public var polyline: MKPolyline {
        var coords = coordinates
        return MKPolyline(coordinates: &coords, count: coords.count)
    }
}

@MainActor
public final class RoutingService {
    public static let shared = RoutingService()

    private var cache: [String: MKRoute] = [:]

    private init() {}

    /// Generate a deterministic cache key from two coordinates.
    /// Rounds to 5 decimal places (~1m precision) for stable hashing.
    nonisolated public static func cacheKey(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> String {
        let precision = 100000.0
        let fLat = (from.latitude * precision).rounded() / precision
        let fLng = (from.longitude * precision).rounded() / precision
        let tLat = (to.latitude * precision).rounded() / precision
        let tLng = (to.longitude * precision).rounded() / precision
        return "\(fLat),\(fLng)->\(tLat),\(tLng)"
    }

    /// Generate segment pairs for a loop: each consecutive pair + last back to first.
    nonisolated public static func segmentPairs(from coordinates: [CLLocationCoordinate2D]) -> [SegmentPair] {
        guard coordinates.count >= 2 else { return [] }
        var pairs = [SegmentPair]()
        for i in 0..<coordinates.count {
            let next = (i + 1) % coordinates.count
            pairs.append(SegmentPair(from: coordinates[i], to: coordinates[next]))
        }
        return pairs
    }

    /// Calculate walking route for a single segment. Uses cache if available.
    public func calculateSegment(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> MKRoute {
        let key = Self.cacheKey(from: from, to: to)

        if let cached = cache[key] {
            return cached
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RoutingError.noRouteFound
        }

        cache[key] = route
        return route
    }

    /// Calculate a complete walking loop through all waypoints.
    /// Calls MKDirections sequentially with a delay to respect rate limits.
    public func calculateLoop(through coordinates: [CLLocationCoordinate2D]) async throws -> CalculatedRoute {
        let pairs = Self.segmentPairs(from: coordinates)
        guard !pairs.isEmpty else {
            throw RoutingError.insufficientWaypoints
        }

        var segmentRoutes = [MKRoute]()
        for (index, pair) in pairs.enumerated() {
            try Task.checkCancellation()
            let wasCacheHit = cache[Self.cacheKey(from: pair.from, to: pair.to)] != nil
            let route = try await calculateSegment(from: pair.from, to: pair.to)
            segmentRoutes.append(route)

            // Rate limit delay between API requests (skip for cache hits and after last)
            if index < pairs.count - 1 && !wasCacheHit {
                try await Task.sleep(for: .seconds(1))
            }
        }

        let allCoords = extractCoordinates(from: segmentRoutes.map { $0.polyline })
        let totalDistance = segmentRoutes.reduce(0) { $0 + $1.distance }
        let totalTime = segmentRoutes.reduce(0) { $0 + $1.expectedTravelTime }

        // Snap each original waypoint to the nearest point on the calculated route polyline
        let snapped = coordinates.map { waypoint in
            PolylineSplitter.snapToPolyline(point: waypoint, polyline: allCoords)
        }

        return CalculatedRoute(
            coordinates: allCoords,
            distance: totalDistance,
            expectedTravelTime: totalTime,
            snappedWaypoints: snapped
        )
    }

    /// Invalidate cached segment for a specific pair (used when user moves a pin).
    public func invalidateCache(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        let key = Self.cacheKey(from: from, to: to)
        cache.removeValue(forKey: key)
    }

    /// Clear entire cache.
    public func clearCache() {
        cache.removeAll()
    }

    /// Extract coordinates from multiple polylines into a single array.
    private func extractCoordinates(from polylines: [MKPolyline]) -> [CLLocationCoordinate2D] {
        var allCoords = [CLLocationCoordinate2D]()
        for polyline in polylines {
            let points = polyline.points()
            for i in 0..<polyline.pointCount {
                allCoords.append(points[i].coordinate)
            }
        }
        return allCoords
    }
}

public enum RoutingError: Error, LocalizedError {
    case noRouteFound
    case insufficientWaypoints

    public var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "No walking route found between those points."
        case .insufficientWaypoints:
            return "At least 2 waypoints are needed to calculate a route."
        }
    }
}
