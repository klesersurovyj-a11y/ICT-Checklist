//
//  WidgetSnapshot.swift
//  ICT Checklist
//

import Foundation
import SwiftData
import WidgetKit

enum WidgetSnapshot {
    static let appGroup = "group.com.organizationName.ICT-Checklist.shared"
    static let snapshotKey = "ladderSnapshot"

    struct WeekDay: Codable {
        var label: String
        var r: Double
    }

    struct Payload: Codable {
        var stepIndex: Int
        var amount: Double
        var accumulatedR: Double
        var lastR: Double?
        var updatedAt: Date
        var weekR: Double
        var weekTrades: Int
        var weekWins: Int
        var weekDays: [WeekDay]

        // Цикл дня: необязательные, чтобы старые данные читались без ошибок.
        var cycleStart: Date?
        var cycleEnd: Date?
        var cycleTrades: Int?
        var cycleMaxTrades: Int?
        var cycleR: Double?
        var cycleMaxR: Double?
        var cycleLimits: Bool?
        var openSymbol: String?
        var openDirection: String?
        var openIsBE: Bool?
        var openTargetR: Double?
        var openStopR: Double?
    }

    @MainActor
    static func refresh(context: ModelContext) {
        let states = (try? context.fetch(FetchDescriptor<RiskLadderState>())) ?? []
        let settingsList = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        let trades = (try? context.fetch(FetchDescriptor<Trade>())) ?? []

        let step = min(max(states.first?.stepIndex ?? 0, 0), 2)
        let amounts = settingsList.first?.ladderAmounts ?? [12, 25, 50]
        let amount = amounts[min(step, amounts.count - 1)]
        let accumulated = states.first?.accumulatedR ?? 0

        let lastClosed = trades
            .filter { $0.result != .open }
            .sorted { ($0.closedAt ?? $0.entryDate) < ($1.closedAt ?? $1.entryDate) }
            .last

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStarts: [Date] = (0..<7).reversed().map {
            calendar.date(byAdding: .day, value: -$0, to: today) ?? today
        }
        let weekStart = weekStarts.first ?? today

        func closeDay(_ trade: Trade) -> Date {
            calendar.startOfDay(for: trade.closedAt ?? trade.entryDate)
        }

        let weekTrades = trades.filter { $0.result != .open && closeDay($0) >= weekStart }
        let weekR = weekTrades.reduce(0) { $0 + $1.actualR }
        let weekWins = weekTrades.filter { $0.actualR > 0.05 }.count
        let weekDays = weekStarts.map { start in
            let total = weekTrades.filter { closeDay($0) == start }.reduce(0) { $0 + $1.actualR }
            return WeekDay(label: dayLabel(start), r: total)
        }

        let cycle = CycleLiveSnapshot.build(context: context)

        let payload = Payload(
            stepIndex: step,
            amount: amount,
            accumulatedR: accumulated,
            lastR: lastClosed?.actualR,
            updatedAt: .now,
            weekR: weekR,
            weekTrades: weekTrades.count,
            weekWins: weekWins,
            weekDays: weekDays,
            cycleStart: cycle?.cycleStart,
            cycleEnd: cycle?.cycleEnd,
            cycleTrades: cycle?.tradesToday,
            cycleMaxTrades: cycle?.maxTrades,
            cycleR: cycle?.rToday,
            cycleMaxR: cycle?.maxLossR,
            cycleLimits: cycle?.limitsEnabled,
            openSymbol: cycle?.openSymbol,
            openDirection: cycle?.openDirection,
            openIsBE: cycle?.openIsBE,
            openTargetR: cycle?.toTargetR,
            openStopR: cycle?.toStopR
        )

        guard let data = try? JSONEncoder().encode(payload),
              let defaults = UserDefaults(suiteName: appGroup) else { return }
        defaults.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func dayLabel(_ date: Date) -> String {
        dayLabelFormatter.string(from: date).uppercased()
    }

    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter
    }()
}
