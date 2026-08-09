import XCTest
@testable import AuraKit

final class JourneyBuilderTests: XCTestCase {

    private let builder = JourneyBuilder(calendar: Fixtures.calendar)

    private var homeNights: [MemorySeed] {
        Fixtures.nightsAtHome(Fixtures.bristol, nights: 20)
    }

    private func lisbonTrip() -> [MemorySeed] {
        Fixtures.burst("lis-d1", at: Fixtures.lisbon, day: 10, startHour: 10, spanHours: 4)
            + Fixtures.burst("lis-d2", at: Fixtures.lisbon, day: 11, startHour: 10, spanHours: 4)
            + Fixtures.burst("lis-d3", at: Fixtures.lisbon, day: 12, startHour: 10, spanHours: 4)
    }

    // MARK: - The core promise

    func testRebuildsATripFromAnUnsortedLibrary() {
        let result = builder.build(from: (homeNights + lisbonTrip()).shuffled())

        XCTAssertEqual(result.journeys.count, 1)
        let journey = try! XCTUnwrap(result.journeys.first)

        XCTAssertEqual(journey.memoryIDs.count, 24)
        XCTAssertEqual(Geo.distanceKm(journey.centroid!, Fixtures.lisbon), 0, accuracy: 1)
        XCTAssertEqual(journey.startDate, Fixtures.date(day: 10, hour: 10))
        XCTAssertEqual(journey.endDate, Fixtures.date(day: 12, hour: 14))
        XCTAssertEqual(journey.dayCount, 3)
    }

    func testEverydayLifeAtHomeIsNotAJourney() {
        let result = builder.build(from: homeNights)

        XCTAssertTrue(result.journeys.isEmpty)
        XCTAssertEqual(result.unassignedMemoryIDs.count, homeNights.count)
        XCTAssertNotNil(result.homeBase)
    }

    /// Bath is 18km from Bristol — a nice day out, not a trip. The home radius is
    /// what stops the feed filling with the user's own city.
    func testNearbyDayTripIsNotAJourney() {
        let seeds = homeNights + Fixtures.burst("bath", at: Fixtures.bath, day: 20)
        XCTAssertTrue(builder.build(from: seeds).journeys.isEmpty)
    }

    func testMultipleTripsBecomeSeparateJourneysNewestFirst() {
        let seeds = homeNights
            + lisbonTrip()
            + Fixtures.burst("tky-d1", at: Fixtures.tokyo, day: 100, startHour: 9, spanHours: 6)
            + Fixtures.burst("tky-d2", at: Fixtures.tokyo, day: 101, startHour: 9, spanHours: 6)

        let journeys = builder.build(from: seeds).journeys
        XCTAssertEqual(journeys.count, 2)
        XCTAssertEqual(Geo.distanceKm(journeys[0].centroid!, Fixtures.tokyo), 0, accuracy: 1)
        XCTAssertEqual(Geo.distanceKm(journeys[1].centroid!, Fixtures.lisbon), 0, accuracy: 1)
    }

    /// A day trip out of the city you are staying in is further from your hotel than
    /// any sane spatial epsilon allows, so density clustering hands it back as its own
    /// cluster. It is still the same holiday.
    func testAFarDayTripDuringATripStaysInTheSameJourney() {
        let seeds = homeNights
            + Fixtures.burst("tky-d1", at: Fixtures.tokyo, day: 100, startHour: 9, spanHours: 6)
            + Fixtures.burst("hak", at: Fixtures.hakone, day: 101, startHour: 9, spanHours: 6)
            + Fixtures.burst("tky-d3", at: Fixtures.tokyo, day: 102, startHour: 9, spanHours: 6)

        let journeys = builder.build(from: seeds.shuffled()).journeys

        XCTAssertEqual(journeys.count, 1)
        XCTAssertEqual(journeys[0].memoryIDs.count, 24)
        XCTAssertEqual(journeys[0].dayCount, 3)
    }

