import SwiftUI

struct RootView: View {
    @Environment(IngestService.self) private var ingest

    var body: some View {
        ZStack {
            AuraTheme.Palette.canvas.ignoresSafeArea()

            switch ingest.phase {
            case .idle, .needsPermission:
                OnboardingView()
            case .permissionDenied:
                PermissionDeniedView()
            case .scanning, .resolvingPlaces, .ready:
                JourneysView()
            }
        }
        .animation(AuraTheme.Motion.gentle, value: ingest.phase)
    }
}
