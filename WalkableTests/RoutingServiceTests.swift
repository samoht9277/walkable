import Testing
import Foundation
import CoreLocation
import MapKit
@testable import WalkableKit

@Suite("RoutingService")
struct RoutingServiceTests {

    @Test("Cache key generation is deterministic")
    func cacheKeyDeterministic() {
        let a = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let b = CLLocationCoordinate2D(latitude: 40.7138, longitude: -74.0070)
        let key1 = RoutingService.cacheKey(from: a, to: b)
        let key2 = RoutingService.cacheKey(from: a, to: b)
        #expect(key1 == key2)
    }

    @Test("Cache key differs for different coordinates")
    func cacheKeyDiffers() {
        let a = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let b = CLLocationCoordinate2D(latitude: 40.7138, longitude: -74.0070)
        let c = CLLocationCoordinate2D(latitude: 40.7148, longitude: -74.0080)
        let key1 = RoutingService.cacheKey(from: a, to: b)
        let key2 = RoutingService.cacheKey(from: a, to: c)
        #expect(key1 != key2)
    }

    @Test("Cache key is order-sensitive")
    func cacheKeyOrderSensitive() {
        let a = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let b = CLLocationCoordinate2D(latitude: 40.7138, longitude: -74.0070)
        let key1 = RoutingService.cacheKey(from: a, to: b)
        let key2 = RoutingService.cacheKey(from: b, to: a)
        #expect(key1 != key2)
    }

    @Test("Segment pairs from waypoints creates a loop")
    func segmentPairsLoop() {
        let coords = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
            CLLocationCoordinate2D(latitude: 2, longitude: 2)
        ]
        let pairs = RoutingService.segmentPairs(from: coords)
        #expect(pairs.count == 3) // 0->1, 1->2, 2->0
        // Last pair connects back to first
        #expect(pairs[2].to.latitude == coords[0].latitude)
    }

    @Test("Segment pairs requires at least 2 waypoints")
    func segmentPairsMinimum() {
        let one = [CLLocationCoordinate2D(latitude: 0, longitude: 0)]
        let pairs = RoutingService.segmentPairs(from: one)
        #expect(pairs.isEmpty)
    }
}
