import Foundation

public struct WalkAnalysisData: Codable, Sendable {
    public var altitudeSamples: [TimedSample]
    public var paceSamples: [TimedSample]
    public var heartRateSamples: [TimedSample]

    public init(altitude: [TimedSample] = [], pace: [TimedSample] = [], heartRate: [TimedSample] = []) {
        self.altitudeSamples = altitude
        self.paceSamples = pace
        self.heartRateSamples = heartRate
    }
}

public struct TimedSample: Codable, Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}
