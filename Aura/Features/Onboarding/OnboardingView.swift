import SwiftUI

/// One screen, one sentence, one button.
///
/// There is no questionnaire and no account because there is nothing Aura needs to
/// ask: everything it knows, it works out from photos the user already has. The only
/// thing worth saying here is the promise and the privacy claim behind it.
struct OnboardingView: View {
    @Environment(IngestService.self) private var ingest
    @State private var hasAppeared = false
    @State private var hasRequestedAccess = false

    var body: some View {
        VStack(spacing: AuraTheme.Spacing.loose) {
            Spacer()

            VStack(spacing: AuraTheme.Spacing.regular) {
                Text("Aura")
                    .font(.system(size: 44, weight: .bold))
                    .tracking(2)

                Text("Your camera roll, remembered properly.")
                    .font(AuraTheme.Text.title)
                    .foregroundStyle(AuraTheme.Palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)

            Spacer()

            VStack(spacing: AuraTheme.Spacing.snug) {
                Text("Aura reads your photos to rebuild the trips you have already taken.")
                    .font(AuraTheme.Text.body)
                    .multilineTextAlignment(.center)

                Text("Everything stays on your phone. Nothing is uploaded.")
                    .font(AuraTheme.Text.caption)
                    .foregroundStyle(AuraTheme.Palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AuraTheme.Spacing.loose)

            Button {
                hasRequestedAccess = true
                ingest.requestAccess()
            } label: {
                Text("Find my journeys")
                    .font(AuraTheme.Text.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AuraTheme.Spacing.snug + 2)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.horizontal, AuraTheme.Spacing.loose)
            .padding(.bottom, AuraTheme.Spacing.generous)
            .opacity(hasAppeared ? 1 : 0)
            .sensoryFeedback(Haptics.settle, trigger: hasRequestedAccess)
        }
        .task {
            withAnimation(AuraTheme.Motion.gentle.delay(0.15)) { hasAppeared = true }
        }
    }
}

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: AuraTheme.Spacing.regular) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AuraTheme.Palette.secondaryText)

            Text("Aura needs your photos")
                .font(AuraTheme.Text.title)

            Text("There is nothing to rebuild without them. You can grant access to your whole library or just a few photos — either works.")
                .font(AuraTheme.Text.body)
                .foregroundStyle(AuraTheme.Palette.secondaryText)
                .multilineTextAlignment(.center)

            Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                .font(AuraTheme.Text.body.weight(.semibold))
                .padding(.top, AuraTheme.Spacing.tight)
        }
        .padding(.horizontal, AuraTheme.Spacing.loose)
    }
}
