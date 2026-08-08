import XCTest
@testable import AuraKit

final class GeoTests: XCTestCase {

    func testDistanceBetweenKnownCities() {
        let km = Geo.distanceKm(Fixtures.bristol, Fixtures.london)
        XCTAssertEqual(km, 171, accuracy: 5)
    }

    func testDistanceIsZeroForIdenticalPoints() {
        XCTAssertEqual(Geo.distanceKm(Fixtures.bristol, Fixtures.bristol), 0, accuracy: 1e-9)
    }

    func testDistanceIsSymmetric() {
        XCTAssertEqual(
            Geo.distanceKm(Fixtures.lisbon, Fixtures.tokyo),
            Geo.distanceKm(Fixtures.tokyo, Fixtures.lisbon),
            accuracy: 1e-6
        )
    }

    func testCentroidOfSinglePointIsThatPoint() {
        let centroid = Geo.centroid(of: [Fixtures.bristol])
        XCTAssertEqual(centroid?.latitude ?? 0, Fixtures.bristol.latitude, accuracy: 1e-9)
        XCTAssertEqual(centroid?.longitude ?? 0, Fixtures.bristol.longitude, accuracy: 1e-9)
    }

    func testCentroidIsEmptyForEmptyInput() {
        XCTAssertNil(Geo.centroid(of: []))
    }

    /// Averaging raw degrees across the antimeridian lands you in the middle of the
    /// Atlantic instead of the Pacific. The 3D mean must not.
    func testCentroidCrossesAntimeridianCorrectly() {
        let west = Coordinate(latitude: 0, longitude: 179)
        let east = Coordinate(latitude: 0, longitude: -179)

        let centroid = Geo.centroid(of: [west, east])
        XCTAssertEqual(abs(centroid?.longitude ?? 0), 180, accuracy: 0.01)
        XCTAssertEqual(centroid?.latitude ?? 99, 0, accuracy: 0.01)
    }

    func testPathLengthSumsConsecutiveLegs() {
        let path = [Fixtures.bristol, Fixtures.bath, Fixtures.london]
        let expected = Geo.distanceKm(Fixtures.bristol, Fixtures.bath)
            + Geo.distanceKm(Fixtures.bath, Fixtures.london)

        XCTAssertEqual(Geo.pathLengthKm(path), expected, accuracy: 1e-6)
        XCTAssertEqual(Geo.pathLengthKm([Fixtures.bristol]), 0)
    }
}
