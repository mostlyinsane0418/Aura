import Foundation

/// DBSCAN with separate space and time neighbourhoods (Birant & Kut's ST-DBSCAN).
///
/// Two points are neighbours when they are close in *both* dimensions:
///
///     km(a, b) <= spatialEpsilonKm  &&  hours(a, b) <= temporalEpsilonHours
///
/// Density-connectivity then chains individual photos into a trip without ever
/// needing to know how long a trip is: a slow drive across a country stays one
/// journey, while the same coordinates six months apart do not.
///
/// The two thresholds are deliberately independent rather than summed into a single
/// normalised distance. Under a summed metric the dimensions borrow from each other,
/// so a trip that moves 25km between towns and sleeps overnight spends most of both
/// budgets and falls apart — which is precisely the shape of a normal holiday.
///
/// DBSCAN is the right family here because the number of trips is unknown ahead of
/// time (ruling out k-means), clusters are wildly uneven in size, and "noise" is a
/// genuine outcome we want — a single photo taken at an airport at 3am should not
/// be forced into anything.
public enum SpatioTemporalDBSCAN {

    public struct Point: Sendable {
        public let date: Date
        public let coordinate: Coordinate

        public init(date: Date, coordinate: Coordinate) {
            self.date = date
            self.coordinate = coordinate
        }
    }

    /// Indices into the input array, grouped into clusters. Points that end up as
    /// noise appear in no cluster.
    public static func cluster(
        points: [Point],
        spatialEpsilonKm: Double,
        temporalEpsilonHours: Double,
        minimumPoints: Int
    ) -> [[Int]] {
        guard !points.isEmpty else { return [] }

        // Sorting by time lets the neighbour query scan only a bounded window
        // instead of the whole library, which is what keeps this usable at
        // 40k assets. `order[i]` is the original index of the i-th point in time.
        let order = points.indices.sorted { points[$0].date < points[$1].date }
        let sorted = order.map { points[$0] }
        let dates = sorted.map(\.date)
        let temporalWindow = temporalEpsilonHours * 3600

        func neighbours(of i: Int) -> [Int] {
            let centre = sorted[i]
            let lower = lowerBound(dates, centre.date.addingTimeInterval(-temporalWindow))
            let upper = upperBound(dates, centre.date.addingTimeInterval(temporalWindow))

            var result: [Int] = []
            for j in lower..<upper {
                let other = sorted[j]
                // The window already bounds time; only distance is left to check.
                if Geo.distanceKm(centre.coordinate, other.coordinate) <= spatialEpsilonKm {
                    result.append(j)
                }
            }
            return result
        }

        enum Label { case unvisited, noise, clustered(Int) }
        var labels = [Label](repeating: .unvisited, count: sorted.count)
        var clusters: [[Int]] = []

        for seed in sorted.indices {
            if case .unvisited = labels[seed] {} else { continue }

            let seedNeighbours = neighbours(of: seed)
            guard seedNeighbours.count >= minimumPoints else {
                labels[seed] = .noise
                continue
            }

            let clusterIndex = clusters.count
            clusters.append([])
            labels[seed] = .clustered(clusterIndex)
            clusters[clusterIndex].append(seed)

            // Breadth-first expansion over density-reachable points.
            var queue = seedNeighbours.filter { $0 != seed }
            var head = 0
            while head < queue.count {
                let current = queue[head]
                head += 1

                switch labels[current] {
                case .clustered:
                    continue
                case .noise:
                    // A border point: joins the cluster but never expands it.
                    labels[current] = .clustered(clusterIndex)
                    clusters[clusterIndex].append(current)
                    continue
                case .unvisited:
                    labels[current] = .clustered(clusterIndex)
                    clusters[clusterIndex].append(current)
                }

                let currentNeighbours = neighbours(of: current)
                if currentNeighbours.count >= minimumPoints {
                    for candidate in currentNeighbours {
                        if case .clustered = labels[candidate] { continue }
                        queue.append(candidate)
                    }
                }
            }
        }

        // Translate back to caller indices and restore chronological order.
        return clusters
            .map { $0.map { order[$0] }.sorted { points[$0].date < points[$1].date } }
            .filter { !$0.isEmpty }
            .sorted { points[$0[0]].date < points[$1[0]].date }
    }

    private static func lowerBound(_ dates: [Date], _ value: Date) -> Int {
        var low = 0, high = dates.count
        while low < high {
            let mid = (low + high) / 2
            if dates[mid] < value { low = mid + 1 } else { high = mid }
        }
        return low
    }

    private static func upperBound(_ dates: [Date], _ value: Date) -> Int {
        var low = 0, high = dates.count
        while low < high {
            let mid = (low + high) / 2
            if dates[mid] <= value { low = mid + 1 } else { high = mid }
        }
        return low
    }
}
