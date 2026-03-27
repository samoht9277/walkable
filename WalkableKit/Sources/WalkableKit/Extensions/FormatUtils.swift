import Foundation
import CoreLocation

public extension Double {
    /// Formats pace (sec/km) as "M:SS /km". Returns "--:--" for invalid values.
    var formattedPace: String {
        guard self > 0 && self < 3600 else { return "--:--" }
        let mins = Int(self) / 60
        let secs = Int(self) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }

    /// Formats pace without /km suffix (for compact displays).
    var formattedPaceShort: String {
        guard self > 0 && self < 3600 else { return "--:--" }
        let mins = Int(self) / 60
        let secs = Int(self) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Formats meters as "Xm" or "X.Xkm".
    var formattedDistance: String {
        if self < 1000 { return String(format: "%.0fm", self) }
        return String(format: "%.1fkm", self / 1000)
    }
}

public extension TimeInterval {
    /// Formats as "M:SS" or "H:MM:SS" for longer durations.
    var formattedDuration: String {
        let totalSecs = Int(self)
        let mins = totalSecs / 60
        let secs = totalSecs % 60
        if mins >= 60 {
            return String(format: "%d:%02d:%02d", mins / 60, mins % 60, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    /// Formats as human-readable "~N min" or "~Xh Ym".
    var formattedEstimate: String {
        let minutes = Int(self) / 60
        if minutes < 60 { return "~\(minutes) min" }
        return "~\(minutes / 60)h \(minutes % 60)m"
    }
}

public extension Data {
    /// Decode stored polyline data to coordinate array for MapPolyline(coordinates:).
    func decodedCoordinates() -> [CLLocationCoordinate2D]? {
        guard let coords = try? JSONDecoder().decode([CodableCoordinate].self, from: self) else { return nil }
        return coords.map { $0.clCoordinate }
    }
}
