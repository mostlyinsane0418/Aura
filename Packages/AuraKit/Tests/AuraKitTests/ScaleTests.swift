import XCTest
@testable import AuraKit

/// A real target library is tens of thousands of assets, and ingest has to finish
/// while the user is still looking at the launch animation. A naive all-pairs
/// neighbour query is O(n²) and would take minutes here; the time-windowed query
/// keeps it near-linear. This test exists to make that regression loud.
final class ScaleTests: XCTestCase {

    private func syntheticLibrary(
        years: Int,
        photosPerDay: Int,
        tripsPerYear: Int,
        tripLengthDays: Int
    ) -> [MemorySeed] {
        var seeds: [MemorySeed] = []
        var identifier = 0

        let destinations = [Fixtures.lisbon, Fixtures.tokyo, Fixtures.london, Fixtures.sintra]

        for year in 0..<years {
            let tripStarts = (0..<tripsPerYear).map { 40 + $0 * (300 / max(1, tripsPerYear)) }

            for dayOfYear in 0..<365 {
                let absoluteDay = Double(year * 365 + dayOfYear)

                let trip = tripStarts.enumerated().first { _, start in
                    dayOfYear >= start && dayOfYear < start + tripLengthDays
                }

                let coordinate = trip.map { destinations[$0.offset % destinations.count] }
                    ?? Fixtures.bristol

                for photo in 0..<photosPerDay {
                    identifier += 1
                    // Spread across the day, including a couple of night-time frames
                    // at home so home-base inference has something to work with.
                    let hour = 8 + Double(photo) * (15.0 / Double(max(1, photosPerDay)))
                    seeds.append(MemorySeed(
                        id: "asset-\(identifier)",
                        createdAt: Fixtures.date(day: absoluteDay, hour: hour),
                        coordinate: coordinate
                    ))
                }
            }
        }
        return seeds
    }

    func testBuildsJourneysForALargeLibraryQuickly() throws {
        let seeds = syntheticLibrary(years: 6, photosPerDay: 20, tripsPerYear: 4, tripLengthDays: 6)
        XCTAssertEqual(seeds.count, 43_800)

        let builder = JourneyBuilder(calendar: Fixtures.calendar)

        let started = Date()
        let result = builder.build(from: seeds)
        let elapsed = Date().timeIntervalSince(started)

        // 24 trips over six years, all far from the inferred Bristol home base.
        XCTAssertEqual(result.journeys.count, 24)
        XCTAssertNotNil(result.homeBase)
        XCTAssertEqual(Geo.distanceKm(result.homeBase!.coordinate, Fixtures.bristol), 0, accuracy: 1)

        for journey in result.journeys {
            XCTAssertEqual(journey.memoryIDs.count, 120)
            XCTAssertFalse(journey.chapters.isEmpty)
        }

        // Generous enough not to flake on a loaded CI machine, tight enough that an
        // accidental O(n²) neighbour scan cannot slip through.
        XCTAssertLessThan(elapsed, 20, "Journey build took \(elapsed)s for \(seeds.count) assets")
    }
}
