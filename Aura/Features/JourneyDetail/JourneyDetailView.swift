import AuraKit
import SwiftUI

struct JourneyDetailView: View {
    let journey: Journey

    @State private var accent: Color = .accentColor
    @State private var selection: MemorySelection?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: AuraTheme.Spacing.hairline),
        count: 3
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraTheme.Spacing.loose) {
                header

                ForEach(journey.chapters) { chapter in
                    chapterSection(chapter)
                }
            }
            .padding(.bottom, AuraTheme.Spacing.generous)
        }
        .background(AuraTheme.Palette.canvas)
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
        .fullScreenCover(item: $selection) { selection in
            MemoryViewer(memoryIDs: journey.memoryIDs, initialMemoryID: selection.id)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            if let heroID = journey.memoryIDs.first {
                MemoryImage(
                    memoryID: heroID,
                    targetSize: CGSize(width: 1400, height: 1400),
                    onLoad: { image in
                        // The accent is pulled from the hero rather than fixed, so
                        // every journey arrives with its own palette.
                        accent = AccentExtractor.shared.accent(for: image, key: heroID)
                    }
                )
                .frame(height: 420)
            }

            AuraTheme.legibilityScrim

            VStack(alignment: .leading, spacing: AuraTheme.Spacing.tight) {
                Text(journey.title)
                    .font(AuraTheme.Text.hero)
                    .foregroundStyle(.white)

                Text(JourneyFormatting.dateRange(from: journey.startDate, to: journey.endDate))
                    .font(AuraTheme.Text.body)
                    .foregroundStyle(.white.opacity(0.9))

                Text(JourneyFormatting.summary(for: journey))
                    .font(AuraTheme.Text.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(AuraTheme.Spacing.regular)
        }
        .frame(height: 420)
        .clipped()
    }

    // MARK: - Chapters

    private func chapterSection(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: AuraTheme.Spacing.snug) {
            VStack(alignment: .leading, spacing: AuraTheme.Spacing.hairline) {
                Text(JourneyFormatting.chapterTitle(for: chapter, in: journey))
                    .font(AuraTheme.Text.title)

                Text(chapter.startDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(AuraTheme.Text.caption)
                    .foregroundStyle(AuraTheme.Palette.secondaryText)
            }
            .padding(.horizontal, AuraTheme.Spacing.regular)

            LazyVGrid(columns: columns, spacing: AuraTheme.Spacing.hairline) {
                ForEach(chapter.memoryIDs, id: \.self) { memoryID in
                    Button {
                        Haptics.snap()
                        selection = MemorySelection(id: memoryID)
                    } label: {
                        MemoryImage(memoryID: memoryID, targetSize: CGSize(width: 300, height: 300))
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(
                                RoundedRectangle(cornerRadius: AuraTheme.Radius.tile, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AuraTheme.Spacing.snug)
        }
    }
}

/// `fullScreenCover(item:)` needs an `Identifiable`. Wrapping the identifier is
/// preferable to conforming `String` itself, which would leak a retroactive
/// conformance into every file in the target.
private struct MemorySelection: Identifiable, Hashable {
    let id: String
}
