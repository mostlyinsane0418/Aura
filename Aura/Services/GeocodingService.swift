import AuraKit
import CoreLocation
import MapKit

/// Turns a journey's centroid into "Bristol, England".
///
/// Reverse geocoding is rate limited and will start failing under a burst, so requests
/// are serialised, spaced, and cached hard. A journey's place name never changes, so a
/// cache hit is always correct — and after the first ingest almost everything is a
/// cache hit.
actor GeocodingService {

    static let shared = GeocodingService()

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

        // The initialiser is failable rather than throwing: it returns nil for
        // coordinates that are not valid at all, which a cluster centroid should never
        // be, but a corrupt asset location could produce.
        guard let request = MKReverseGeocodingRequest(location: location),
              let mapItems = try? await request.mapItems,
              let mapItem = mapItems.first else {
            // A failure here is not worth surfacing: the journey still has its dates,
            // its photos, and its map. It reads as "Somewhere" until the next ingest
            // retries it.
            return nil
        }

        // MapKit stopped vending structured postal components in iOS 26 — there is no
        // `CNPostalAddress` on a geocoded map item any more. What it offers instead is
        // pre-formatted strings that are correct for the region in question, which is
        // the better primitive for a label anyway: `cityWithContext` knows that a US
        // city wants its state and a French one does not.
        let representations = mapItem.addressRepresentations
        let city = representations?.city

        let place = Place(
            name: city ?? mapItem.address?.shortAddress,
            locality: city,
            country: representations?.region,
            formattedName: representations?.cityWithContext,
            coordinate: coordinate
        )
        cache[key] = place
        return place
    }
}
