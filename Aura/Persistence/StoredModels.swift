import AuraKit
import Foundation
import SwiftData

/// Aura persists metadata and nothing else.
///
/// A journey is a list of `PHAsset.localIdentifier`s plus what we worked out about
/// them; the pixels stay in Photos. That is what keeps the app small, keeps deletions
/// in Photos honest, and means there is no second copy of the user's life to lose.
@Model
final class StoredJourney {
    #Index<StoredJourney>([\.startDate])

    @Attribute(.unique) var id: UUID
    var memoryIDs: [String]
    var startDate: Date
    var endDate: Date

    var latitude: Double?
    var longitude: Double?

    var placeName: String?
    var locality: String?
    var administrativeArea: String?
    var country: String?
    var countryCode: String?

    /// Set only when the user renames a journey, so re-running ingest can refresh
    /// everything else without stepping on their edit.
    var customTitle: String?

    @Relationship(deleteRule: .cascade, inverse: \StoredChapter.journey)
    var chapters: [StoredChapter] = []

    init(journey: Journey) {
        id = journey.id
        memoryIDs = journey.memoryIDs
        startDate = journey.startDate
        endDate = journey.endDate
        latitude = journey.centroid?.latitude
        longitude = journey.centroid?.longitude
        customTitle = journey.customTitle
        apply(place: journey.place)
    }

    func apply(place: Place?) {
        placeName = place?.name
        locality = place?.locality
        administrativeArea = place?.administrativeArea
        country = place?.country
        countryCode = place?.countryCode
    }

    var coordinate: Coordinate? {
        guard let latitude, let longitude else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }

    var place: Place? {
        guard let coordinate else { return nil }
        return Place(
            name: placeName,
            locality: locality,
            administrativeArea: administrativeArea,
            country: country,
            countryCode: countryCode,
            coordinate: coordinate
        )
    }

    var asJourney: Journey {
        Journey(
            id: id,
            memoryIDs: memoryIDs,
            chapters: chapters.sorted { $0.startDate < $1.startDate }.map(\.asChapter),
            startDate: startDate,
            endDate: endDate,
            centroid: coordinate,
            place: place,
            customTitle: customTitle
        )
    }
}

@Model
final class StoredChapter {
    @Attribute(.unique) var id: UUID
    var memoryIDs: [String]
    var startDate: Date
    var endDate: Date
    var latitude: Double?
    var longitude: Double?
    var placeName: String?

    var journey: StoredJourney?

    init(chapter: Chapter) {
        id = chapter.id
        memoryIDs = chapter.memoryIDs
        startDate = chapter.startDate
        endDate = chapter.endDate
        latitude = chapter.centroid?.latitude
        longitude = chapter.centroid?.longitude
        placeName = chapter.place?.name
    }

    var asChapter: Chapter {
        let coordinate = latitude.flatMap { latitude in
            longitude.map { Coordinate(latitude: latitude, longitude: $0) }
        }
        return Chapter(
            id: id,
            memoryIDs: memoryIDs,
            startDate: startDate,
            endDate: endDate,
            centroid: coordinate,
            place: coordinate.map { Place(name: placeName, coordinate: $0) }
        )
    }
}

/// Everything the next ingest needs to avoid redoing work.
@Model
final class IngestState {
    var lastCompletedAt: Date?
    var homeLatitude: Double?
    var homeLongitude: Double?
    var homeSupport: Int

    init(lastCompletedAt: Date? = nil, homeBase: HomeBase? = nil) {
        self.lastCompletedAt = lastCompletedAt
        homeLatitude = homeBase?.coordinate.latitude
        homeLongitude = homeBase?.coordinate.longitude
        homeSupport = homeBase?.support ?? 0
    }

    var homeBase: HomeBase? {
        guard let homeLatitude, let homeLongitude, homeSupport > 0 else { return nil }
        return HomeBase(
            coordinate: Coordinate(latitude: homeLatitude, longitude: homeLongitude),
            support: homeSupport
        )
    }
}
