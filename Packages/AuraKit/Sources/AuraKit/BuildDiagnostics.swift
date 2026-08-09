import Foundation

/// Why a cluster of photos did or did not become a journey.
///
/// An empty feed has several very different causes — a library with no GPS data, a
/// home base swallowing everything, thresholds set too tight — and they are
/// indistinguishable from the outside. This records the reason for every decision so
/// "no journeys yet" can be diagnosed rather than guessed at.
public struct BuildDiagnostics: Sendable, Equatable {

    public enum ClusterOutcome: Sendable, Equatable {
        case accepted
        case tooFewMemories(count: Int, minimum: Int)
        /// The cluster is real, but it sits inside the ordinary-life radius.
        case tooCloseToHome(distanceKm: Double, radiusKm: Double)
        /// No home base to compare against, and the cluster is too brief to be a trip.
        case tooShort(days: Int, minimumDays: Int)

        public var isAccepted: Bool { self == .accepted }
    }

    public struct ClusterReport: Sendable, Equatable {
        public let memoryCount: Int
        public let startDate: Date
        public let endDate: Date
        public let centroid: Coordinate?
        public let distanceFromHomeKm: Double?
        public let outcome: ClusterOutcome

        public init(
            memoryCount: Int,
            startDate: Date,
            endDate: Date,
            centroid: Coordinate?,
            distanceFromHomeKm: Double?,
            outcome: ClusterOutcome
        ) {
            self.memoryCount = memoryCount
            self.startDate = startDate
            self.endDate = endDate
            self.centroid = centroid
            self.distanceFromHomeKm = distanceFromHomeKm
            self.outcome = outcome
        }
    }

    public let totalMemories: Int
    public let locatedMemories: Int
    /// Photos with a coordinate taken between 22:00 and 06:00 — the only evidence
    /// home-base inference has. Below `HomeBaseInference.minimumSupport` there is no
    /// home base, and journey detection falls back to duration.
    public let nightTimeLocatedMemories: Int
    /// Located photos that landed in no cluster at all: isolated in space and time.
    public let unclusteredLocatedMemories: Int
    public let clusters: [ClusterReport]

    public var unlocatedMemories: Int { totalMemories - locatedMemories }
    public var acceptedClusters: Int { clusters.count { $0.outcome.isAccepted } }
}
