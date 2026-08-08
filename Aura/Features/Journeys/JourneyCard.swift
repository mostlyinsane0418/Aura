import AuraKit
import SwiftUI

/// The unit of the feed: one trip, one photograph, three lines of text.
///
/// The image is the card. Text sits over it behind a gradient scrim rather than in a
/// caption bar underneath, so scrolling the feed feels like leafing through prints
/// rather than reading a list.
struct JourneyCard: View {
    let journey: Journey
    var scrollOffset: CGFloat = 0

    private var heroID: String? { journey.memoryIDs.first }

    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            // Parallax: the image drifts against the card as it passes, which reads
            // as depth without any explicit 3D.
            let parallax = -frame.minY * 0.08

            ZStack(alignment: .bottomLeading) {
                if let heroID {
                    MemoryImage(memoryID: heroID, targetSize: CGSize(width: 1200, height: 1200))
                        .frame(width: geometry.size.width, height: geometry.size.height + 40)
                        .offset(y: parallax)
                } else {
                    AuraTheme.Palette.placeholder
                }

                AuraTheme.legibilityScrim

                VStack(alignment: .leading, spacing: AuraTheme.Spacing.tight) {
                    Text(journey.title)
                        .font(AuraTheme.Text.hero)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(JourneyFormatting.dateRange(from: journey.startDate, to: journey.endDate))
                        .font(AuraTheme.Text.body)
                        .foregroundStyle(.white.opacity(0.9))

                    Text(JourneyFormatting.summary(for: journey))
                        .font(AuraTheme.Text.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(AuraTheme.Spacing.regular)
            }
            .clipShape(RoundedRectangle(cornerRadius: AuraTheme.Radius.card, style: .continuous))
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }
}
