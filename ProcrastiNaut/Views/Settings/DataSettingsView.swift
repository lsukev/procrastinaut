import SwiftUI

struct DataSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var showingArchiveConfirmation = false

    var body: some View {
        Form {
            Section("Auto-Archive") {
                Stepper(
                    "Archive after \(settings.archiveAfterDays) days",
                    value: $settings.archiveAfterDays,
                    in: 30...365,
                    step: 30
                )

                Stepper(
                    "Delete archived after \(settings.deleteArchivedAfterDays) days",
                    value: $settings.deleteArchivedAfterDays,
                    in: 90...730,
                    step: 30
                )
            }

            Section("Duration Learning") {
                Toggle("Learn from completion times", isOn: $settings.enableDurationLearning)
                    .help("Adjusts future estimates based on how long tasks actually take")
            }

            Section("Manual Actions") {
                Button("Archive Old Records Now") {
                    showingArchiveConfirmation = true
                }

                Button("Export Data as JSON") {
                    exportData()
                }
            }
        }
        .formStyle(.grouped)
        .alert("Archive Now?", isPresented: $showingArchiveConfirmation) {
            Button("Archive", role: .destructive) {
                runArchive()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will archive completed records older than \(settings.archiveAfterDays) days.")
        }
    }

    private func runArchive() {
        // Triggered via AppDelegate which has access to ModelContext
        NotificationCenter.default.post(name: .procrastiNautArchiveRequested, object: nil)
    }

    private func exportData() {
        NotificationCenter.default.post(name: .procrastiNautExportRequested, object: nil)
    }
}

extension Notification.Name {
    static let procrastiNautArchiveRequested = Notification.Name("procrastiNautArchiveRequested")
    static let procrastiNautExportRequested = Notification.Name("procrastiNautExportRequested")
}
