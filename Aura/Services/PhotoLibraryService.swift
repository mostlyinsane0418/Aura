import AuraKit
import Photos
import UIKit

enum PhotoAccess: Equatable {
    case notDetermined
    case denied
    case limited
    case full

    var canRead: Bool { self == .limited || self == .full }
}

/// The single door between the app and PhotoKit.
///
/// Nothing above this layer knows what a `PHAsset` is: the rest of Aura sees
/// `MemorySeed` values and `UIImage`s. That keeps the clustering core portable, makes
/// previews and tests possible without a photo library, and means the privacy-
/// sensitive surface is one file rather than scattered through the UI.
protocol PhotoLibraryServing: AnyObject, Sendable {
    var access: PhotoAccess { get }
    func requestAccess() async -> PhotoAccess

    /// Newest first, which is also the order the UI wants to show them in.
    func fetchSeeds(limit: Int?) async -> [MemorySeed]
    func image(for memoryID: String, targetSize: CGSize) async -> UIImage?
}

final class PhotoLibraryService: NSObject, PhotoLibraryServing, @unchecked Sendable {

    static let shared = PhotoLibraryService()

    private let imageManager = PHCachingImageManager()
    private let queue = DispatchQueue(label: "aura.photolibrary", qos: .userInitiated)

    var access: PhotoAccess {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> PhotoAccess {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return Self.map(status)
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoAccess {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted, .denied: .denied
        case .limited: .limited
        case .authorized: .full
        @unknown default: .denied
        }
    }

    // MARK: - Reading

    func fetchSeeds(limit: Int? = nil) async -> [MemorySeed] {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.fetchSeedsSync(limit: limit))
            }
        }
    }

    private func fetchSeedsSync(limit: Int?) -> [MemorySeed] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        if let limit { options.fetchLimit = limit }

        let assets = PHAsset.fetchAssets(with: options)
        var seeds: [MemorySeed] = []
        seeds.reserveCapacity(assets.count)

        assets.enumerateObjects { asset, _, _ in
            // An asset with no creation date cannot be placed on a timeline at all,
            // and a journey is a shape in time before it is anything else.
            guard let createdAt = asset.creationDate else { return }

            // Photos keeps its own location database, separate from the file's EXIF.
            // `asset.location` is the authoritative one; reading EXIF would miss
            // anything the user or another app corrected after import.
            let coordinate = asset.location.map {
                Coordinate(
                    latitude: $0.coordinate.latitude,
                    longitude: $0.coordinate.longitude
                )
            }

            seeds.append(MemorySeed(
                id: asset.localIdentifier,
                createdAt: createdAt,
                coordinate: coordinate,
                isVideo: asset.mediaType == .video,
                isFavorite: asset.isFavorite,
                durationSeconds: asset.mediaType == .video ? asset.duration : nil
            ))
        }
        return seeds
    }

    func image(for memoryID: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [memoryID],
            options: nil
        ).firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // Opportunistic delivery calls back twice: a fast degraded thumbnail,
                // then the real thing. A continuation may only be resumed once, so
                // wait for the final image unless the request failed outright.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !hasResumed, !isDegraded else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
    }
}
