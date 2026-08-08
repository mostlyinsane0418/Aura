import AuraKit
import CoreLocation

/// Turns a journey's centroid into "Bristol, United Kingdom".
///
/// `CLGeocoder` is rate limited and will start failing under a burst, so requests are
/// serialised, spaced, and cached hard. A journey's place name never changes, so a
/// cache hit is always correct — and after the first ingest almost everything is a
/// cache hit.
actor GeocodingService {

    static let shared = GeocodingService()

    private let geocoder = CLGeocoder()
    private var cache: [CacheKey: Place] = [:]
    private var lastRequest: Date?

    /// Apple does not publish the limit; roughly one request per second is the
    /// commonly reported safe rate, and ingest is a background activity anyway.
    private let minimumInterval: TimeInterval = 1.0

    /// Coordinates rounded to ~1km. Two journeys centred a few hundred metres apart
    /// resolve to the same place name, so there is no reason to ask twice.
    private struct CacheKey: Hashable {
        let latitude: Int
        let longitude: Int

        init(_ coordinate: Coordinate) {
            latitude = Int((coordinate.latitude * 100).rounded())
            longitude = Int((coordinate.longitude * 100).rounded())
        }
    }

    func place(for coordinate: Coordinate) async -> Place? {
        let key = CacheKey(coordinate)
        if let cached = cache[key] { return cached }

        if let lastRequest {
            let elapsed = Date().timeIntervalSince(lastRequest)
            if elapsed < minimumInterval {
                try? await Task.sleep(for: .seconds(minimumInterval - elapsed))
            }
        }
        lastRequest = Date()

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            // A failure here is not worth surfacing: the journey still has its dates,
            // its photos, and its map. It simply reads as "Somewhere" until the next
            // ingest retries it.
            return nil
        }

        let place = Place(
            name: placemark.name,
            locality: placemark.locality ?? placemark.subAdministrativeArea,
            administrativeArea: placemark.administrativeArea,
            country: placemark.country,
            countryCode: placemark.isoCountryCode,
            coordinate: coordinate
        )
        cache[key] = place
        return place
    }
}
