import SwiftUI
@preconcurrency import MapKit

extension String {
    var asMapStyle: MapStyle {
        switch self {
        case "satellite": return .imagery
        case "hybrid": return .hybrid
        default: return .standard(elevation: .realistic)
        }
    }

    var asMapStyleExcludingPOI: MapStyle {
        switch self {
        case "satellite": return .imagery
        case "hybrid": return .hybrid(pointsOfInterest: .excludingAll)
        default: return .standard(elevation: .realistic, pointsOfInterest: .excludingAll)
        }
    }
}
