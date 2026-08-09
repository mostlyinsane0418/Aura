import Foundation

/// Where the user lives, inferred rather than asked.
///
/// The signal is night-time photos: between 22:00 and 06:00 local time people are
/// overwhelmingly at home, and the handful of nights they are not are exactly the
/// nights we want to classify as travel. Taking the densest cell of night-time
/// coordinates gives a home base without a single onboarding question.
public struct HomeBase: Hashable, Sendable {
    public let coordinate: Coordinate
    /// How many night-time photos supported this inference. Low support means the
    /// caller should be sceptical and fall back to duration-based journey detection.
    public let support: Int

    public init(coordinate: Coordinate, support: Int) {
        self.coordinate = coordinate
        self.support = support
    }
}

public enum HomeBaseInference {

    /// Minimum night-time photos before we trust the inference at all.
    public static let minimumSupport = 20

    /// ~0.25° cells: roughly 28km north-south, less east-west at latitude. Coarse
    /// enough that a city is one bucket, fine enough that neighbouring cities are not.
    static let cellSize = 0.25

    /// How many located photos fall in the night-time window — the evidence available
    /// to `infer`. Below `minimumSupport` no home base is produced at all.
    public static func nightTimeSampleCount(
        from seeds: [MemorySeed],
        calendar: Calendar = Calendar(identifier: .gregorian),
        nightStartHour: Int = 22,
        nightEndHour: Int = 6
    ) -> Int {
        seeds.count { seed in
            guard seed.coordinate != nil else { return false }
            let hour = calendar.component(.hour, from: seed.createdAt)
            return hour >= nightStartHour || hour < nightEndHour
        }
    }

    public static func infer(
        from seeds: [MemorySeed],
        calendar: Calendar = Calendar(identifier: .gregorian),
        nightStartHour: Int = 22,
        nightEndHour: Int = 6
    ) -> HomeBase? {
        var buckets: [Cell: [Coordinate]] = [:]

        for seed in seeds {
            guard let coordinate = seed.coordinate else { continue }
            let hour = calendar.component(.hour, from: seed.createdAt)
            let isNight = hour >= nightStartHour || hour < nightEndHour
            guard isNight else { continue }

            buckets[Cell(coordinate), default: []].append(coordinate)
        }

        // Ties are broken deterministically so repeated runs on the same library
        // never produce a different home base.
        guard let winner = buckets.max(by: { lhs, rhs in
            lhs.value.count != rhs.value.count
                ? lhs.value.count < rhs.value.count
                : lhs.key > rhs.key
        }) else { return nil }

        guard winner.value.count >= minimumSupport,
              let centroid = Geo.centroid(of: winner.value) else { return nil }

        return HomeBase(coordinate: centroid, support: winner.value.count)
    }

    struct Cell: Hashable, Comparable {
        let x: Int
        let y: Int

        init(_ coordinate: Coordinate) {
            x = Int((coordinate.longitude / cellSize).rounded(.down))
            y = Int((coordinate.latitude / cellSize).rounded(.down))
        }

        static func < (lhs: Cell, rhs: Cell) -> Bool {
            (lhs.y, lhs.x) < (rhs.y, rhs.x)
        }
    }
}
