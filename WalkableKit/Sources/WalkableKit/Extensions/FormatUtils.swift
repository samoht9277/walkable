import Foundation
import CoreLocation

private var _useMetric: Bool {
    // Default to true (metric) when key has never been set
    if UserDefaults.standard.object(forKey: "useMetric") == nil { return true }
    return UserDefaults.standard.bool(forKey: "useMetric")
}

public extension Double {
    /// Formats pace (sec/km or sec/mi) as "M:SS /km" or "M:SS /mi". Returns "--:--" for invalid values.
    var formattedPace: String {
        guard self > 0 && self < 3600 else { return "--:--" }
        let paceValue = _useMetric ? self : self * 1.60934
        let mins = Int(paceValue) / 60
        let secs = Int(paceValue) % 60
        let unit = _useMetric ? "/km" : "/mi"
        return String(format: "%d:%02d %@", mins, secs, unit)
    }

    /// Formats pace without unit suffix (for compact displays).
    var formattedPaceShort: String {
        guard self > 0 && self < 3600 else { return "--:--" }
        let paceValue = _useMetric ? self : self * 1.60934
        let mins = Int(paceValue) / 60
        let secs = Int(paceValue) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Formats meters as "Xm"/"X.Xkm" or "Xft"/"X.Xmi".
    var formattedDistance: String {
        if _useMetric {
            if self < 1000 { return String(format: "%.0fm", self) }
            return String(format: "%.1fkm", self / 1000)
        } else {
            let miles = self / 1609.34
            if miles < 0.1 {
                let feet = self * 3.28084
                return String(format: "%.0fft", feet)
            }
            return String(format: "%.1fmi", miles)
        }
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
