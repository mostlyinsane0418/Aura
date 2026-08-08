import SwiftUI
import UIKit

/// A bounded in-memory cache of decoded thumbnails.
///
/// `NSCache` rather than a dictionary specifically so the system can evict under
/// pressure: a grid of a thousand memories would otherwise happily hold a few hundred
/// megabytes of decoded bitmaps and get the app jettisoned.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 400
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

/// Loads and displays one memory from the photo library.
///
/// Fades in rather than popping: a grid that snaps into existence looks like a table
/// of data, and one that resolves looks like photographs.
struct MemoryImage: View {
    let memoryID: String
    var targetSize: CGSize = CGSize(width: 400, height: 400)
    var onLoad: ((UIImage) -> Void)?

    @State private var image: UIImage?
    @State private var hasAppeared = false

    private var cacheKey: String { "\(memoryID)-\(Int(targetSize.width))" }

    var body: some View {
        ZStack {
            AuraTheme.Palette.placeholder

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .clipped()
        .animation(.easeOut(duration: 0.25), value: image == nil)
        .task(id: memoryID) { await load() }
    }

    private func load() async {
        if let cached = ThumbnailCache.shared.image(forKey: cacheKey) {
            image = cached
            onLoad?(cached)
            return
        }

        guard let loaded = await PhotoLibraryService.shared.image(
            for: memoryID,
            targetSize: targetSize
        ) else { return }

        ThumbnailCache.shared.insert(loaded, forKey: cacheKey)
        image = loaded
        onLoad?(loaded)
    }
}
