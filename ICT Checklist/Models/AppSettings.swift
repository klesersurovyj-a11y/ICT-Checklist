//
//  AppSettings.swift
//  ICT Checklist
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    var symbolsRaw: String = "EURUSD,GBPUSD,XAUUSD"
    var minRR: Double = 2.0
    var ladder1: Double = 12
    var ladder2: Double = 25
    var ladder3: Double = 50
    var cycleStartHour: Int = 19
    var cycleStartMinute: Int = 0
    var cycleEndHour: Int = 22
    var cycleEndMinute: Int = 0

    var reminderStartEnabled: Bool = false
    var reminderEndEnabled: Bool = false

    /// Daily limits: once reached, no new entries until the next cycle.
    var dailyLimitsEnabled: Bool = false
    /// Maximum loss for a trading day, stored as a positive number of R.
    var maxDailyLossR: Double = 2
    var maxTradesPerDay: Int = 2

    /// Weekly limits: a soft warning once the week's loss or trade count is reached.
    var weeklyLimitsEnabled: Bool = false
    /// Maximum loss for a trading week, stored as a positive number of R.
    var maxWeeklyLossR: Double = 6
    var maxTradesPerWeek: Int = 10

    /// Максимальный риск на сделку в процентах капитала.
    var maxRiskPercent: Double = 1

    /// Автозакрытие позиций по TP/SL по рыночной цене.
    var autoCloseEnabled: Bool = false

    /// Напоминать, когда суммарный R месяца доходит до цели.
    var goalReminderEnabled: Bool = false
    /// Месяц и цель, о которых уже сообщили, — чтобы не повторять.
    var goalNoticeKey: String = ""
    /// Напоминать заполнить дневник после закрытия терминала.
    var journalReminderEnabled: Bool = false

    /// Напоминать заполнить разбор через час после закрытия сделки.
    var reviewReminderEnabled: Bool = false

    /// Напоминать про план новой недели в воскресенье.
    var weekPlanReminderEnabled: Bool = false

    /// Напоминать, когда сработал дневной лимит.
    var dailyLimitReminderEnabled: Bool = false
    /// Торговый день, о лимите которого уже сообщили, — чтобы не повторять.
    var dailyLimitNoticeKey: String = ""
    /// Скрытые плитки «Разбора недели»: идентификаторы через запятую.
    var hiddenReviewTilesRaw: String = ""

    /// Провайдер ИИ-ассистента: OpenAI или OpenRouter.
    var assistantProviderRaw: String = "openai"
    /// Модель выбранного провайдера.
    var assistantModelName: String = "gpt-4o-mini"

    init(symbolsRaw: String = "EURUSD,GBPUSD,XAUUSD",
         minRR: Double = 2.0,
         ladder1: Double = 12,
         ladder2: Double = 25,
         ladder3: Double = 50,
         cycleStartHour: Int = 19,
         cycleStartMinute: Int = 0,
         cycleEndHour: Int = 22,
         cycleEndMinute: Int = 0) {
        self.symbolsRaw = symbolsRaw
        self.minRR = minRR
        self.ladder1 = ladder1
        self.ladder2 = ladder2
        self.ladder3 = ladder3
        self.cycleStartHour = cycleStartHour
        self.cycleStartMinute = cycleStartMinute
        self.cycleEndHour = cycleEndHour
        self.cycleEndMinute = cycleEndMinute
    }

    var symbols: [String] {
        get {
            symbolsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            symbolsRaw = newValue.joined(separator: ",")
        }
    }

    var ladderAmounts: [Double] {
        [ladder1, ladder2, ladder3]
    }

    var assistantProvider: AssistantProvider {
        get { AssistantProvider(rawValue: assistantProviderRaw) ?? .openAI }
        set { assistantProviderRaw = newValue.rawValue }
    }

    func ladderAmount(at index: Int) -> Double {
        let safeIndex = min(max(index, 0), ladderAmounts.count - 1)
        return ladderAmounts[safeIndex]
    }
}
