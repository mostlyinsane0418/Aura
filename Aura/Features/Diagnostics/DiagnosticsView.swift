import AuraKit
import SwiftUI

/// Explains what Aura saw in the library and what it decided.
///
/// "No journeys yet" has at least four causes that look identical from the outside:
/// photos with no coordinates, a home base swallowing every cluster, thresholds set
/// too tight, or a genuine absence of travel. Guessing between them by rebuilding the
/// app is slow and unreliable, so the app shows its own working.
struct DiagnosticsView: View {
    @Environment(IngestService.self) private var ingest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let diagnostics = ingest.diagnostics {
                    library(diagnostics)
                    home(diagnostics)
                    clusters(diagnostics)
                } else {
                    Text("Nothing analysed yet — pull to refresh the feed first.")
                        .font(AuraTheme.Text.caption)
                        .foregroundStyle(AuraTheme.Palette.secondaryText)
                }
            }
            .navigationTitle("What Aura saw")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func library(_ diagnostics: BuildDiagnostics) -> some View {
        Section("Library") {
            row("Photos", "\(diagnostics.totalMemories)")
            row("With location", "\(diagnostics.locatedMemories)")
            row("Without location", "\(diagnostics.unlocatedMemories)")

            if diagnostics.locatedMemories == 0 && diagnostics.totalMemories > 0 {
                note("""
                None of these photos carry GPS coordinates, so there is nothing to \
                group by place. Photos received through messaging apps, screenshots, \
                and shots taken with Camera location turned off never have them.
                """)
            }
        }
    }

    @ViewBuilder
    private func home(_ diagnostics: BuildDiagnostics) -> some View {
        Section("Home") {
            row("Night-time photos", "\(diagnostics.nightTimeLocatedMemories)")
            if let home = ingest.homeBase {
                row("Home base", String(
                    format: "%.3f, %.3f",
                    home.coordinate.latitude, home.coordinate.longitude
                ))
                note("Clusters within 40km of here are treated as everyday life.")
            } else {
                note("""
                Not enough night-time photos with a location to work out where you \
                live, so anything lasting two days or more counts as a trip instead.
                """)
            }
        }
    }

    @ViewBuilder
    private func clusters(_ diagnostics: BuildDiagnostics) -> some View {
        Section("Clusters (\(diagnostics.acceptedClusters) of \(diagnostics.clusters.count) became journeys)") {
            if diagnostics.clusters.isEmpty {
                note("""
                No group of photos was dense enough in place and time to be a trip.
                """)
            }
            ForEach(Array(diagnostics.clusters.enumerated()), id: \.offset) { _, cluster in
                VStack(alignment: .leading, spacing: AuraTheme.Spacing.hairline) {
                    Text("\(cluster.memoryCount) photos · \(JourneyFormatting.dateRange(from: cluster.startDate, to: cluster.endDate))")
                        .font(AuraTheme.Text.body)
                    Text(verdict(cluster))
                        .font(AuraTheme.Text.caption)
                        .foregroundStyle(
                            cluster.outcome.isAccepted
                                ? AuraTheme.Palette.primaryText
                                : AuraTheme.Palette.secondaryText
                        )
                }
                .padding(.vertical, AuraTheme.Spacing.hairline)
            }
        }
    }

    private func verdict(_ cluster: BuildDiagnostics.ClusterReport) -> String {
        switch cluster.outcome {
        case .accepted:
            "Journey"
        case let .tooFewMemories(count, minimum):
            "Skipped — \(count) photos, needs \(minimum)"
        case let .tooCloseToHome(distance, radius):
            String(format: "Skipped — %.0fkm from home, needs %.0fkm", distance, radius)
        case let .tooShort(days, minimum):
            "Skipped — \(days) day\(days == 1 ? "" : "s"), needs \(minimum)"
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value).monospacedDigit()
        }
        .font(AuraTheme.Text.body)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(AuraTheme.Text.caption)
            .foregroundStyle(AuraTheme.Palette.secondaryText)
    }
}
