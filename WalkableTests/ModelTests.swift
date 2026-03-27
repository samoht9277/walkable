import Testing
import Foundation
import SwiftData
@testable import WalkableKit

@Suite("Data Models")
struct ModelTests {

    @Test("Route creation with defaults")
    func routeDefaults() {
        let route = Route(name: "Test Loop")
        #expect(route.name == "Test Loop")
        #expect(route.tags.isEmpty)
        #expect(route.isFavorite == false)
        #expect(route.distance == 0)
        #expect(route.estimatedDuration == 0)
        #expect(route.waypoints.isEmpty)
        #expect(route.sessions.isEmpty)
    }

    @Test("Waypoint stores coordinates")
    func waypointCoordinates() {
        let wp = Waypoint(index: 0, latitude: 40.7128, longitude: -74.0060)
        #expect(wp.index == 0)
        #expect(wp.latitude == 40.7128)
        #expect(wp.longitude == -74.0060)
        #expect(wp.label == nil)
    }

    @Test("Waypoint coordinate property")
    func waypointCoordinateProperty() {
        let wp = Waypoint(index: 0, latitude: 40.7128, longitude: -74.0060)
        let coord = wp.coordinate
        #expect(abs(coord.latitude - 40.7128) < 0.0001)
        #expect(abs(coord.longitude - (-74.0060)) < 0.0001)
    }

    @Test("WalkSession pace formatting")
    func sessionPace() {
        let route = Route(name: "Test")
        let session = WalkSession(route: route)
        session.totalDistance = 2000
        session.totalDuration = 1200
        session.avgPace = 600
        #expect(session.avgPace == 600)
    }

    @Test("LegSplit stores segment data")
    func legSplitData() {
        let route = Route(name: "Test")
        let session = WalkSession(route: route)
        let split = LegSplit(
            session: session,
            fromWaypointIndex: 0,
            toWaypointIndex: 1,
            distance: 500,
            duration: 300,
            pace: 600
        )
        #expect(split.fromWaypointIndex == 0)
        #expect(split.toWaypointIndex == 1)
        #expect(split.distance == 500)
    }

    @Test("Route sorted waypoints")
    func routeSortedWaypoints() {
        let route = Route(name: "Test")
        let wp2 = Waypoint(index: 2, latitude: 0, longitude: 0)
        let wp0 = Waypoint(index: 0, latitude: 0, longitude: 0)
        let wp1 = Waypoint(index: 1, latitude: 0, longitude: 0)
        route.waypoints = [wp2, wp0, wp1]
        let sorted = route.sortedWaypoints
        #expect(sorted[0].index == 0)
        #expect(sorted[1].index == 1)
        #expect(sorted[2].index == 2)
    }

    @Test("CodableCoordinate encoding roundtrip")
    func polylineEncoding() {
        let coords = [
            CodableCoordinate(latitude: 40.7128, longitude: -74.0060),
            CodableCoordinate(latitude: 40.7138, longitude: -74.0070),
            CodableCoordinate(latitude: 40.7148, longitude: -74.0080)
        ]
        let data = try! JSONEncoder().encode(coords)
        let decoded = try! JSONDecoder().decode([CodableCoordinate].self, from: data)
        #expect(decoded.count == 3)
        #expect(abs(decoded[0].latitude - 40.7128) < 0.0001)
    }
}
