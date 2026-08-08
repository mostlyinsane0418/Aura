import Foundation

public struct JourneyBuildResult: Sendable {
    public let journeys: [Journey]
    public let homeBase: HomeBase?
    /// Memories that belong to no journey — everyday life, and unlocated photos that
    /// fall outside every journey's window. Still shown on the map, never in the feed.
    public let unassignedMemoryIDs: [String]
}

/// Turns a flat library into journeys and chapters.
///
/// Pipeline:
///   1. infer the home base from night-time photos
///   2. DBSCAN the located photos over the combined space/time metric
///   3. keep the clusters that read as travel rather than everyday life
///   4. sub-cluster each journey into chapters
///   5. absorb unlocated photos (screenshots, AirDrops, old cameras) by time
public struct JourneyBuilder: Sendable {
    public let configuration: ClusteringConfiguration
    private let calendar: Calendar

    public init(
        configuration: ClusteringConfiguration = .default,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.configuration = configuration
        self.calendar = calendar
    }

    public func build(from seeds: [MemorySeed], homeBase: HomeBase? = nil) -> JourneyBuildResult {
        let home = homeBase ?? HomeBaseInference.infer(from: seeds, calendar: calendar)

        let located = seeds.filter { $0.coordinate != nil }
        let unlocated = seeds.filter { $0.coordinate == nil }

        let clusters = SpatioTemporalDBSCAN.cluster(
            points: located.map {
                .init(date: $0.createdAt, coordinate: $0.coordinate!)
            },
            spatialEpsilonKm: configuration.spatialEpsilonKm,
            temporalEpsilonHours: configuration.temporalEpsilonHours,
            minimumPoints: configuration.minimumPoints
        )

        var journeys: [Journey] = []
        var assigned = Set<String>()

        for cluster in clusters {
            let members = cluster.map { located[$0] }
            guard qualifiesAsJourney(members, home: home) else { continue }

            let coordinates = members.compactMap(\.coordinate)
            let journey = Journey(
                memoryIDs: members.map(\.id),
                chapters: chapters(for: members),
                startDate: members.first!.createdAt,
                endDate: members.last!.createdAt,
                centroid: Geo.centroid(of: coordinates)
            )
            journeys.append(journey)
            assigned.formUnion(journey.memoryIDs)
        }

        journeys = absorbUnlocated(unlocated, into: journeys, assigned: &assigned)
        journeys.sort { $0.startDate > $1.startDate }

        let unassigned = seeds.map(\.id).filter { !assigned.contains($0) }
        return JourneyBuildResult(
            journeys: journeys,
            homeBase: home,
            unassignedMemoryIDs: unassigned
        )
    }

    // MARK: - Journey qualification

    /// A cluster is a journey when it happened away from home. Distance is measured
    /// from the cluster centroid rather than its furthest point, so a trip that
    /// merely passes near somewhere far away is not promoted on that alone.
    ///
    /// Without a trustworthy home base — a new phone, a library with no night-time
    /// location data — we cannot tell "away" from "here", so we fall back to
    /// duration: a multi-day cluster is a trip often enough to be a safe default.
    func qualifiesAsJourney(_ members: [MemorySeed], home: HomeBase?) -> Bool {
        guard members.count >= configuration.minimumJourneyMemories else { return false }

        if let home, let centroid = Geo.centroid(of: members.compactMap(\.coordinate)) {
            return Geo.distanceKm(centroid, home.coordinate) >= configuration.homeRadiusKm
        }

        let span = calendar.dateComponents(
            [.day],
            from: members.first!.createdAt,
            to: members.last!.createdAt
        ).day ?? 0
        return span + 1 >= configuration.minimumJourneyDays
    }

    // MARK: - Chapters

