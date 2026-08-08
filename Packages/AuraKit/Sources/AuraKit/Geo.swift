import Foundation

/// A WGS-84 coordinate, deliberately free of any CoreLocation dependency so the
/// clustering core stays portable and testable off-device.
public struct Coordinate: Hashable, Sendable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum Geo {
    static let earthRadiusKm = 6371.0088

    /// Great-circle distance in kilometres.
    public static func distanceKm(_ a: Coordinate, _ b: Coordinate) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusKm * asin(min(1, sqrt(h)))
    }

    /// Mean of a set of coordinates, computed in 3D to stay correct across the
    /// antimeridian and near the poles, where averaging degrees goes wrong.
    public static func centroid(of coordinates: [Coordinate]) -> Coordinate? {
        guard !coordinates.isEmpty else { return nil }

        var x = 0.0, y = 0.0, z = 0.0
        for c in coordinates {
            let lat = c.latitude * .pi / 180
            let lon = c.longitude * .pi / 180
            x += cos(lat) * cos(lon)
            y += cos(lat) * sin(lon)
            z += sin(lat)
        }
        let n = Double(coordinates.count)
        x /= n; y /= n; z /= n

        let hyp = sqrt(x * x + y * y)
        guard hyp > 1e-12 || abs(z) > 1e-12 else { return coordinates[0] }

        return Coordinate(
            latitude: atan2(z, hyp) * 180 / .pi,
            longitude: atan2(y, x) * 180 / .pi
        )
    }

    /// Total path length walked in order. Used for the "kilometres travelled" stat.
    public static func pathLengthKm(_ coordinates: [Coordinate]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        return zip(coordinates, coordinates.dropFirst())
            .reduce(0) { $0 + distanceKm($1.0, $1.1) }
    }
}
