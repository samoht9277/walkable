import Testing
import Foundation
@testable import WalkableKit

@Suite("GPXService")
struct GPXServiceTests {

    @Test("Export route produces valid GPX XML")
    func exportRoute() {
        let route = Route(name: "Test Route", distance: 1000)
        let wp1 = Waypoint(index: 0, latitude: 37.7749, longitude: -122.4194)
        let wp2 = Waypoint(index: 1, latitude: 37.7750, longitude: -122.4190)
        route.waypoints = [wp1, wp2]

        let gpx = GPXService.export(route: route)
        #expect(gpx.contains("<gpx"))
        #expect(gpx.contains("Test Route"))
        #expect(gpx.contains("37.7749"))
        #expect(gpx.contains("-122.4194"))
        #expect(gpx.contains("<rtept"))
    }

    @Test("Parse GPX with waypoints")
    func parseWaypoints() {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Walkable" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata><name>Parsed Route</name></metadata>
          <rte>
            <name>Parsed Route</name>
            <rtept lat="37.7749" lon="-122.4194"><name>Start</name></rtept>
            <rtept lat="37.7760" lon="-122.4180"><name>End</name></rtept>
          </rte>
        </gpx>
        """

        let data = GPXService.parse(gpxString: gpx)
        #expect(data != nil)
        #expect(data?.name == "Parsed Route")
        #expect(data?.waypoints.count == 2)
        #expect(data?.waypoints[0].name == "Start")
        #expect(abs(data!.waypoints[0].latitude - 37.7749) < 0.001)
    }

    @Test("Parse GPX with track points and elevation")
    func parseTrackPoints() {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Walkable" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata><name>Track Test</name></metadata>
          <trk><trkseg>
            <trkpt lat="37.7749" lon="-122.4194"><ele>25.0</ele><time>2026-04-06T12:00:00Z</time></trkpt>
            <trkpt lat="37.7750" lon="-122.4190"><ele>26.5</ele><time>2026-04-06T12:00:30Z</time></trkpt>
          </trkseg></trk>
        </gpx>
        """

        let data = GPXService.parse(gpxString: gpx)
        #expect(data?.trackPoints.count == 2)
        #expect(data?.trackPoints[0].elevation == 25.0)
        #expect(data?.trackPoints[1].time != nil)
    }

    @Test("Parse empty GPX returns empty data")
    func parseEmpty() {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
        </gpx>
        """
        let data = GPXService.parse(gpxString: gpx)
        #expect(data != nil)
        #expect(data?.waypoints.isEmpty == true)
        #expect(data?.trackPoints.isEmpty == true)
    }

    @Test("Roundtrip: export then parse preserves waypoints")
    func roundtrip() {
        let route = Route(name: "Roundtrip Test", distance: 500)
        let wp1 = Waypoint(index: 0, latitude: -34.5875, longitude: -58.4371, label: "Home")
        let wp2 = Waypoint(index: 1, latitude: -34.5880, longitude: -58.4365, label: "Park")
        route.waypoints = [wp1, wp2]

        let gpx = GPXService.export(route: route)
        let parsed = GPXService.parse(gpxString: gpx)

        #expect(parsed?.name == "Roundtrip Test")
        #expect(parsed?.waypoints.count == 2)
        #expect(parsed?.waypoints[0].name == "Home")
        #expect(abs(parsed!.waypoints[1].latitude - (-34.5880)) < 0.001)
    }

    @Test("XML special characters are escaped")
    func escapeXML() {
        let route = Route(name: "Tom & Jerry's <Route>")
        let gpx = GPXService.export(route: route)
        #expect(gpx.contains("Tom &amp; Jerry"))
        #expect(gpx.contains("&lt;Route&gt;"))
    }
}
