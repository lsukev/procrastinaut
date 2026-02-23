import Foundation
import SwiftData

@MainActor
final class ArchiveManager {
    private let settings = UserSettings.shared

    func performArchive(modelContext: ModelContext) {
        archiveOldTaskRecords(modelContext: modelContext)
        deleteOldArchived(modelContext: modelContext)
        pruneOldDailyStats(modelContext: modelContext)
    }

    private func archiveOldTaskRecords(modelContext: ModelContext) {
        let archiveCutoff = Calendar.current.date(
            byAdding: .day,
            value: -settings.archiveAfterDays,
            to: Date()
        ) ?? Date()

        let descriptor = FetchDescriptor<TaskRecord>(
            predicate: #Predicate<TaskRecord> { record in
                record.completedAt != nil && record.isArchived == false
            }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            if let completedAt = record.completedAt, completedAt < archiveCutoff {
                record.isArchived = true
            }
        }

        try? modelContext.save()
    }

    private func deleteOldArchived(modelContext: ModelContext) {
        let deleteCutoff = Calendar.current.date(
            byAdding: .day,
            value: -settings.deleteArchivedAfterDays,
            to: Date()
        ) ?? Date()

        let descriptor = FetchDescriptor<TaskRecord>(
            predicate: #Predicate<TaskRecord> { record in
                record.isArchived == true
            }
        )

        guard let records = try? modelContext.fetch(descriptor) else { return }

        for record in records {
            if let completedAt = record.completedAt, completedAt < deleteCutoff {
                modelContext.delete(record)
            }
        }

        try? modelContext.save()
    }

    private func pruneOldDailyStats(modelContext: ModelContext) {
        let statsCutoff = Calendar.current.date(
            byAdding: .day,
            value: -settings.deleteArchivedAfterDays,
            to: Date()
        ) ?? Date()

        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate<DailyStats> { stat in
                stat.date < statsCutoff
            }
        )

        guard let stats = try? modelContext.fetch(descriptor) else { return }

        for stat in stats {
            modelContext.delete(stat)
        }

        try? modelContext.save()
    }
}
