import AuraKit
import Foundation

/// Runs Aura's real clustering over photo metadata supplied as JSON on stdin, and
/// prints what it decided and why.
///
/// The point is to be able to answer "why is my feed empty?" without a phone, a
/// simulator, or a build of the app. Feed it the metadata of any library — see
/// `Tools/probe_library.py` for extracting it from a folder of JPEGs — and it reports
/// the same diagnostics the app's own debug panel shows.
///
///     python3 Tools/probe_library.py ~/photos | swift run aura-probe

struct InputSeed: Decodable {
    let id: String
    /// Seconds since 1970.
    let timestamp: Double
    let latitude: Double?
    let longitude: Double?
}

let data = FileHandle.standardInput.readDataToEndOfFile()
let input: [InputSeed]
do {
    input = try JSONDecoder().decode([InputSeed].self, from: data)
} catch {
    FileHandle.standardError.write(Data("Could not read metadata JSON: \(error)\n".utf8))
    exit(1)
}

let seeds = input.map { entry in
    MemorySeed(
        id: entry.id,
        createdAt: Date(timeIntervalSince1970: entry.timestamp),
        coordinate: zip2(entry.latitude, entry.longitude).map(Coordinate.init)
    )
}

func zip2<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}

let result = JourneyBuilder().build(from: seeds)
let diagnostics = result.diagnostics

let dates = DateFormatter()
dates.dateFormat = "d MMM yyyy"

print("""

  Library
    \(diagnostics.totalMemories) photos
    \(diagnostics.locatedMemories) with coordinates, \(diagnostics.unlocatedMemories) without
    \(diagnostics.nightTimeLocatedMemories) located at night (need \
\(HomeBaseInference.minimumSupport) to infer a home base)
""")

if let home = result.homeBase {
    print(String(
        format: "    home base: %.4f, %.4f (%d photos)",
        home.coordinate.latitude, home.coordinate.longitude, home.support
    ))
} else {
    print("    home base: none — falling back to duration to detect trips")
}

print("\n  Clusters (\(diagnostics.acceptedClusters) of \(diagnostics.clusters.count) became journeys)")
for cluster in diagnostics.clusters {
    let range = "\(dates.string(from: cluster.startDate))–\(dates.string(from: cluster.endDate))"
    let verdict: String
    switch cluster.outcome {
    case .accepted:
        verdict = "journey"
    case let .tooFewMemories(count, minimum):
        verdict = "rejected: \(count) photos, need \(minimum)"
    case let .tooCloseToHome(distance, radius):
        verdict = String(format: "rejected: %.0fkm from home, need %.0fkm", distance, radius)
    case let .tooShort(days, minimum):
        verdict = "rejected: \(days) day(s), need \(minimum)"
    }
    print("    \(cluster.memoryCount) photos  \(range)  → \(verdict)")
}

print("\n  Journeys")
if result.journeys.isEmpty {
    print("    none")
}
for journey in result.journeys {
    print("    \(journey.memoryIDs.count) photos, \(journey.chapters.count) chapters, "
        + "\(dates.string(from: journey.startDate))–\(dates.string(from: journey.endDate))")
}
print("")
