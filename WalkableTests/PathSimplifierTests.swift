import Testing
import Foundation
import CoreLocation
@testable import WalkableKit

@Suite("PathSimplifier")
struct PathSimplifierTests {

    @Test("Douglas-Peucker reduces points on a straight line")
    func straightLineSimplification() {
        // Points along a straight line should simplify to just endpoints
        let points = (0...10).map {
            CLLocationCoordinate2D(latitude: Double($0) * 0.001, longitude: 0)
        }
        let simplified = PathSimplifier.simplify(points, tolerance: 0.0001)
        #expect(simplified.count == 2) // just start and end
    }

    @Test("Douglas-Peucker keeps points on a curve")
    func curveKeepsPoints() {
        // L-shaped path: should keep the corner
        let points = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.001, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0.001),
            CLLocationCoordinate2D(latitude: 0.002, longitude: 0.002),
        ]
        let simplified = PathSimplifier.simplify(points, tolerance: 0.00005)
        #expect(simplified.count >= 3) // at least start, corner, end
        #expect(simplified.count <= 5)
    }

    @Test("Sample waypoints at interval")
    func sampleWaypoints() {
        // Create a path roughly 1km long (0.01 degrees ~ 1.1km at equator)
        let points = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.005, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0),
        ]
        // Sample every 200m along a ~1.1km path should give ~5-6 points
        let sampled = PathSimplifier.sampleWaypoints(along: points, intervalMeters: 200)
        #expect(sampled.count >= 3)
        #expect(sampled.count <= 8)
    }

    @Test("Sample waypoints always includes first and last")
    func sampleIncludesEndpoints() {
        let points = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0),
        ]
        let sampled = PathSimplifier.sampleWaypoints(along: points, intervalMeters: 200)
        #expect(sampled.first!.latitude == 0)
        #expect(abs(sampled.last!.latitude - 0.01) < 0.001)
    }

    @Test("Empty input returns empty")
    func emptyInput() {
        let simplified = PathSimplifier.simplify([], tolerance: 0.001)
        #expect(simplified.isEmpty)
        let sampled = PathSimplifier.sampleWaypoints(along: [], intervalMeters: 200)
        #expect(sampled.isEmpty)
    }
}
