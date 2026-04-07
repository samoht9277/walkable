import Foundation
import CoreLocation

public enum GPXService {

    // MARK: - Export

    /// Export a Route to GPX XML string
    public static func export(route: Route) -> String {
        let isoFormatter = ISO8601DateFormatter()
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Walkable"
             xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(escapeXML(route.name))</name>
            <time>\(isoFormatter.string(from: route.createdAt))</time>
          </metadata>
          <rte>
            <name>\(escapeXML(route.name))</name>
        """

        for wp in route.sortedWaypoints {
            gpx += """

                <rtept lat="\(wp.latitude)" lon="\(wp.longitude)">
                  <name>\(escapeXML(wp.label ?? "Waypoint \(wp.index + 1)"))</name>
                </rtept>
            """
        }

        gpx += "\n  </rte>"

        if let coords = route.decodedPolylineCoordinates {
            gpx += """

              <trk>
                <name>\(escapeXML(route.name)) Path</name>
                <trkseg>
            """
            for coord in coords {
                gpx += """

                  <trkpt lat="\(coord.latitude)" lon="\(coord.longitude)">
                  </trkpt>
                """
            }
            gpx += """

                </trkseg>
              </trk>
            """
        }

        gpx += "\n</gpx>"
        return gpx
    }

    /// Export a WalkSession (with GPS track) to GPX
    public static func exportSession(session: WalkSession, route: Route?) -> String {
        let isoFormatter = ISO8601DateFormatter()
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Walkable"
             xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(escapeXML(route?.name ?? "Walk"))</name>
            <time>\(isoFormatter.string(from: session.startedAt))</time>
          </metadata>
        """

        if let route {
            gpx += "\n  <rte>\n    <name>\(escapeXML(route.name))</name>"
            for wp in route.sortedWaypoints {
                gpx += """

                    <rtept lat="\(wp.latitude)" lon="\(wp.longitude)">
                      <name>\(escapeXML(wp.label ?? "Waypoint \(wp.index + 1)"))</name>
                    </rtept>
                """
            }
            gpx += "\n  </rte>"
        }

        if let gpsData = session.gpsTrackData,
           let coords = gpsData.decodedCoordinates() {
            gpx += """

              <trk>
                <name>GPS Track</name>
                <trkseg>
            """
            let duration = session.totalDuration
            for (i, coord) in coords.enumerated() {
                let t = duration > 0 ? (Double(i) / Double(max(coords.count - 1, 1))) * duration : 0
                let time = session.startedAt.addingTimeInterval(t)
                gpx += """

                  <trkpt lat="\(coord.latitude)" lon="\(coord.longitude)">
                    <time>\(isoFormatter.string(from: time))</time>
                  </trkpt>
                """
            }
            gpx += """

                </trkseg>
              </trk>
            """
        }

        gpx += "\n</gpx>"
        return gpx
    }

    // MARK: - Import

    /// Parse a GPX file and return waypoints and track points
    public static func parse(gpxString: String) -> GPXData? {
        let parser = GPXParser(xmlString: gpxString)
        return parser.parse()
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - GPX Data Types

public struct GPXData {
    public let name: String?
    public let waypoints: [GPXWaypoint]
    public let trackPoints: [GPXTrackPoint]
}

public struct GPXWaypoint {
    public let latitude: Double
    public let longitude: Double
    public let name: String?
}

public struct GPXTrackPoint {
    public let latitude: Double
    public let longitude: Double
    public let elevation: Double?
    public let time: Date?
}

// MARK: - GPX Parser

class GPXParser: NSObject, XMLParserDelegate {
    private let xmlString: String
    private var name: String?
    private var waypoints: [GPXWaypoint] = []
    private var trackPoints: [GPXTrackPoint] = []

    private var currentElement = ""
    private var currentText = ""
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentElevation: Double?
    private var currentTime: Date?
    private var currentName: String?
    private var inRoute = false
    private var inTrack = false
    private var inMetadata = false

    private let isoFormatter = ISO8601DateFormatter()

    init(xmlString: String) {
        self.xmlString = xmlString
    }

    func parse() -> GPXData? {
        guard let data = xmlString.data(using: .utf8) else { return nil }
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }
        return GPXData(name: name, waypoints: waypoints, trackPoints: trackPoints)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "metadata": inMetadata = true
        case "rte": inRoute = true
        case "trk", "trkseg": inTrack = true
        case "rtept", "wpt":
            currentLat = Double(attributes["lat"] ?? "")
            currentLon = Double(attributes["lon"] ?? "")
            currentName = nil
        case "trkpt":
            currentLat = Double(attributes["lat"] ?? "")
            currentLon = Double(attributes["lon"] ?? "")
            currentElevation = nil
            currentTime = nil
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "metadata": inMetadata = false
        case "name":
            if inMetadata { name = text } else if inRoute || !inTrack { currentName = text }
        case "ele": currentElevation = Double(text)
        case "time":
            if !inMetadata { currentTime = isoFormatter.date(from: text) }
        case "rtept", "wpt":
            if let lat = currentLat, let lon = currentLon {
                waypoints.append(GPXWaypoint(latitude: lat, longitude: lon, name: currentName))
            }
        case "trkpt":
            if let lat = currentLat, let lon = currentLon {
                trackPoints.append(GPXTrackPoint(latitude: lat, longitude: lon, elevation: currentElevation, time: currentTime))
            }
        case "rte": inRoute = false
        case "trk", "trkseg": inTrack = false
        default: break
        }
    }
}