    func chapters(for members: [MemorySeed]) -> [Chapter] {
        let clusters = SpatioTemporalDBSCAN.cluster(
            points: members.map { .init(date: $0.createdAt, coordinate: $0.coordinate!) },
            spatialEpsilonKm: configuration.chapterSpatialEpsilonKm,
            temporalEpsilonHours: configuration.chapterTemporalEpsilonHours,
            minimumPoints: configuration.chapterMinimumPoints
        )

        var chapters = clusters.map { cluster -> Chapter in
            let chapterMembers = cluster.map { members[$0] }
            return Chapter(
                memoryIDs: chapterMembers.map(\.id),
                startDate: chapterMembers.first!.createdAt,
                endDate: chapterMembers.last!.createdAt,
                centroid: Geo.centroid(of: chapterMembers.compactMap(\.coordinate))
            )
        }

        // Photos the tighter pass rejected as noise still belong to the journey, so
        // fold them into the nearest chapter in time rather than losing them.
        let claimed = Set(chapters.flatMap(\.memoryIDs))
        let orphans = members.filter { !claimed.contains($0.id) }

        if chapters.isEmpty {
            guard !members.isEmpty else { return [] }
            return [Chapter(
                memoryIDs: members.map(\.id),
                startDate: members.first!.createdAt,
                endDate: members.last!.createdAt,
                centroid: Geo.centroid(of: members.compactMap(\.coordinate))
            )]
        }

        for orphan in orphans {
            guard let target = chapters.indices.min(by: {
                temporalGap(orphan.createdAt, chapters[$0]) < temporalGap(orphan.createdAt, chapters[$1])
            }) else { continue }

            chapters[target].memoryIDs.append(orphan.id)
            chapters[target].startDate = min(chapters[target].startDate, orphan.createdAt)
            chapters[target].endDate = max(chapters[target].endDate, orphan.createdAt)
        }

        return chapters.sorted { $0.startDate < $1.startDate }
    }

    private func temporalGap(_ date: Date, _ chapter: Chapter) -> TimeInterval {
        if date < chapter.startDate { return chapter.startDate.timeIntervalSince(date) }
        if date > chapter.endDate { return date.timeIntervalSince(chapter.endDate) }
        return 0
    }

    // MARK: - Unlocated photos

    /// Screenshots of boarding passes, AirDropped photos from a friend's phone, shots
    /// from a camera with no GPS: no coordinate, but unmistakably part of the trip.
    /// Time alone is enough to place them.
    private func absorbUnlocated(
        _ unlocated: [MemorySeed],
        into journeys: [Journey],
        assigned: inout Set<String>
    ) -> [Journey] {
        guard !journeys.isEmpty, !unlocated.isEmpty else { return journeys }

        var journeys = journeys
        let grace = configuration.unlocatedGraceHours * 3600

        for seed in unlocated {
            let candidates = journeys.indices.filter { index in
                seed.createdAt >= journeys[index].startDate.addingTimeInterval(-grace)
                    && seed.createdAt <= journeys[index].endDate.addingTimeInterval(grace)
            }
            // Overlapping windows are possible at trip boundaries; prefer the journey
            // whose middle is closest, which reads as "the trip it happened during".
            guard let target = candidates.min(by: {
                abs(midpoint(journeys[$0]).timeIntervalSince(seed.createdAt))
                    < abs(midpoint(journeys[$1]).timeIntervalSince(seed.createdAt))
            }) else { continue }

            journeys[target].memoryIDs.append(seed.id)
            assigned.insert(seed.id)

            if let chapterIndex = journeys[target].chapters.indices.min(by: {
                temporalGap(seed.createdAt, journeys[target].chapters[$0])
                    < temporalGap(seed.createdAt, journeys[target].chapters[$1])
            }) {
                journeys[target].chapters[chapterIndex].memoryIDs.append(seed.id)
            }
        }

        return journeys
    }

    private func midpoint(_ journey: Journey) -> Date {
        Date(timeIntervalSince1970:
            (journey.startDate.timeIntervalSince1970 + journey.endDate.timeIntervalSince1970) / 2)
    }
}
