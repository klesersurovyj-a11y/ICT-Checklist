//
//  WeekPlanReminder.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@MainActor
enum WeekPlanReminder {
    /// Планирует одно напоминание про план новой недели, если он ещё пустой.
    static func refresh(context: ModelContext) {
        let settingsList = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        guard let settings = settingsList.first, settings.weekPlanReminderEnabled else {
            ReminderService.cancelWeekPlan()
            return
        }

        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let now = Date()
        let today = calendar.startOfDay(for: now)
        let sundayOffset = (1 - calendar.component(.weekday, from: today) + 7) % 7

        guard var fireDate = calendar.date(byAdding: .day, value: sundayOffset, to: today) else {
            return
        }
        if let atSix = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: fireDate) {
            fireDate = atSix
        }

        if sundayOffset == 0, fireDate <= now {
            guard let next = calendar.date(byAdding: .day, value: 7, to: fireDate) else { return }
            fireDate = next
        }

        // Неделя, для которой нужен план, начинается в понедельник после этого воскресенья.
        guard let targetWeekStart = calendar.date(byAdding: .day, value: 1, to: fireDate) else {
            return
        }

        let plans = (try? context.fetch(FetchDescriptor<WeekPlan>())) ?? []
        let plan = plans.first { calendar.isDate($0.weekStart, inSameDayAs: targetWeekStart) }

        let theme = (plan?.theme ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasScenarios = (plan?.scenarios ?? []).contains {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if theme.isEmpty && !hasScenarios {
            ReminderService.scheduleWeekPlan(on: fireDate)
        } else {
            ReminderService.cancelWeekPlan()
        }
    }
}
