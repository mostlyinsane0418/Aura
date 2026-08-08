import Foundation

/// The minimal, framework-free description of one item in the photo library.
/// `PhotoLibraryService` maps `PHAsset` onto this; everything downstream —
/// clustering, chaptering, highlight selection — sees only this.
public struct MemorySeed: Identifiable, Hashable, Sendable {
    /// `PHAsset.localIdentifier`. Aura never copies pixels, only this reference.
    public let id: String
    public let createdAt: Date
    public let coordinate: Coordinate?
    public let isVideo: Bool
    public let isFavorite: Bool
    public let durationSeconds: Double?

    public init(
        id: String,
        createdAt: Date,
        coordinate: Coordinate? = nil,
        isVideo: Bool = false,
        isFavorite: Bool = false,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.coordinate = coordinate
        self.isVideo = isVideo
        self.isFavorite = isFavorite
        self.durationSeconds = durationSeconds
    }
}

/// A resolved place name. Populated by reverse geocoding; nil fields are normal
/// (open ocean, remote areas) and the UI must read as intentional when they are.
public struct Place: Hashable, Sendable, Codable {
    public var name: String?
    public var locality: String?
    public var administrativeArea: String?
    public var country: String?
    public var countryCode: String?
    public var coordinate: Coordinate

    /// A ready-made, regionally correct label supplied by the geocoder, when it has
    /// one. Preferred over anything assembled here — see `displayName`.
    public var formattedName: String?

    public init(
        name: String? = nil,
        locality: String? = nil,
        administrativeArea: String? = nil,
        country: String? = nil,
        countryCode: String? = nil,
        formattedName: String? = nil,
        coordinate: Coordinate
    ) {
        self.name = name
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.country = country
        self.countryCode = countryCode
        self.formattedName = formattedName
        self.coordinate = coordinate
    }

    /// What the user actually reads on a journey card: "Bristol", "Bristol, England",
    /// or a graceful fallback rather than "Unknown Location".
    ///
    /// The fallback concatenation is genuinely a fallback. Joining components with a
    /// comma produces confidently wrong labels in plenty of the world — which level of
    /// administrative division disambiguates a city, and in which order, is regional —
    /// so a label the geocoder formatted itself always wins.
    public var displayName: String {
        if let formattedName, !formattedName.isEmpty { return formattedName }
        if let locality, let country, country != locality {
            return "\(locality), \(country)"
        }
        return locality ?? name ?? administrativeArea ?? country ?? "Somewhere"
    }
}

/// Aura's mood taxonomy. Derived from visual signals, never from text, and always
/// treated as a soft tag: it drives ordering and styling, never filtering.
public enum Mood: String, CaseIterable, Hashable, Sendable, Codable {
    case joyful, serene, awe, nostalgic, playful, quiet

    public var displayName: String {
        rawValue.capitalized
    }
}

/// A time-and-place coherent group of memories within a journey — typically one day
/// or one place. "Day 2 · Clifton Observatory".
public struct Chapter: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var memoryIDs: [String]
    public var startDate: Date
    public var endDate: Date
    public var centroid: Coordinate?
    public var place: Place?

    public init(
        id: UUID = UUID(),
        memoryIDs: [String],
        startDate: Date,
        endDate: Date,
        centroid: Coordinate? = nil,
        place: Place? = nil
    ) {
        self.id = id
        self.memoryIDs = memoryIDs
        self.startDate = startDate
        self.endDate = endDate
        self.centroid = centroid
        self.place = place
    }
}

/// The primary unit of the app: a trip, rebuilt from the library rather than
/// assembled by hand.
public struct Journey: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var memoryIDs: [String]
    public var chapters: [Chapter]
    public var startDate: Date
    public var endDate: Date
    public var centroid: Coordinate?
    public var place: Place?
    /// User-set title. When nil the UI falls back to the resolved place name, so a
    /// rename never has to mutate the clustering result.
    public var customTitle: String?
    public var highlightIDs: [String]
    public var moodProfile: [Mood: Double]

    public init(
        id: UUID = UUID(),
        memoryIDs: [String],
        chapters: [Chapter] = [],
        startDate: Date,
        endDate: Date,
        centroid: Coordinate? = nil,
        place: Place? = nil,
        customTitle: String? = nil,
        highlightIDs: [String] = [],
        moodProfile: [Mood: Double] = [:]
    ) {
        self.id = id
        self.memoryIDs = memoryIDs
        self.chapters = chapters
        self.startDate = startDate
        self.endDate = endDate
        self.centroid = centroid
        self.place = place
        self.customTitle = customTitle
        self.highlightIDs = highlightIDs
        self.moodProfile = moodProfile
    }

    public var title: String {
        customTitle ?? place?.displayName ?? "Somewhere"
    }

    public var dayCount: Int {
        let days = Calendar(identifier: .gregorian)
            .dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(1, days + 1)
    }

    public var dominantMood: Mood? {
        moodProfile.max { $0.value < $1.value }?.key
    }
}
