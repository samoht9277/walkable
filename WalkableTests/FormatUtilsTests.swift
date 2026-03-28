import Testing
import Foundation
import CoreLocation
@testable import WalkableKit

@Suite("FormatUtils")
struct FormatUtilsTests {

    // MARK: - formattedPace

    @Test("formattedPace with valid pace 360 = 6:00 /km")
    func formattedPaceValid() {
        let pace: Double = 360
        #expect(pace.formattedPace == "6:00 /km")
    }

    @Test("formattedPace with 0 returns --:--")
    func formattedPaceZero() {
        let pace: Double = 0
        #expect(pace.formattedPace == "--:--")
    }

    @Test("formattedPace with > 3600 returns --:--")
    func formattedPaceOverHour() {
        let pace: Double = 3601
        #expect(pace.formattedPace == "--:--")
    }

    @Test("formattedPace with exactly 3600 returns --:--")
    func formattedPaceExactlyHour() {
        // guard checks self > 0 && self < 3600, so 3600 itself should be invalid
        let pace: Double = 3600
        #expect(pace.formattedPace == "--:--")
    }

    @Test("formattedPace with negative value returns --:--")
    func formattedPaceNegative() {
        let pace: Double = -100
        #expect(pace.formattedPace == "--:--")
    }

    // MARK: - formattedPaceShort

    @Test("formattedPaceShort without /km suffix")
    func formattedPaceShort() {
        let pace: Double = 360
        #expect(pace.formattedPaceShort == "6:00")
    }

    @Test("formattedPaceShort with 0 returns --:--")
    func formattedPaceShortZero() {
        let pace: Double = 0
        #expect(pace.formattedPaceShort == "--:--")
    }

    // MARK: - formattedDuration

    @Test("formattedDuration with seconds only, 90 = 1:30")
    func formattedDurationSecondsOnly() {
        let duration: TimeInterval = 90
        #expect(duration.formattedDuration == "1:30")
    }

    @Test("formattedDuration with hours, 3661 = 1:01:01")
    func formattedDurationWithHours() {
        let duration: TimeInterval = 3661
        #expect(duration.formattedDuration == "1:01:01")
    }

    @Test("formattedDuration zero seconds")
    func formattedDurationZero() {
        let duration: TimeInterval = 0
        #expect(duration.formattedDuration == "0:00")
    }

    // MARK: - formattedEstimate

    @Test("formattedEstimate with minutes, 1800 = ~30 min")
    func formattedEstimateMinutes() {
        let duration: TimeInterval = 1800
        #expect(duration.formattedEstimate == "~30 min")
    }

    @Test("formattedEstimate with hours, 5400 = ~1h 30m")
    func formattedEstimateHours() {
        let duration: TimeInterval = 5400
        #expect(duration.formattedEstimate == "~1h 30m")
    }

    @Test("formattedEstimate with exactly 1 hour = ~1h 0m")
    func formattedEstimateExactHour() {
        let duration: TimeInterval = 3600
        #expect(duration.formattedEstimate == "~1h 0m")
    }

    // MARK: - formattedDistance

    @Test("formattedDistance meters, 500 = 500m")
    func formattedDistanceMeters() {
        let dist: Double = 500
        #expect(dist.formattedDistance == "500m")
    }

    @Test("formattedDistance kilometers, 2500 = 2.5km")
    func formattedDistanceKilometers() {
        let dist: Double = 2500
        #expect(dist.formattedDistance == "2.5km")
    }

    @Test("formattedDistance at boundary, 999 = 999m")
    func formattedDistanceBoundaryBelow() {
        let dist: Double = 999
        #expect(dist.formattedDistance == "999m")
    }

    @Test("formattedDistance at boundary, 1000 = 1.0km")
    func formattedDistanceBoundaryAt() {
        let dist: Double = 1000
        #expect(dist.formattedDistance == "1.0km")
    }

    // MARK: - decodedCoordinates

    @Test("decodedCoordinates roundtrip encode/decode")
    func decodedCoordinatesRoundtrip() {
        let original = [
            CodableCoordinate(latitude: 40.7128, longitude: -74.0060),
            CodableCoordinate(latitude: 40.7138, longitude: -74.0070)
        ]
        let data = try! JSONEncoder().encode(original)
        let decoded = data.decodedCoordinates()
        #expect(decoded != nil)
        #expect(decoded!.count == 2)
        #expect(abs(decoded![0].latitude - 40.7128) < 0.0001)
        #expect(abs(decoded![0].longitude - (-74.0060)) < 0.0001)
        #expect(abs(decoded![1].latitude - 40.7138) < 0.0001)
    }

    @Test("decodedCoordinates with invalid data returns nil")
    func decodedCoordinatesInvalidData() {
        let garbage = "not json at all".data(using: .utf8)!
        let decoded = garbage.decodedCoordinates()
        #expect(decoded == nil)
    }

    @Test("decodedCoordinates with empty array")
    func decodedCoordinatesEmptyArray() {
        let data = try! JSONEncoder().encode([CodableCoordinate]())
        let decoded = data.decodedCoordinates()
        #expect(decoded != nil)
        #expect(decoded!.isEmpty)
    }
}
