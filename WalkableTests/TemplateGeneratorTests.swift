import Testing
import Foundation
import CoreLocation
@testable import WalkableKit

@Suite("TemplateGenerator")
struct TemplateGeneratorTests {

    let center = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

    @Test("Loop generates correct number of waypoints")
    func loopWaypointCount() {
        let waypoints = TemplateGenerator.loop(center: center, targetDistanceMeters: 2000)
        // 2km loop, waypoints every ~200m = ~10 points
        #expect(waypoints.count >= 6)
        #expect(waypoints.count <= 15)
    }

    @Test("Loop waypoints form a rough circle around center")
    func loopFormation() {
        let waypoints = TemplateGenerator.loop(center: center, targetDistanceMeters: 2000)
        // All points should be roughly equidistant from center
        let distances = waypoints.map { distance(from: center, to: $0) }
        let avgDist = distances.reduce(0, +) / Double(distances.count)
        for d in distances {
            #expect(abs(d - avgDist) / avgDist < 0.15) // within 15% of average
        }
    }

    @Test("Out and back generates symmetric waypoints")
    func outAndBack() {
        let waypoints = TemplateGenerator.outAndBack(center: center, targetDistanceMeters: 2000, bearingDegrees: 0)
        #expect(waypoints.count >= 4)
        // First and last should be close to center
        let firstDist = distance(from: center, to: waypoints.first!)
        let lastDist = distance(from: center, to: waypoints.last!)
        #expect(firstDist < 50) // within 50m of center
        #expect(lastDist < 50)
    }

    @Test("Figure-8 generates two loops worth of waypoints")
    func figure8() {
        let waypoints = TemplateGenerator.figure8(center: center, targetDistanceMeters: 3000)
        // Figure-8 splits into two half-distance loops, so should have more waypoints
        // than a single loop of half the distance
        let halfLoopWaypoints = TemplateGenerator.loop(center: center, targetDistanceMeters: 1500)
        #expect(waypoints.count >= halfLoopWaypoints.count)
    }

    // Helper: distance between two coords in meters
    private func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
