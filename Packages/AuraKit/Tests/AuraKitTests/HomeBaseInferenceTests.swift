import XCTest
@testable import AuraKit

final class HomeBaseInferenceTests: XCTestCase {

    private func infer(_ seeds: [MemorySeed]) -> HomeBase? {
        HomeBaseInference.infer(from: seeds, calendar: Fixtures.calendar)
    }

    func testInfersHomeFromNightTimePhotos() {
        let home = infer(Fixtures.nightsAtHome(Fixtures.bristol, nights: 10))

        XCTAssertNotNil(home)
        XCTAssertEqual(Geo.distanceKm(home!.coordinate, Fixtures.bristol), 0, accuracy: 1)
        XCTAssertEqual(home?.support, 30)
    }

    func testReturnsNilBelowMinimumSupport() {
        XCTAssertNil(infer(Fixtures.nightsAtHome(Fixtures.bristol, nights: 2)))
    }

    func testReturnsNilWhenNoPhotoHasALocation() {
        let seeds = (0..<50).map {
            MemorySeed(id: "\($0)", createdAt: Fixtures.date(day: Double($0), hour: 23), coordinate: nil)
        }
        XCTAssertNil(infer(seeds))
    }

    /// Daytime photos say nothing about where you sleep. A month of tourist photos in
    /// Tokyo must not relocate a Bristol resident's home.
    func testDaytimePhotosElsewhereDoNotMoveHome() {
        let seeds = Fixtures.nightsAtHome(Fixtures.bristol, nights: 10)
            + (0..<25).flatMap { day in
                (0..<8).map { index in
                    MemorySeed(
                        id: "tokyo-\(day)-\(index)",
                        createdAt: Fixtures.date(day: Double(day), hour: 9 + Double(index)),
                        coordinate: Fixtures.tokyo
                    )
                }
            }

        let home = infer(seeds)
        XCTAssertEqual(Geo.distanceKm(home!.coordinate, Fixtures.bristol), 0, accuracy: 1)
    }

    /// A long trip does produce night-time photos abroad — home is still wherever the
    /// most nights were spent.
    func testHomeIsTheMostFrequentNightLocation() {
        let seeds = Fixtures.nightsAtHome(Fixtures.bristol, nights: 40)
            + (0..<7).flatMap { night in
                (0..<3).map { index in
                    MemorySeed(
                        id: "lisbon-night-\(night)-\(index)",
                        createdAt: Fixtures.date(day: Double(night), hour: 22 + Double(index) * 0.5),
                        coordinate: Fixtures.lisbon
                    )
                }
            }

        let home = infer(seeds)
        XCTAssertEqual(Geo.distanceKm(home!.coordinate, Fixtures.bristol), 0, accuracy: 1)
    }

    func testHoursBeforeSixAmCountAsNight() {
        let seeds = (0..<30).map {
            MemorySeed(id: "\($0)", createdAt: Fixtures.date(day: Double($0), hour: 3), coordinate: Fixtures.bristol)
        }
        XCTAssertEqual(infer(seeds)?.support, 30)
    }
}
