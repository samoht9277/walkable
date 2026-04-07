import Testing
import Foundation
import CoreLocation
@testable import WalkableKit

@Suite("PolylineSplitter")
struct PolylineSplitterTests {

    // MARK: - snapToPolyline

    @Test("snapToPolyline returns a point on the polyline")
    func snapReturnsPointOnPolyline() {
        let polyline = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.01)
        ]
        let offPoint = CLLocationCoordinate2D(latitude: 0.005, longitude: 0.005)
        let snapped = PolylineSplitter.snapToPolyline(point: offPoint, polyline: polyline)

        // The snapped point should lie on the segment, so latitude should be ~0
        // (the segment runs along latitude 0 from lon 0 to lon 0.01)
        #expect(abs(snapped.latitude) < 0.0001)
        #expect(snapped.longitude >= -0.0001 && snapped.longitude <= 0.0101)
    }

    @Test("snapToPolyline with a point far from the polyline still returns closest point")
    func snapFarPointReturnsClosest() {
        let polyline = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.01)
        ]
        // A point far away to the north
        let farPoint = CLLocationCoordinate2D(latitude: 10.0, longitude: 0.005)
        let snapped = PolylineSplitter.snapToPolyline(point: farPoint, polyline: polyline)

        // Should still snap to somewhere on the segment (latitude ~0)
        #expect(abs(snapped.latitude) < 0.0001)
        #expect(snapped.longitude >= -0.0001 && snapped.longitude <= 0.0101)
    }

    @Test("snapToPolyline with single point returns the original point")
    func snapSinglePointPolyline() {
        let polyline = [CLLocationCoordinate2D(latitude: 5, longitude: 5)]
        let point = CLLocationCoordinate2D(latitude: 10, longitude: 10)
        let snapped = PolylineSplitter.snapToPolyline(point: point, polyline: polyline)
        // With fewer than 2 points, it returns the input point unchanged
        #expect(snapped.latitude == point.latitude)
        #expect(snapped.longitude == point.longitude)
    }

    // MARK: - split

    @Test("split divides correctly, walked + remaining cover the full polyline")
    func splitCoversFullPolyline() {
        let polyline = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.005),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.01)
        ]
        let midPoint = CLLocationCoordinate2D(latitude: 0, longitude: 0.005)
        let (walked, remaining) = PolylineSplitter.split(polyline: polyline, at: midPoint)

        // Walked should end at or near the midpoint, remaining should start there
        #expect(walked.count >= 2)
        #expect(remaining.count >= 2)

        // The last point of walked and first point of remaining should be the same (the projection)
        #expect(abs(walked.last!.longitude - remaining.first!.longitude) < 0.0001)

        // Walked starts at the polyline start
        #expect(abs(walked.first!.longitude) < 0.0001)
        // Remaining ends at the polyline end
        #expect(abs(remaining.last!.longitude - 0.01) < 0.0001)
    }

    @Test("split at the start returns empty walked, full remaining")
    func splitAtStart() {
        let polyline = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.005),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.01)
        ]
        let startPoint = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let (walked, remaining) = PolylineSplitter.split(polyline: polyline, at: startPoint)

        // Walked should be just the first point (start + projection at start)
        // The projection is on the polyline[0], so walked = [polyline[0], projection]
        // where projection == polyline[0], effectively 1 logical point
        #expect(walked.count <= 2)
        // Remaining should contain essentially the full polyline
        #expect(remaining.count >= 3)
        #expect(abs(remaining.last!.longitude - 0.01) < 0.0001)
    }

    @Test("split at the end returns full walked, minimal remaining")
    func splitAtEnd() {
        let polyline = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.005),
            CLLocationCoordinate2D(latitude: 0, longitude: 0.01)
        ]
        let endPoint = CLLocationCoordinate2D(latitude: 0, longitude: 0.01)
        let (walked, remaining) = PolylineSplitter.split(polyline: polyline, at: endPoint)

        // Walked should cover the full polyline
        #expect(walked.count >= 3)
        #expect(abs(walked.first!.longitude) < 0.0001)
        // Remaining starts at the projection (at the end) and includes any points after
        // the closest segment index. Both the projection and the final point are at lon 0.01.
        #expect(remaining.count <= 2)
        #expect(abs(remaining.first!.longitude - 0.01) < 0.0001)
        #expect(abs(remaining.last!.longitude - 0.01) < 0.0001)
    }

    @Test("split with searchFromIndex skips earlier segments on shared streets")
    func splitWithSearchFromIndex() {
        // Out-and-back route: A -> B -> C -> B -> A (shares segment A-B)
        let polyline = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),       // A
            CLLocationCoordinate2D(latitude: 0, longitude: 0.01),    // B (outbound)
            CLLocationCoordinate2D(latitude: 0, longitude: 0.02),    // C (turnaround)
            CLLocationCoordinate2D(latitude: 0, longitude: 0.01),    // B (return)
            CLLocationCoordinate2D(latitude: 0, longitude: 0)        // A (finish)
        ]

        // User is near B on the return leg (segment index 3: B->A)
        let nearB = CLLocationCoordinate2D(latitude: 0, longitude: 0.01)

        // Without searchFromIndex, it snaps to segment 0 (outbound A->B)
        let (walkedDefault, _) = PolylineSplitter.split(polyline: polyline, at: nearB)
        #expect(walkedDefault.count <= 3) // snaps to early segment

        // With searchFromIndex=2, it skips outbound and finds segment 2 (C->B) or 3 (B->A)
        let (walkedForward, remaining) = PolylineSplitter.split(polyline: polyline, at: nearB, searchFromIndex: 2)
        #expect(walkedForward.count >= 4) // includes outbound + turnaround
        #expect(remaining.count >= 2)     // still has return leg
    }

    @Test("split with 1-point polyline returns it as walked")
    func splitSinglePoint() {
        let polyline = [CLLocationCoordinate2D(latitude: 1, longitude: 1)]
        let (walked, remaining) = PolylineSplitter.split(polyline: polyline, at: CLLocationCoordinate2D(latitude: 0, longitude: 0))

        // guard polyline.count >= 2 returns (polyline, [])
        #expect(walked.count == 1)
        #expect(remaining.isEmpty)
        #expect(walked.first!.latitude == 1)
    }
}
