//
//  GoalReminder.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@MainActor
enum GoalReminder {
    /// Если цель месяца достигнута впервые — сообщает об этом один раз.
    static func check(context: ModelContext) {
        let settingsList = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        guard let settings = settingsList.first, settings.goalReminderEnabled else { return }

        guard let monthStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: .now)
        ) else { return }

        let goals = (try? context.fetch(FetchDescriptor<MonthlyGoal>())) ?? []
        let target = goals.first {
            Calendar.current.isDate($0.monthStart, equalTo: monthStart, toGranularity: .month)
        }?.targetR ?? 10

        guard target > 0 else { return }

        let trades = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        let monthR = trades
            .filter { $0.result != .open }
            .filter {
                Calendar.current.isDate($0.tradingDay, equalTo: monthStart, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.actualR }

        guard monthR >= target else { return }

        // Ключ включает цель: если её подняли, отсчёт начинается заново.
        let key = "\(Int(monthStart.timeIntervalSince1970))|\(String(format: "%.2f", target))"
        guard settings.goalNoticeKey != key else { return }

        settings.goalNoticeKey = key
        try? context.save()

        ReminderService.notifyGoal(monthR: monthR, target: target)
    }
}
