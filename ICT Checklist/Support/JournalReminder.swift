//
//  JournalReminder.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@MainActor
enum JournalReminder {
    /// Планирует напоминание о дневнике на ближайшие дни.
    /// Если запись за сегодня уже есть, сегодняшнее напоминание пропускается.
    static func refresh(context: ModelContext) {
        let settingsList = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        guard let settings = settingsList.first, settings.journalReminderEnabled else {
            ReminderService.cancelJournal()
            return
        }

        let today = Calendar.current.startOfDay(for: .now)
        let entries = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        let hasTodayEntry = entries.contains {
            Calendar.current.isDate($0.day, equalTo: today, toGranularity: .day)
        }

        ReminderService.scheduleJournal(
            hour: settings.cycleEndHour,
            minute: settings.cycleEndMinute,
            skipToday: hasTodayEntry
        )
    }
}