    /// Merging is bounded by time: trips separated by a spell back home stay apart
    /// even when the destinations are close together.
    func testTripsSeparatedByTimeAreNotMerged() {
        let seeds = homeNights
            + Fixtures.burst("lis-a1", at: Fixtures.lisbon, day: 10, startHour: 9, spanHours: 6)
            + Fixtures.burst("lis-a2", at: Fixtures.lisbon, day: 11, startHour: 9, spanHours: 6)
            + Fixtures.burst("lis-b1", at: Fixtures.lisbon, day: 40, startHour: 9, spanHours: 6)
            + Fixtures.burst("lis-b2", at: Fixtures.lisbon, day: 41, startHour: 9, spanHours: 6)

        XCTAssertEqual(builder.build(from: seeds).journeys.count, 2)
    }

    // MARK: - Diagnostics

    func testDiagnosticsExplainWhyAClusterWasRejected() {
        let seeds = homeNights + Fixtures.burst("bath", at: Fixtures.bath, day: 20)
        let diagnostics = builder.build(from: seeds).diagnostics

        XCTAssertEqual(diagnostics.totalMemories, seeds.count)
        XCTAssertEqual(diagnostics.locatedMemories, seeds.count)
        XCTAssertEqual(diagnostics.unlocatedMemories, 0)
        XCTAssertEqual(diagnostics.nightTimeLocatedMemories, homeNights.count)
        XCTAssertEqual(diagnostics.acceptedClusters, 0)

        let bath = try! XCTUnwrap(diagnostics.clusters.first {
            $0.startDate == Fixtures.date(day: 20, hour: 10)
        })
        guard case let .tooCloseToHome(distance, radius) = bath.outcome else {
            return XCTFail("expected a home-radius rejection, got \(bath.outcome)")
        }
        XCTAssertEqual(distance, Geo.distanceKm(Fixtures.bath, Fixtures.bristol), accuracy: 1)
        XCTAssertEqual(radius, builder.configuration.homeRadiusKm)
    }

    func testDiagnosticsCountPhotosWithNoCoordinate() {
        let seeds = homeNights + lisbonTrip()
            + Fixtures.burst("screenshot", at: nil, day: 10, count: 3)
        let diagnostics = builder.build(from: seeds).diagnostics

        XCTAssertEqual(diagnostics.unlocatedMemories, 3)
        XCTAssertEqual(diagnostics.locatedMemories, seeds.count - 3)
    }

    // MARK: - Chapters

    func testJourneySplitsIntoChaptersByPlace() {
        let seeds = homeNights
            + Fixtures.burst("lis", at: Fixtures.lisbon, day: 10, startHour: 10, spanHours: 4)
            + Fixtures.burst("sin", at: Fixtures.sintra, day: 11, startHour: 10, spanHours: 4)
            + Fixtures.burst("lis2", at: Fixtures.lisbon, day: 12, startHour: 10, spanHours: 4)

        let journey = builder.build(from: seeds).journeys[0]
        XCTAssertEqual(journey.chapters.count, 3)
        XCTAssertEqual(journey.chapters.map(\.memoryIDs.count), [8, 8, 8])

        let starts = journey.chapters.map(\.startDate)
        XCTAssertEqual(starts, starts.sorted())
        XCTAssertEqual(Geo.distanceKm(journey.chapters[1].centroid!, Fixtures.sintra), 0, accuracy: 1)
    }

    func testEveryJourneyMemoryBelongsToExactlyOneChapter() {
        let seeds = homeNights + lisbonTrip()
        let journey = builder.build(from: seeds).journeys[0]

        let chaptered = journey.chapters.flatMap(\.memoryIDs)
        XCTAssertEqual(Set(chaptered), Set(journey.memoryIDs))
        XCTAssertEqual(chaptered.count, Set(chaptered).count)
    }

    // MARK: - Photos with no coordinate

    /// Boarding-pass screenshots and AirDropped shots from a friend's phone carry no
    /// GPS at all, but they are unmistakably part of the trip.
    func testUnlocatedPhotosTakenDuringATripAreAbsorbed() {
        let screenshots = (0..<3).map {
            MemorySeed(
                id: "screenshot-\($0)",
                createdAt: Fixtures.date(day: 11, hour: 15 + Double($0)),
                coordinate: nil
            )
        }

        let journey = builder.build(from: homeNights + lisbonTrip() + screenshots).journeys[0]
        XCTAssertEqual(journey.memoryIDs.count, 27)
        for screenshot in screenshots {
            XCTAssertTrue(journey.memoryIDs.contains(screenshot.id))
            XCTAssertTrue(journey.chapters.contains { $0.memoryIDs.contains(screenshot.id) })
        }
    }

