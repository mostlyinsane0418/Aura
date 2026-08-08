import AuraKit
import Foundation
import SwiftData
import SwiftUI

/// Reads the library and rebuilds the user's journeys.
///
/// The first launch is the whole product: if it shows a spinner over an empty screen,
/// nothing downstream matters. So ingest runs in two passes — a quick pass over the
/// most recent slice of the library that puts a real journey on screen in seconds,
/// then a full pass that backfills the rest underneath it. Geocoding streams in after
/// that, upgrading "Somewhere" to "Bristol" a journey at a time.
@MainActor
@Observable
final class IngestService {

    enum Phase: Equatable {
        case idle
        case needsPermission
        case permissionDenied
        /// Reading the library. `progress` is nil while the total is still unknown.
        case scanning(progress: Double?)
        case resolvingPlaces
        case ready
    }

    /// How much of the library the quick pass looks at. Large enough to almost always
    /// contain the most recent trip, small enough to finish while the launch
    /// animation is still playing.
    private static let quickPassAssetLimit = 3_000

    private(set) var phase: Phase = .idle
    private(set) var journeys: [Journey] = []
    private(set) var homeBase: HomeBase?

    private let library: PhotoLibraryServing
    private let builder: JourneyBuilder
    private let geocoder: GeocodingService
    private var modelContext: ModelContext?
    private var runTask: Task<Void, Never>?

    init(
        library: PhotoLibraryServing = PhotoLibraryService.shared,
        builder: JourneyBuilder = JourneyBuilder(),
        geocoder: GeocodingService = .shared
    ) {
        self.library = library
        self.builder = builder
        self.geocoder = geocoder
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadPersisted()
    }

    // MARK: - Entry points

    func start() {
        guard runTask == nil else { return }

        switch library.access {
        case .notDetermined:
            phase = .needsPermission
        case .denied:
            phase = .permissionDenied
        case .limited, .full:
            refresh()
        }
    }

    func requestAccess() {
        Task {
            let access = await library.requestAccess()
            if access.canRead {
                refresh()
            } else {
                phase = .permissionDenied
            }
        }
    }

    func refresh() {
        guard runTask == nil else { return }
        runTask = Task { [weak self] in
            await self?.run()
            self?.runTask = nil
        }
    }

    // MARK: - The pipeline

    private func run() async {
        phase = .scanning(progress: journeys.isEmpty ? nil : 1)

        // Pass one: the recent slice. Enough to put something real on screen fast.
        if journeys.isEmpty {
            let recent = await library.fetchSeeds(limit: Self.quickPassAssetLimit)
            if !recent.isEmpty {
                let quick = builder.build(from: recent)
                apply(quick)
                phase = .scanning(progress: 0.3)
            }
        }

        // Pass two: everything. This is the authoritative result — the quick pass can
        // only ever see the tail of a trip that straddles its cut-off.
        let all = await library.fetchSeeds(limit: nil)
        guard !Task.isCancelled else { return }

        let result = builder.build(from: all)
        apply(result)

        phase = .resolvingPlaces
        await resolvePlaces()
        guard !Task.isCancelled else { return }

        persist()
        phase = .ready
    }

    private func apply(_ result: JourneyBuildResult) {
        homeBase = result.homeBase

        // Carry over anything already resolved so a refresh never regresses a journey
        // from "Bristol" back to "Somewhere" while it re-geocodes.
        let knownPlaces = Dictionary(
            journeys.compactMap { journey in journey.place.map { (journey.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        let knownTitles = Dictionary(
            journeys.compactMap { journey in journey.customTitle.map { (journey.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )

        journeys = result.journeys.map { journey in
            var journey = journey
            journey.place = journey.place ?? knownPlaces[journey.id]
            journey.customTitle = journey.customTitle ?? knownTitles[journey.id]
            return journey
        }
    }

    /// Newest first: the journey the user is most likely to open should get its name
    /// before the ones from four years ago.
    private func resolvePlaces() async {
        for index in journeys.indices {
            guard !Task.isCancelled else { return }
            guard journeys[index].place == nil,
                  let centroid = journeys[index].centroid else { continue }

            if let place = await geocoder.place(for: centroid) {
                journeys[index].place = place
            }
        }
    }

    // MARK: - Persistence

    private func loadPersisted() {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<StoredJourney>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        guard let stored = try? modelContext.fetch(descriptor), !stored.isEmpty else { return }

        journeys = stored.map(\.asJourney)
        homeBase = (try? modelContext.fetch(FetchDescriptor<IngestState>()))?.first?.homeBase
        phase = .ready
    }

    private func persist() {
        guard let modelContext else { return }

        // Journeys are derived data: the library is the source of truth, so a clean
        // replace is both simpler and more correct than trying to diff clusters whose
        // membership may have shifted.
        try? modelContext.delete(model: StoredJourney.self)
        try? modelContext.delete(model: IngestState.self)

        for journey in journeys {
            let stored = StoredJourney(journey: journey)
            modelContext.insert(stored)
            for chapter in journey.chapters {
                let storedChapter = StoredChapter(chapter: chapter)
                storedChapter.journey = stored
                modelContext.insert(storedChapter)
            }
        }
        modelContext.insert(IngestState(lastCompletedAt: .now, homeBase: homeBase))

        try? modelContext.save()
    }
}
