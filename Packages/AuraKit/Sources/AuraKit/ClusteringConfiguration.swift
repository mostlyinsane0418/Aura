import Foundation

/// Tuning for the journey/chapter clustering. Exposed as a value type so it can be
/// swept against a real library without touching the algorithm.
public struct ClusteringConfiguration: Hashable, Sendable {
    /// Spatial reach of the journey-level neighbourhood.
    public var spatialEpsilonKm: Double
    /// Temporal reach of the journey-level neighbourhood.
    ///
    /// This has to comfortably exceed one night. People photograph the day and stop
    /// at dinner, so consecutive days of the same trip are routinely 20+ hours apart;
    /// anything tighter shatters a week in Lisbon into seven one-day "journeys".
    /// 36 hours bridges a full blank day while still keeping two weekend trips to the
    /// same city a fortnight apart firmly separate.
    public var temporalEpsilonHours: Double
    /// Minimum neighbours (including self) for a point to be a DBSCAN core point.
    public var minimumPoints: Int

    /// Anything inside this radius of the inferred home base is everyday life.
    public var homeRadiusKm: Double
    /// Fallback when no home base can be inferred: a cluster spanning at least this
    /// many days is treated as a journey.
    public var minimumJourneyDays: Int
    /// A cluster below this size is noise, however far from home it is.
    public var minimumJourneyMemories: Int

    public var chapterSpatialEpsilonKm: Double
    public var chapterTemporalEpsilonHours: Double
    public var chapterMinimumPoints: Int

    /// How far outside a journey's date range an unlocated photo may fall and still
    /// be absorbed into it.
    public var unlocatedGraceHours: Double

    public init(
        spatialEpsilonKm: Double = 50,
        temporalEpsilonHours: Double = 36,
        minimumPoints: Int = 5,
        homeRadiusKm: Double = 40,
        minimumJourneyDays: Int = 2,
        minimumJourneyMemories: Int = 5,
        chapterSpatialEpsilonKm: Double = 5,
        chapterTemporalEpsilonHours: Double = 6,
        chapterMinimumPoints: Int = 3,
        unlocatedGraceHours: Double = 12
    ) {
        self.spatialEpsilonKm = spatialEpsilonKm
        self.temporalEpsilonHours = temporalEpsilonHours
        self.minimumPoints = minimumPoints
        self.homeRadiusKm = homeRadiusKm
        self.minimumJourneyDays = minimumJourneyDays
        self.minimumJourneyMemories = minimumJourneyMemories
        self.chapterSpatialEpsilonKm = chapterSpatialEpsilonKm
        self.chapterTemporalEpsilonHours = chapterTemporalEpsilonHours
        self.chapterMinimumPoints = chapterMinimumPoints
        self.unlocatedGraceHours = unlocatedGraceHours
    }

    public static let `default` = ClusteringConfiguration()
}
