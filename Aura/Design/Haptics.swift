import UIKit

/// Four sensations, each with exactly one meaning.
///
/// Haptics stop meaning anything the moment they fire on every touch, so the API is
/// deliberately a closed vocabulary rather than a passthrough to `UIFeedbackGenerator`:
/// adding a fifth kind of buzz should require editing this file and thinking about it.
enum Haptics {

    /// A card settled into place.
    static func settle() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// You snapped onto something — a carousel item, a pin, a chapter.
    static func snap() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// An artifact materialised: the polaroid finished developing.
    static func materialise() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// An export completed.
    static func succeeded() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
