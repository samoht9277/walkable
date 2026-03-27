import MapKit

public extension MKPolyline {
    func encodedData() throws -> Data {
        var coords = [CodableCoordinate]()
        let points = self.points()
        for i in 0..<self.pointCount {
            let mapPoint = points[i]
            let coord = mapPoint.coordinate
            coords.append(CodableCoordinate(coord))
        }
        return try JSONEncoder().encode(coords)
    }

    static func from(encodedData data: Data) throws -> MKPolyline {
        let coords = try JSONDecoder().decode([CodableCoordinate].self, from: data)
        var clCoords = coords.map { $0.clCoordinate }
        return MKPolyline(coordinates: &clCoords, count: clCoords.count)
    }
}
