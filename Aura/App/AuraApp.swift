import SwiftData
import SwiftUI

@main
struct AuraApp: App {
    @State private var ingest = IngestService()

    private let modelContainer: ModelContainer = {
        let schema = Schema([StoredJourney.self, StoredChapter.self, IngestState.self])
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            )
        } catch {
            // Everything here is derived from the photo library, so a store that
            // cannot be opened is a cache miss, not lost user data: start clean
            // rather than refusing to launch.
            return try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(ingest)
                .preferredColorScheme(.dark)
                .task {
                    ingest.attach(modelContext: modelContainer.mainContext)
                    ingest.start()
                }
        }
        .modelContainer(modelContainer)
    }
}
