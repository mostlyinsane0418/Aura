import Foundation

public struct JourneyBuildResult: Sendable {
    public let journeys: [Journey]
    public let homeBase: HomeBase?
    /// Memories that belong to no journey — everyday life, and unlocated photos that
    /// fall outside every journey's window. Still shown on the map, never in the feed.
    public let unassignedMemoryIDs: [String]
    /// Why each cluster was accepted or rejected. An empty feed is otherwise
    /// indistinguishable from a broken one.
    public let diagnostics: BuildDiagnostics
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

        var accepted: [[MemorySeed]] = []
        var assigned = Set<String>()
        var reports: [BuildDiagnostics.ClusterReport] = []

        for cluster in clusters {
            let members = cluster.map { located[$0] }
            let centroid = Geo.centroid(of: members.compactMap(\.coordinate))
            let verdict = outcome(for: members, home: home)

            reports.append(BuildDiagnostics.ClusterReport(
                memoryCount: members.count,
                startDate: members.first!.createdAt,
                endDate: members.last!.createdAt,
                centroid: centroid,
                distanceFromHomeKm: home.flatMap { home in
                    centroid.map { Geo.distanceKm($0, home.coordinate) }
                },
                outcome: verdict
            ))

            guard verdict.isAccepted else { continue }
            accepted.append(members)
        }

        var journeys = merge(accepted).map { members -> Journey in
            assigned.formUnion(members.map(\.id))
            return Journey(
                memoryIDs: members.map(\.id),
                chapters: chapters(for: members),
                startDate: members.first!.createdAt,
                endDate: members.last!.createdAt,
                centroid: Geo.centroid(of: members.compactMap(\.coordinate))
            )
        }

        journeys = absorbUnlocated(unlocated, into: journeys, assigned: &assigned)
        journeys.sort { $0.startDate > $1.startDate }

        let unassigned = seeds.map(\.id).filter { !assigned.contains($0) }
        return JourneyBuildResult(
            journeys: journeys,
            homeBase: home,
            unassignedMemoryIDs: unassigned,
            diagnostics: BuildDiagnostics(
                totalMemories: seeds.count,
                locatedMemories: located.count,
                nightTimeLocatedMemories: HomeBaseInference.nightTimeSampleCount(
                    from: seeds,
                    calendar: calendar
                ),
                unclusteredLocatedMemories: located.count - clusters.reduce(0) { $0 + $1.count },
                clusters: reports
            )
        )
    }

    // MARK: - Merging

    /// Stitches clusters that overlap in time back into a single journey.
    ///
    /// Density clustering splits on distance, but a person cannot be on two trips at
    /// once. A day trip out of the city you are staying in — Hakone from Tokyo, 80km —
    /// exceeds any sane spatial epsilon and arrives here as its own cluster, which
    /// would present a single holiday as three. Widening the epsilon instead is the
    /// wrong fix: it would also merge genuinely separate trips to neighbouring places.
    ///
    /// So time gets the final say. Clusters whose date ranges touch, or sit within the
    /// same temporal epsilon used for clustering, describe one continuous period away
    /// and are merged.
    func merge(_ clusters: [[MemorySeed]]) -> [[MemorySeed]] {
        guard clusters.count > 1 else { return clusters }

        let ordered = clusters.sorted { $0.first!.createdAt < $1.first!.createdAt }
        let gap = configuration.temporalEpsilonHours * 3600

        var merged: [[MemorySeed]] = [ordered[0]]
        for cluster in ordered.dropFirst() {
            let currentEnd = merged[merged.count - 1].last!.createdAt
            if cluster.first!.createdAt <= currentEnd.addingTimeInterval(gap) {
                merged[merged.count - 1].append(contentsOf: cluster)
                merged[merged.count - 1].sort { $0.createdAt < $1.createdAt }
            } else {
                merged.append(cluster)
            }
        }
        return merged
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
        outcome(for: members, home: home).isAccepted
    }

    func outcome(for members: [MemorySeed], home: HomeBase?) -> BuildDiagnostics.ClusterOutcome {
        guard members.count >= configuration.minimumJourneyMemories else {
            return .tooFewMemories(
                count: members.count,
                minimum: configuration.minimumJourneyMemories
            )
        }

        if let home, let centroid = Geo.centroid(of: members.compactMap(\.coordinate)) {
            let distance = Geo.distanceKm(centroid, home.coordinate)
            return distance >= configuration.homeRadiusKm
                ? .accepted
                : .tooCloseToHome(distanceKm: distance, radiusKm: configuration.homeRadiusKm)
        }

        let span = (calendar.dateComponents(
            [.day],
            from: members.first!.createdAt,
            to: members.last!.createdAt
        ).day ?? 0) + 1
        return span >= configuration.minimumJourneyDays
            ? .accepted
            : .tooShort(days: span, minimumDays: configuration.minimumJourneyDays)
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
