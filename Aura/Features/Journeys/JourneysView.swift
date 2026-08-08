import AuraKit
import SwiftUI

struct JourneysView: View {
    @Environment(IngestService.self) private var ingest
    @Namespace private var cardTransition

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AuraTheme.Spacing.loose) {
                    if ingest.journeys.isEmpty {
                        emptyOrScanning
                            .padding(.top, AuraTheme.Spacing.generous)
                    } else {
                        ForEach(ingest.journeys) { journey in
                            NavigationLink {
                                JourneyDetailView(journey: journey)
                                    .navigationTransition(
                                        .zoom(sourceID: journey.id, in: cardTransition)
                                    )
                            } label: {
                                JourneyCard(journey: journey)
                                    .matchedTransitionSource(id: journey.id, in: cardTransition)
                            }
                            .buttonStyle(CardButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, AuraTheme.Spacing.regular)
                .padding(.bottom, AuraTheme.Spacing.generous)
            }
            .background(AuraTheme.Palette.canvas)
            .navigationTitle("Journeys")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button {
                            ingest.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .refreshable { ingest.refresh() }
        }
    }

    private var isWorking: Bool {
        switch ingest.phase {
        case .scanning, .resolvingPlaces: true
        default: false
        }
    }

    /// While the first pass runs there is genuinely nothing to show, so say what is
    /// happening in a sentence rather than parking a spinner on an empty screen.
    @ViewBuilder
    private var emptyOrScanning: some View {
        VStack(spacing: AuraTheme.Spacing.snug) {
            if isWorking {
                ProgressView()
                Text("Reading your library")
                    .font(AuraTheme.Text.body)
                Text("Rebuilding trips from where and when your photos were taken.")
                    .font(AuraTheme.Text.caption)
                    .foregroundStyle(AuraTheme.Palette.secondaryText)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "map")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AuraTheme.Palette.secondaryText)
                Text("No journeys yet")
                    .font(AuraTheme.Text.title)
                Text("Aura looks for photos taken away from home. Once you travel, your trips will appear here on their own.")
                    .font(AuraTheme.Text.caption)
                    .foregroundStyle(AuraTheme.Palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, AuraTheme.Spacing.loose)
    }
}

/// Cards should feel pressable, not tappable: a small, springy scale rather than a
/// highlight colour, with a soft tap on release.
private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(AuraTheme.Motion.standard, value: configuration.isPressed)
            .sensoryFeedback(Haptics.settle, trigger: configuration.isPressed) { wasPressed, isPressed in
                wasPressed && !isPressed
            }
    }
}