    func testUnlocatedPhotosOutsideEveryTripAreLeftOut() {
        let stray = MemorySeed(id: "stray", createdAt: Fixtures.date(day: 200), coordinate: nil)

        let result = builder.build(from: homeNights + lisbonTrip() + [stray])
        XCTAssertEqual(result.journeys[0].memoryIDs.count, 24)
        XCTAssertTrue(result.unassignedMemoryIDs.contains("stray"))
    }

    /// A photo taken in the airport lounge a few hours before the first located shot
    /// still reads as the start of the trip.
    func testUnlocatedPhotoWithinGraceWindowIsAbsorbed() {
        let lounge = MemorySeed(id: "lounge", createdAt: Fixtures.date(day: 10, hour: 4), coordinate: nil)

        let journey = builder.build(from: homeNights + lisbonTrip() + [lounge]).journeys[0]
        XCTAssertTrue(journey.memoryIDs.contains("lounge"))
    }

    // MARK: - Fallback when home is unknown

    /// A fresh phone has no night-time history to infer a home from. Duration is the
    /// only signal left, so a multi-day cluster is treated as travel.
    func testWithoutAHomeBaseMultiDayClustersAreJourneys() {
        let result = builder.build(from: lisbonTrip())

        XCTAssertNil(result.homeBase)
        XCTAssertEqual(result.journeys.count, 1)
        XCTAssertEqual(result.journeys[0].memoryIDs.count, 24)
    }

    func testWithoutAHomeBaseASingleDayClusterIsNotAJourney() {
        let result = builder.build(from: Fixtures.burst("day", at: Fixtures.lisbon, day: 10))

        XCTAssertNil(result.homeBase)
        XCTAssertTrue(result.journeys.isEmpty)
    }

    // MARK: - Invariants

    func testEmptyLibraryProducesNothing() {
        let result = builder.build(from: [])
        XCTAssertTrue(result.journeys.isEmpty)
        XCTAssertTrue(result.unassignedMemoryIDs.isEmpty)
        XCTAssertNil(result.homeBase)
    }

    func testNoMemoryAppearsInTwoJourneys() {
        let seeds = homeNights
            + lisbonTrip()
            + Fixtures.burst("tky", at: Fixtures.tokyo, day: 100, spanHours: 6)
            + Fixtures.burst("tky2", at: Fixtures.tokyo, day: 101, spanHours: 6)

        let all = builder.build(from: seeds).journeys.flatMap(\.memoryIDs)
        XCTAssertEqual(all.count, Set(all).count)
    }

    func testAssignedAndUnassignedPartitionTheLibrary() {
        let seeds = homeNights + lisbonTrip()
        let result = builder.build(from: seeds)

        let assigned = Set(result.journeys.flatMap(\.memoryIDs))
        XCTAssertTrue(assigned.isDisjoint(with: Set(result.unassignedMemoryIDs)))
        XCTAssertEqual(
            assigned.union(result.unassignedMemoryIDs),
            Set(seeds.map(\.id))
        )
    }

    func testResultIsIndependentOfInputOrder() {
        let seeds = homeNights + lisbonTrip()
        let expected = builder.build(from: seeds).journeys.map(\.memoryIDs)

        for _ in 0..<5 {
            XCTAssertEqual(builder.build(from: seeds.shuffled()).journeys.map(\.memoryIDs), expected)
        }
    }

    func testAnExplicitHomeBaseOverridesInference() {
        // Tell it home is Lisbon: the Lisbon trip becomes everyday life, and the
        // Bristol nights become the journey.
        let result = builder.build(
            from: homeNights + lisbonTrip(),
            homeBase: HomeBase(coordinate: Fixtures.lisbon, support: 999)
        )

        XCTAssertEqual(result.journeys.count, 1)
        XCTAssertEqual(Geo.distanceKm(result.journeys[0].centroid!, Fixtures.bristol), 0, accuracy: 1)
    }
}
