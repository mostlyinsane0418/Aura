import SwiftUI

/// The whole visual language in one place. Defined once, up front, so nothing drifts
/// as features are added: every surface reads from here rather than inventing a
/// number.
enum AuraTheme {

    // MARK: - Type
    //
    // Four sizes, not a ramp of twelve. Restraint is the aesthetic.

    enum Text {
        static let hero = Font.system(size: 34, weight: .bold, design: .default)
        static let title = Font.system(size: 22, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let caption = Font.system(size: 13, weight: .medium)
    }

    // MARK: - Spacing

    enum Spacing {
        static let hairline: CGFloat = 2
        static let tight: CGFloat = 6
        static let snug: CGFloat = 12
        static let regular: CGFloat = 20
        static let loose: CGFloat = 32
        static let generous: CGFloat = 48
    }

    enum Radius {
        static let card: CGFloat = 28
        static let tile: CGFloat = 12
        static let capsule: CGFloat = 999
    }

    // MARK: - Motion
    //
    // One spring for everything. When every transition shares a curve the app feels
    // like a single physical object rather than a set of screens.

    enum Motion {
        static let standard = Animation.interpolatingSpring(stiffness: 220, damping: 26)
        /// For larger surfaces, where the standard spring reads as too eager.
        static let gentle = Animation.interpolatingSpring(stiffness: 160, damping: 24)
        /// The one deliberate exception: a polaroid takes its time to develop.
        static let develop = Animation.easeOut(duration: 1.2)
    }

    // MARK: - Colour

    enum Palette {
        static let canvas = Color(
            light: Color(red: 0.98, green: 0.973, blue: 0.961),
            dark: Color(red: 0.043, green: 0.043, blue: 0.051)
        )
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        /// Used behind imagery that has not loaded yet — warm, never a grey slab.
        static let placeholder = Color(
            light: Color(red: 0.93, green: 0.92, blue: 0.90),
            dark: Color(red: 0.11, green: 0.11, blue: 0.12)
        )
    }

    /// The scrim that keeps white text legible over an unpredictable photograph.
    /// A gradient rather than a flat overlay, so the image is only dimmed where the
    /// text actually sits.
    static var legibilityScrim: LinearGradient {
        LinearGradient(
            colors: [.clear, .black.opacity(0.15), .black.opacity(0.65)],
            startPoint: .center,
            endPoint: .bottom
        )
    }
}

extension Color {
    /// Light/dark pairs without needing an asset catalogue entry for every colour.
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}
