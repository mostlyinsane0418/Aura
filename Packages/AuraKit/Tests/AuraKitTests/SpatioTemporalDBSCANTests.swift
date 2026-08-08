import XCTest
@testable import AuraKit

final class SpatioTemporalDBSCANTests: XCTestCase {

    private func cluster(
        _ seeds: [MemorySeed],
        spatialKm: Double = 50,
        temporalHours: Double = 36,
        minimumPoints: Int = 5
    ) -> [[Int]] {
        SpatioTemporalDBSCAN.cluster(
            points: seeds.map { .init(date: $0.createdAt, coordinate: $0.coordinate!) },
            spatialEpsilonKm: spatialKm,
            temporalEpsilonHours: temporalHours,
            minimumPoints: minimumPoints
        )
    }

    func testEmptyInputProducesNoClusters() {
        XCTAssertTrue(cluster([]).isEmpty)
    }

    func testSeparatesTwoDistantClusters() {
        let seeds = Fixtures.burst("bristol", at: Fixtures.bristol, day: 0)
            + Fixtures.burst("tokyo", at: Fixtures.tokyo, day: 40)

        let clusters = cluster(seeds)
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.map(\.count).sorted(), [8, 8])
    }

    /// Same coordinates, months apart: one place, two trips.
    func testSameLocationAtDifferentTimesSplits() {
        let seeds = Fixtures.burst("spring", at: Fixtures.lisbon, day: 0)
            + Fixtures.burst("autumn", at: Fixtures.lisbon, day: 180)

        XCTAssertEqual(cluster(seeds).count, 2)
    }

    /// A blank night between two days of shooting must not split a trip.
    func testConsecutiveDaysBridgeOvernightGap() {
        let seeds = Fixtures.burst("d1", at: Fixtures.lisbon, day: 10, startHour: 10, spanHours: 4)
            + Fixtures.burst("d2", at: Fixtures.lisbon, day: 11, startHour: 10, spanHours: 4)
            + Fixtures.burst("d3", at: Fixtures.lisbon, day: 12, startHour: 10, spanHours: 4)

        let clusters = cluster(seeds)
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].count, 24)
    }

    /// The regression this guards: an 18-hour epsilon cannot span 20 hours of night,
    /// so a three-day trip fragments into three.
    func testTooTightTemporalEpsilonFragmentsATrip() {
        let seeds = Fixtures.burst("d1", at: Fixtures.lisbon, day: 10, startHour: 10, spanHours: 4)
            + Fixtures.burst("d2", at: Fixtures.lisbon, day: 11, startHour: 10, spanHours: 4)

        XCTAssertEqual(cluster(seeds, temporalHours: 18).count, 2)
        XCTAssertEqual(cluster(seeds, temporalHours: 36).count, 1)
    }

    func testSparsePointsBecomeNoise() {
        let lonely = (0..<3).map {
            MemorySeed(
                id: "lonely-\($0)",
                createdAt: Fixtures.date(day: Double($0) * 30),
                coordinate: Fixtures.bristol
            )
        }
        XCTAssertTrue(cluster(lonely).isEmpty)
    }

    /// Space and time are independent thresholds: exceeding either one breaks the
    /// link, and staying inside both keeps it, however much of each budget is used.
    func testBothThresholdsMustHold() {
        func pair(_ a: Coordinate, _ b: Coordinate, hoursApart: Double) -> [MemorySeed] {
            [
                MemorySeed(id: "a", createdAt: Fixtures.date(day: 0, hour: 0), coordinate: a),
                MemorySeed(id: "b", createdAt: Fixtures.date(day: 0, hour: hoursApart), coordinate: b)
            ]
        }

        // Deep into both budgets — 18km and 30h — but inside both, so still linked.
        XCTAssertEqual(cluster(pair(Fixtures.bristol, Fixtures.bath, hoursApart: 30), minimumPoints: 2).count, 1)

        // Close in time, too far in space: neither point reaches the other, so with
        // minimumPoints of 2 both are noise and no cluster survives.
        XCTAssertTrue(cluster(pair(Fixtures.bristol, Fixtures.london, hoursApart: 1), minimumPoints: 2).isEmpty)

        // Same place, too far apart in time.
        XCTAssertTrue(cluster(pair(Fixtures.bristol, Fixtures.bristol, hoursApart: 40), minimumPoints: 2).isEmpty)
    }

    /// The failure this guards against: a holiday that moves between nearby towns and
    /// sleeps overnight uses much of both budgets at once. Under a summed metric that
    /// exceeds the threshold and a normal trip shatters into one journey per town.
    func testTripHoppingBetweenNearbyTownsStaysOneCluster() {
        let seeds = Fixtures.burst("lis", at: Fixtures.lisbon, day: 10, startHour: 10, spanHours: 4)
            + Fixtures.burst("sin", at: Fixtures.sintra, day: 11, startHour: 10, spanHours: 4)
            + Fixtures.burst("lis2", at: Fixtures.lisbon, day: 12, startHour: 10, spanHours: 4)

        let clusters = cluster(seeds)
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].count, 24)
    }

    func testClustersAndMembersAreChronological() {
        let seeds = Fixtures.burst("late", at: Fixtures.tokyo, day: 40)
            + Fixtures.burst("early", at: Fixtures.bristol, day: 0)

        let clusters = cluster(seeds)
        XCTAssertEqual(clusters.count, 2)

        let firstDates = clusters.map { seeds[$0[0]].createdAt }
        XCTAssertEqual(firstDates, firstDates.sorted())

        for indices in clusters {
            let dates = indices.map { seeds[$0].createdAt }
            XCTAssertEqual(dates, dates.sorted())
        }
    }

    func testEveryPointAppearsAtMostOnce() {
        let seeds = Fixtures.burst("a", at: Fixtures.lisbon, day: 0)
            + Fixtures.burst("b", at: Fixtures.lisbon, day: 1)
            + Fixtures.burst("c", at: Fixtures.tokyo, day: 60)

        let assigned = cluster(seeds).flatMap { $0 }
        XCTAssertEqual(assigned.count, Set(assigned).count)
    }

    /// Photo libraries do not arrive in a guaranteed order, so the same set of assets
    /// must produce the same journeys regardless of how they were enumerated.
    func testResultIsIndependentOfInputOrder() {
        let seeds = Fixtures.burst("a", at: Fixtures.lisbon, day: 0)
            + Fixtures.burst("b", at: Fixtures.tokyo, day: 50)
            + Fixtures.burst("c", at: Fixtures.bristol, day: 100)

        func clusteredIDs(_ input: [MemorySeed]) -> [[String]] {
            cluster(input).map { $0.map { input[$0].id } }
        }

        let expected = clusteredIDs(seeds)
        XCTAssertEqual(expected.map(\.count), [8, 8, 8])

        var generator = SystemRandomNumberGenerator()
        for _ in 0..<5 {
            XCTAssertEqual(clusteredIDs(seeds.shuffled(using: &generator)), expected)
        }
    }
}
