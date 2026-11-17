//
//  DailyLimitReminder.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@MainActor
enum DailyLimitReminder {
    /// Если дневной лимит сработал впервые — сообщает об этом один раз за торговый день.
    static func check(context: ModelContext) {
        let settingsList = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        guard let settings = settingsList.first,
              settings.dailyLimitsEnabled,
              settings.dailyLimitReminderEnabled else { return }

        let maxLoss = max(settings.maxDailyLossR, 0.5)
        let maxTrades = max(settings.maxTradesPerDay, 1)

        let trades = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        let today = trades.filter { Calendar.current.isDateInToday($0.tradingDay) }
        let dayR = today
            .filter { $0.result != .open }
            .reduce(0) { $0 + $1.actualR }

        let reached = today.count >= maxTrades || dayR <= -maxLoss + 0.0001
        guard reached else { return }

        let dayStart = Calendar.current.startOfDay(for: .now)
        let key = "\(Int(dayStart.timeIntervalSince1970))"
        guard settings.dailyLimitNoticeKey != key else { return }

        settings.dailyLimitNoticeKey = key
        try? context.save()

        ReminderService.notifyDailyLimit(
            tradesCount: today.count,
            maxTrades: maxTrades,
            dayR: dayR,
            maxLossR: maxLoss
        )
    }
}
