import SwiftUI

/// Four sensations, each with exactly one meaning.
///
/// Haptics stop meaning anything the moment they fire on every touch, so this is
/// deliberately a closed vocabulary rather than a passthrough to the feedback API:
/// adding a fifth kind of buzz should require editing this file and thinking about it.
///
/// These are `SensoryFeedback` values rather than `UIFeedbackGenerator` calls so they
/// are attached to a state change with `.sensoryFeedback(_:trigger:)`. SwiftUI then
/// owns the timing and the main-actor hop, and a haptic cannot drift out of sync with
/// the animation it belongs to.
enum Haptics {

    /// A card settled into place.
    static let settle: SensoryFeedback = .impact(flexibility: .soft)

    /// You snapped onto something — a carousel item, a pin, a chapter.
    static let snap: SensoryFeedback = .selection

    /// An artifact materialised: the polaroid finished developing.
    static let materialise: SensoryFeedback = .impact(flexibility: .rigid)

    /// An export completed.
    static let succeeded: SensoryFeedback = .success
}
